import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch_scope_provider.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/network/session_expiration_notifier.dart';
import '../../../../core/telemetry/error_telemetry.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/google_auth_models.dart';
import '../../data/models/login_response_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    AuthRemoteDataSource(ref.watch(apiClientProvider)),
    ref.watch(secureStorageProvider),
  );
});

final googleAuthConfigProvider = FutureProvider<GoogleAuthConfigModel>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final desktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // El backend embebido de escritorio puede tardar unos segundos en quedar
  // disponible. Un fallo transitorio no debe hacer desaparecer Google del login
  // durante toda la vida de este provider.
  final attempts = desktop ? 5 : 1;
  Object? lastError;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await repository.googleConfig();
    } catch (error) {
      lastError = error;
      if (attempt == attempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 650 * attempt));
    }
  }
  throw lastError ?? StateError('No fue posible cargar Google Sign-In.');
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    LoginUseCase(ref.watch(authRepositoryProvider)),
    LogoutUseCase(ref.watch(authRepositoryProvider)),
    ref.watch(authRepositoryProvider),
    ref.watch(sessionExpirationNotifierProvider),
    ref,
  );
});

class AuthState {
  const AuthState({
    this.authenticated = false,
    this.loading = false,
    this.restoringSession = false,
    this.failure,
    this.roles = const <String>[],
    this.subscriptionStatus,
    this.subscriptionActive = true,
    this.businessSetupComplete = true,
  });

  final bool authenticated;
  final bool loading;

  /// Indica que BarLytics todavía está resolviendo la sesión almacenada.
  /// Mientras sea true no debe mostrarse Login ni decidir rutas protegidas.
  final bool restoringSession;

  final Failure? failure;

  /// Roles del usuario autenticado devueltos por el backend en el login.
  /// Se usan para consultar MENUS/OPCIONMENU y pintar la navegación permitida.
  final List<String> roles;
  final String? subscriptionStatus;
  final bool subscriptionActive;
  final bool businessSetupComplete;

