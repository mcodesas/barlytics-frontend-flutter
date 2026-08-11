import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/network/session_expiration_notifier.dart';
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

final googleAuthConfigProvider = FutureProvider<GoogleAuthConfigModel>((ref) {
  return ref.watch(authRepositoryProvider).googleConfig();
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
    this.failure,
    this.roles = const <String>[],
    this.subscriptionStatus,
    this.subscriptionActive = true,
  });

  final bool authenticated;
  final bool loading;
  final Failure? failure;

  /// Roles del usuario autenticado devueltos por el backend en el login.
  /// Se usan para consultar MENUS/OPCIONMENU y pintar la navegación permitida.
  final List<String> roles;
  final String? subscriptionStatus;
  final bool subscriptionActive;

  AuthState copyWith({
    bool? authenticated,
    bool? loading,
    Failure? failure,
    List<String>? roles,
    String? subscriptionStatus,
    bool? subscriptionActive,
  }) =>
      AuthState(
        authenticated: authenticated ?? this.authenticated,
        loading: loading ?? this.loading,
        failure: failure,
        roles: roles ?? this.roles,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._login,
    this._logout,
    this._repository,
    this._sessionExpirationNotifier,
    this._ref,
  ) : super(const AuthState()) {
    _sessionExpirationNotifier.addListener(_handleSessionExpired);
    checkSession();
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final AuthRepository _repository;
  final SessionExpirationNotifier _sessionExpirationNotifier;
  final Ref _ref;

  void _handleSessionExpired() {
    if (!state.authenticated) return;
    _ref.invalidate(branchScopeProvider);
    state = const AuthState();
  }

  @override
  void dispose() {
    _sessionExpirationNotifier.removeListener(_handleSessionExpired);
    super.dispose();
  }

  Future<void> checkSession() async {
    final hasSession = await _repository.hasSession();
    final roles = hasSession ? await _repository.getStoredRoles() : const <String>[];
    final subscriptionStatus = hasSession ? await _repository.getStoredSubscriptionStatus() : null;
    final subscriptionActive = hasSession ? await _repository.getStoredSubscriptionActive() : true;
    state = state.copyWith(
      authenticated: hasSession,
      roles: roles,
      subscriptionStatus: subscriptionStatus,
      subscriptionActive: subscriptionActive,
    );
    if (hasSession && subscriptionActive) {
      await _ref.read(branchScopeProvider.notifier).load();
    }
  }

  Future<bool> login(String identificador, String password) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _login(identificador, password);
      state = AuthState(
        authenticated: true,
        roles: response.roles,
        subscriptionStatus: response.subscriptionStatus,
        subscriptionActive: response.subscriptionActive,
      );
      if (response.subscriptionActive) {
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
      state = AuthState(
        authenticated: true,
        roles: response.roles,
        subscriptionStatus: response.subscriptionStatus,
        subscriptionActive: response.subscriptionActive,
      );
      if (response.subscriptionActive) {
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
    _ref.invalidate(branchScopeProvider);
    state = AuthState(
      authenticated: true,
      roles: response.roles,
      subscriptionStatus: response.subscriptionStatus,
      subscriptionActive: response.subscriptionActive,
    );
  }

  Future<void> updateSubscription({required String status, required bool active}) async {
    await _repository.updateSubscriptionState(status: status, active: active);
    state = state.copyWith(subscriptionStatus: status, subscriptionActive: active);
    if (active) {
      await _ref.read(branchScopeProvider.notifier).load();
    } else {
      _ref.invalidate(branchScopeProvider);
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

  Future<void> logout() async {
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
