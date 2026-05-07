import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<LoginResponseModel> login(String identificador, String password);
  Future<void> logout();
  Future<bool> hasSession();

  /// Obtiene desde almacenamiento seguro los roles persistidos tras el login.
  /// Esto permite reconstruir el menú autorizado al refrescar el navegador.
  Future<List<String>> getStoredRoles();
}
