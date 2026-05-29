import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  @override
  Future<LoginResponseModel> login(String identificador, String password) async {
    final response = await _remote.login(LoginRequestModel(identificador: identificador, password: password));
    await _storage.write(StorageKeys.authToken, response.token);
    if (response.userId != null) await _storage.write(StorageKeys.userId, response.userId.toString());
    if (response.empresaId != null) await _storage.write(StorageKeys.empresaId, response.empresaId.toString());
    if (response.sucursalId != null) await _storage.write(StorageKeys.sucursalId, response.sucursalId.toString());
    if (response.email != null) await _storage.write(StorageKeys.email, response.email!);
    await _storage.write(StorageKeys.roles, response.roles.join(','));
    return response;
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _storage.clear();
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
