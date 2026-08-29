import 'dart:async';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/google_auth_models.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  @override
  Future<LoginResponseModel> login(String identificador, String password) async {
    final response = await _remote.login(LoginRequestModel(identificador: identificador, password: password));
    await saveSession(response);
    return response;
  }

  @override
  Future<GoogleAuthConfigModel> googleConfig() => _remote.googleConfig();

  @override
  Future<GoogleIdentityModel> googleIdentity(String idToken) => _remote.googleIdentity(idToken);

  @override
  Future<LoginResponseModel> googleLogin(String idToken) async {
    final response = await _remote.googleLogin(idToken);
    await saveSession(response);
    return response;
  }

  @override
  Future<void> saveSession(LoginResponseModel response) async {
    await _storage.write(StorageKeys.authToken, response.token);
    if (response.userId != null) await _storage.write(StorageKeys.userId, response.userId.toString());
    if (response.empresaId != null) await _storage.write(StorageKeys.empresaId, response.empresaId.toString());
    if (response.sucursalId != null) await _storage.write(StorageKeys.sucursalId, response.sucursalId.toString());
    if (response.email != null) await _storage.write(StorageKeys.email, response.email!);
    await _storage.write(StorageKeys.roles, response.roles.join(','));
    await _storage.write(StorageKeys.subscriptionStatus, response.subscriptionStatus ?? '');
    await _storage.write(StorageKeys.subscriptionActive, response.subscriptionActive ? 'true' : 'false');
    if (!response.subscriptionActive) {
      await _storage.write(StorageKeys.businessSetupComplete, 'false');
    }
  }

  @override
  Future<void> logout() async {
    // El logout del usuario es local primero: nunca se bloquea la salida de la
    // aplicación esperando al backend. Se conserva el JWT solo para intentar
    // registrar el evento LOGOUT de forma no bloqueante.
    final token = await _storage.read(StorageKeys.authToken);
    await _storage.clear();

    if (token != null && token.trim().isNotEmpty) {
      unawaited(_notifyRemoteLogout(token));
    }
  }

  Future<void> _notifyRemoteLogout(String token) async {
    try {
      await _remote.logout(token: token);
    } catch (_) {
      // El registro remoto de logout es best-effort. La sesión local ya fue
      // eliminada y no debe restaurarse ni mostrar errores por este fallo.
    }
  }

  @override
  Future<bool> hasSession() async {
    final token = await _storage.read(StorageKeys.authToken);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> requestPasswordRecovery(String email) => _remote.requestPasswordRecovery(email);

  @override
  Future<void> validatePasswordRecoveryCode(String code) => _remote.validatePasswordRecoveryCode(code);

  @override
  Future<void> resetPassword({required String code, required String newPassword, required String confirmPassword}) {
    return _remote.resetPassword(code: code, newPassword: newPassword, confirmPassword: confirmPassword);
  }

  @override
  Future<String?> getStoredSubscriptionStatus() => _storage.read(StorageKeys.subscriptionStatus);

  @override
  Future<bool> getStoredSubscriptionActive() async {
    final raw = await _storage.read(StorageKeys.subscriptionActive);
    // Sesiones anteriores al módulo SaaS se consideran activas para no romper compatibilidad.
    return raw == null || raw.isEmpty || raw.toLowerCase() == 'true';
  }

  @override
  Future<void> updateSubscriptionState({required String status, required bool active}) async {
    await _storage.write(StorageKeys.subscriptionStatus, status);
    await _storage.write(StorageKeys.subscriptionActive, active ? 'true' : 'false');
  }

  @override
  Future<bool> getStoredBusinessSetupComplete() async {
    final raw = await _storage.read(StorageKeys.businessSetupComplete);
    return raw != null && raw.toLowerCase() == 'true';
  }

  @override
  Future<bool> fetchBusinessSetupComplete() => _remote.businessSetupComplete();

  @override
  Future<void> updateBusinessSetupState(bool complete) =>
      _storage.write(StorageKeys.businessSetupComplete, complete ? 'true' : 'false');

  @override
  Future<List<String>> getStoredRoles() async {
    final raw = await _storage.read(StorageKeys.roles);
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
  }
}
