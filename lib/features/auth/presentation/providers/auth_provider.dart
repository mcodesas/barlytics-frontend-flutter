import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
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

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    LoginUseCase(ref.watch(authRepositoryProvider)),
    LogoutUseCase(ref.watch(authRepositoryProvider)),
    ref.watch(authRepositoryProvider),
  );
});

class AuthState {
  const AuthState({
    this.authenticated = false,
    this.loading = false,
    this.failure,
    this.roles = const <String>[],
  });

  final bool authenticated;
  final bool loading;
  final Failure? failure;

  /// Roles del usuario autenticado devueltos por el backend en el login.
  /// Se usan para consultar MENUS/OPCIONMENU y pintar la navegación permitida.
  final List<String> roles;

  AuthState copyWith({
    bool? authenticated,
    bool? loading,
    Failure? failure,
    List<String>? roles,
  }) =>
      AuthState(
        authenticated: authenticated ?? this.authenticated,
        loading: loading ?? this.loading,
        failure: failure,
        roles: roles ?? this.roles,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._login, this._logout, this._repository) : super(const AuthState()) {
    checkSession();
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final AuthRepository _repository;

  Future<void> checkSession() async {
    final hasSession = await _repository.hasSession();
    final roles = hasSession ? await _repository.getStoredRoles() : const <String>[];
    state = state.copyWith(authenticated: hasSession, roles: roles);
  }

  Future<bool> login(String identificador, String password) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _login(identificador, password);
      state = AuthState(authenticated: true, roles: response.roles);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
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
    await _logout();
    state = const AuthState();
  }
}
