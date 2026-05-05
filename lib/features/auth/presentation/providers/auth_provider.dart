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
  const AuthState({this.authenticated = false, this.loading = false, this.failure});
  final bool authenticated;
  final bool loading;
  final Failure? failure;
  AuthState copyWith({bool? authenticated, bool? loading, Failure? failure}) => AuthState(
        authenticated: authenticated ?? this.authenticated,
        loading: loading ?? this.loading,
        failure: failure,
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
    state = state.copyWith(authenticated: hasSession);
  }

  Future<bool> login(String identificador, String password) async {
    state = state.copyWith(loading: true);
    try {
      await _login(identificador, password);
      state = const AuthState(authenticated: true);
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
