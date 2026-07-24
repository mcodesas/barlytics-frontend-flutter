import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<LoginResponseModel> login(String identificador, String password);
  Future<void> logout();
  Future<bool> hasSession();
  Future<void> requestPasswordRecovery(String email);
  Future<void> validatePasswordRecoveryCode(String code);
  Future<void> resetPassword({required String code, required String newPassword, required String confirmPassword});

  /// Obtiene desde almacenamiento seguro los roles persistidos tras el login.
  /// Esto permite reconstruir el menú autorizado al refrescar el navegador.
  Future<List<String>> getStoredRoles();
}