  AuthState copyWith({
    bool? authenticated,
    bool? loading,
    bool? restoringSession,
    Failure? failure,
    List<String>? roles,
    String? subscriptionStatus,
    bool? subscriptionActive,
    bool? businessSetupComplete,
  }) =>
      AuthState(
        authenticated: authenticated ?? this.authenticated,
        loading: loading ?? this.loading,
        restoringSession: restoringSession ?? this.restoringSession,
        failure: failure,
        roles: roles ?? this.roles,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        subscriptionActive: subscriptionActive ?? this.subscriptionActive,
        businessSetupComplete: businessSetupComplete ?? this.businessSetupComplete,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._login,
    this._logout,
    this._repository,
    this._sessionExpirationNotifier,
    this._ref,
  ) : super(const AuthState(restoringSession: true)) {
    _sessionExpirationNotifier.addListener(_handleSessionExpired);
    checkSession();
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final AuthRepository _repository;
  final SessionExpirationNotifier _sessionExpirationNotifier;
  final Ref _ref;

  void _handleSessionExpired() {
    // Un 402 no invalida las credenciales: actualizamos solamente el estado
    // de suscripción para que el router lleve al cobro, conservando la sesión.
    if (_sessionExpirationNotifier.subscriptionRequired) {
      if (!state.authenticated || !state.subscriptionActive) return;
      state = state.copyWith(
        subscriptionStatus: 'PAST_DUE',
        subscriptionActive: false,
        businessSetupComplete: false,
      );
      unawaited(_repository.updateSubscriptionState(
        status: 'PAST_DUE',
        active: false,
      ).catchError((Object _) {}));
      _ref.invalidate(branchScopeProvider);
      return;
    }
    // También se ejecuta durante checkSession(). Si el token vence mientras se
    // restaura una sesión, el estado todavía puede estar en authenticated=false;
    // aun así debemos cancelar la restauración y volver al login.
    _ref.invalidate(branchScopeProvider);
    _ref.invalidate(googleAuthConfigProvider);
    state = const AuthState();
  }

  @override
  void dispose() {
    _sessionExpirationNotifier.removeListener(_handleSessionExpired);
    super.dispose();
  }

  Future<void> checkSession() async {
    try {
      final hasSession = await _repository.hasSession();
      if (!hasSession) {
        state = const AuthState();
        return;
      }

      final roles = await _repository.getStoredRoles();
    if (roles.isEmpty) {
      // Un JWT sin roles útiles no puede conservar una sesión operativa. Se
      // elimina silenciosamente para evitar pantallas de "menú sin roles".
      await _repository.logout();
      _ref.invalidate(branchScopeProvider);
      state = const AuthState();
      return;
    }

    final subscriptionStatus = await _repository.getStoredSubscriptionStatus();
    final subscriptionActive = await _repository.getStoredSubscriptionActive();
    var businessSetupComplete = await _repository.getStoredBusinessSetupComplete();
    if (subscriptionActive) {
      try {
        businessSetupComplete = await _repository.fetchBusinessSetupComplete();
        await _repository.updateBusinessSetupState(businessSetupComplete);
      } catch (_) {
        // Un 401 limpia Secure Storage desde AuthInterceptor. Los errores de red
        // normales conservan el último estado conocido.
      }
    }

    // Es obligatorio volver a consultar el almacenamiento: un 401 puede haber
    // invalidado la sesión mientras esperábamos fetchBusinessSetupComplete().
    if (!await _repository.hasSession()) {
      _ref.invalidate(branchScopeProvider);
      state = const AuthState();
      return;
    }

    state = AuthState(
      authenticated: true,
      roles: roles,
      subscriptionStatus: subscriptionStatus,
      subscriptionActive: subscriptionActive,
      businessSetupComplete: businessSetupComplete,
    );
      if (subscriptionActive && businessSetupComplete) {
        await _ref.read(branchScopeProvider.notifier).load();
      }
    } catch (_) {
      // Un fallo inesperado al restaurar almacenamiento/sesión no debe dejar
      // la aplicación bloqueada en el splash. Se vuelve a un estado anónimo.
      _ref.invalidate(branchScopeProvider);
      state = const AuthState();
    }
  }

  Future<bool> login(String identificador, String password) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _login(identificador, password);
      if (response.roles.isEmpty) {
        await _repository.logout();
        _ref.invalidate(branchScopeProvider);
        state = const AuthState();
        return false;
      }
      final setupComplete = response.subscriptionActive
          ? await _refreshBusinessSetupValue()
          : false;
      // No atribuir fallos de un usuario público/anterior a esta sesión.
      ErrorTelemetry.instance.clearSession();
      state = AuthState(
        authenticated: true,
        roles: response.roles,
        subscriptionStatus: response.subscriptionStatus,
        subscriptionActive: response.subscriptionActive,
        businessSetupComplete: setupComplete,
      );
      if (response.subscriptionActive && setupComplete) {
        await _ref.read(branchScopeProvider.notifier).load();
      } else {
        _ref.invalidate(branchScopeProvider);
      }
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<bool> googleLogin(String idToken) async {
    state = state.copyWith(loading: true, failure: null);
    try {
      final response = await _repository.googleLogin(idToken);
      if (response.roles.isEmpty) {
        await _repository.logout();
        _ref.invalidate(branchScopeProvider);
        state = const AuthState();
        return false;
      }
      final setupComplete = response.subscriptionActive
          ? await _refreshBusinessSetupValue()
          : false;
      // No atribuir fallos de un usuario público/anterior a esta sesión.
      ErrorTelemetry.instance.clearSession();
      state = AuthState(
        authenticated: true,
        roles: response.roles,
        subscriptionStatus: response.subscriptionStatus,
        subscriptionActive: response.subscriptionActive,
        businessSetupComplete: setupComplete,
      );
      if (response.subscriptionActive && setupComplete) {
        await _ref.read(branchScopeProvider.notifier).load();
      } else {
        _ref.invalidate(branchScopeProvider);
      }
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<bool> appleLogin(String idToken) async {
    state = state.copyWith(loading: true, failure: null);
    try {
      final response = await _repository.appleLogin(idToken);
      if (response.roles.isEmpty) {
        await _repository.logout();
        _ref.invalidate(branchScopeProvider);
        state = const AuthState();
        return false;
      }
      final setupComplete = response.subscriptionActive
          ? await _refreshBusinessSetupValue()
          : false;
      // No atribuir fallos de un usuario público/anterior a esta sesión.
      ErrorTelemetry.instance.clearSession();
      state = AuthState(
        authenticated: true,
        roles: response.roles,
        subscriptionStatus: response.subscriptionStatus,
        subscriptionActive: response.subscriptionActive,
        businessSetupComplete: setupComplete,
      );
      if (response.subscriptionActive && setupComplete) {
        await _ref.read(branchScopeProvider.notifier).load();
      } else {
        _ref.invalidate(branchScopeProvider);
      }
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<void> completeRegistration(LoginResponseModel response) async {
    await _repository.saveSession(response);
    if (response.roles.isEmpty) {
      await _repository.logout();
      _ref.invalidate(branchScopeProvider);
      state = const AuthState();
      return;
    }
    _ref.invalidate(branchScopeProvider);
    final setupComplete = response.subscriptionActive
        ? await _refreshBusinessSetupValue()
        : false;
    state = AuthState(
      authenticated: true,
      roles: response.roles,
      subscriptionStatus: response.subscriptionStatus,
      subscriptionActive: response.subscriptionActive,
      businessSetupComplete: setupComplete,
    );
  }

  Future<void> updateSubscription({required String status, required bool active}) async {
    await _repository.updateSubscriptionState(status: status, active: active);
    final setupComplete = active ? await _refreshBusinessSetupValue() : false;
    state = state.copyWith(
      subscriptionStatus: status,
      subscriptionActive: active,
      businessSetupComplete: setupComplete,
    );
    if (active && setupComplete) {
      await _ref.read(branchScopeProvider.notifier).load();
    } else {
      _ref.invalidate(branchScopeProvider);
    }
  }

  Future<bool> refreshBusinessSetup() async {
    final complete = state.subscriptionActive ? await _refreshBusinessSetupValue() : false;
    state = state.copyWith(businessSetupComplete: complete);
    if (state.subscriptionActive && complete) {
      await _ref.read(branchScopeProvider.notifier).load();
    }
    return complete;
  }

  Future<bool> _refreshBusinessSetupValue() async {
    try {
      final complete = await _repository.fetchBusinessSetupComplete();
      await _repository.updateBusinessSetupState(complete);
      return complete;
    } catch (_) {
      return _repository.getStoredBusinessSetupComplete();
    }
  }

  Future<bool> requestPasswordRecovery(String email) async {
    state = state.copyWith(loading: true);
    try {
      await _repository.requestPasswordRecovery(email);
      state = state.copyWith(loading: false);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<bool> validatePasswordRecoveryCode(String code) async {
    state = state.copyWith(loading: true);
    try {
      await _repository.validatePasswordRecoveryCode(code);
      state = state.copyWith(loading: false);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<bool> resetPassword({required String code, required String newPassword, required String confirmPassword}) async {
    state = state.copyWith(loading: true);
    try {
      await _repository.resetPassword(code: code, newPassword: newPassword, confirmPassword: confirmPassword);
      state = state.copyWith(loading: false);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  bool _refreshingRoles = false;

  /// Refresca los permisos sin tocar el JWT ni expulsar al usuario.
  Future<void> refreshAssignedRoles() async {
    if (!state.authenticated || _refreshingRoles) return;
    _refreshingRoles = true;
    try {
      final latest = await _repository.fetchCurrentRoles();
      if (!mounted || !state.authenticated) return;
      final previous = state.roles.map((r) => r.trim().toUpperCase()).toSet();
      final current = latest.map((r) => r.trim().toUpperCase()).toSet();
      if (previous.length == current.length && previous.containsAll(current)) return;
      await _repository.storeCurrentRoles(latest);
      if (!mounted || !state.authenticated) return;
      state = state.copyWith(roles: latest);
      // Se invalida el menú en caché y la selección de roles obsoletos.
      _ref.invalidate(selectedRolesProvider);
      _ref.invalidate(userMenuProvider);
      // Los roles pueden modificar el alcance de sucursales. Volver a cargar
      // el catálogo permitido descarta la sede activa que haya sido revocada.
      await _ref.read(branchScopeProvider.notifier).load();
    } catch (_) {
      // Errores de red no deben invalidar una sesión operativa.
    } finally {
      _refreshingRoles = false;
    }
  }

  Future<void> logout() async {
    ErrorTelemetry.instance.clearSession();
    // El router escucha este estado. Se cambia primero para que el usuario vaya
    // al login de inmediato, sin esperar red, timeout ni respuesta del backend.
    _ref.invalidate(branchScopeProvider);
    state = const AuthState();

    try {
      await _logout();
    } catch (_) {
      // Protección adicional si incluso el almacenamiento local fallara. El
      // estado visual ya quedó cerrado y no debe volver a una pantalla cargando.
      try {
        await _ref.read(secureStorageProvider).clear();
      } catch (_) {}
    }
  }
}
