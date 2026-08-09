import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<LoginResponseModel> login(LoginRequestModel request) async {
    final response = await _apiClient.post<LoginResponseModel>(
      ApiPaths.authLogin,
      request.toJson(),
      (json) => LoginResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
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
