import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/google_auth_models.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<List<String>> currentRoles() async {
    final response = await _apiClient.get<List<String>>(
      '/api/v1/me/roles',
      (json) => (json as List).map((item) => item.toString()).toList(growable: false),
    );
    return response.data ?? const <String>[];
  }

  Future<void> revokeDevice(String refreshToken) async {
    try {
      await _apiClient.post<void>(
        '/api/v1/auth/device/revoke', {'refreshToken': refreshToken}, (_) => null,
      );
    } catch (_) {
      // Sesión ya eliminada localmente.
    }
  }

  Future<LoginResponseModel> login(LoginRequestModel request) async {
    final response = await _apiClient.post<LoginResponseModel>(
      ApiPaths.authLogin,
      request.toJson(),
      (json) => LoginResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<GoogleAuthConfigModel> googleConfig() async {
    final response = await _apiClient.get<GoogleAuthConfigModel>(
      ApiPaths.authGoogleConfig,
      (json) => GoogleAuthConfigModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data ?? const GoogleAuthConfigModel(enabled: false);
  }

  Future<GoogleIdentityModel> googleIdentity(String idToken) async {
    final response = await _apiClient.post<GoogleIdentityModel>(
      ApiPaths.authGoogleIdentity,
      <String, dynamic>{'idToken': idToken},
      (json) => GoogleIdentityModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible validar la identidad de Google.');
    return response.data!;
  }

  Future<LoginResponseModel> googleLogin(String idToken) async {
    final response = await _apiClient.post<LoginResponseModel>(
      ApiPaths.authGoogleLogin,
      <String, dynamic>{'idToken': idToken},
      (json) => LoginResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible iniciar sesión con Google.');
    return response.data!;
  }

  Future<LoginResponseModel> appleLogin(String idToken) async {
    final response = await _apiClient.post<LoginResponseModel>(
      ApiPaths.authAppleLogin,
      <String, dynamic>{'idToken': idToken},
      (json) => LoginResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible iniciar sesión con Apple.');
    return response.data!;
  }

  Future<bool> businessSetupComplete() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.businessSetupStatus,
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data?['complete'] == true;
  }

  Future<void> logout({String? token}) async {
    final authorization = token == null || token.trim().isEmpty ? null : 'Bearer $token';
    await _apiClient.post<void>(
      ApiPaths.authLogout,
      null,
      (_) => null,
      headers: authorization == null ? null : {'Authorization': authorization},
    );
  }

  Future<void> requestPasswordRecovery(String email) async {
    await _apiClient.post<void>(
      ApiPaths.authForgotPassword,
      {'email': email},
      (_) => null,
    );
  }

  Future<void> validatePasswordRecoveryCode(String code) async {
    await _apiClient.get<void>(
      ApiPaths.authPasswordRecoveryValidate,
      (_) => null,
      queryParameters: {'code': code},
    );
  }

  Future<void> resetPassword({
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.post<void>(
      ApiPaths.authResetPassword,
      {
        'code': code,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      (_) => null,
    );
  }
}
