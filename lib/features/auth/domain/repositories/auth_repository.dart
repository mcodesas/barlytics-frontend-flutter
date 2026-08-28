import '../../data/models/google_auth_models.dart';
import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<LoginResponseModel> login(String identificador, String password);
  Future<GoogleAuthConfigModel> googleConfig();
  Future<GoogleIdentityModel> googleIdentity(String idToken);
  Future<LoginResponseModel> googleLogin(String idToken);
  Future<void> saveSession(LoginResponseModel response);
  Future<void> logout();
  Future<bool> hasSession();
  Future<void> requestPasswordRecovery(String email);
  Future<void> validatePasswordRecoveryCode(String code);
  Future<void> resetPassword({required String code, required String newPassword, required String confirmPassword});

  /// Obtiene desde almacenamiento seguro los roles persistidos tras el login.
  /// Esto permite reconstruir el menú autorizado al refrescar el navegador.
  Future<List<String>> getStoredRoles();
  Future<String?> getStoredSubscriptionStatus();
  Future<bool> getStoredSubscriptionActive();
  Future<bool> getStoredBusinessSetupComplete();
  Future<bool> fetchBusinessSetupComplete();
  Future<void> updateBusinessSetupState(bool complete);
  Future<void> updateSubscriptionState({required String status, required bool active});
}
