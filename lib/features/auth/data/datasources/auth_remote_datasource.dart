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

  Future<void> logout() async {
    await _apiClient.post<void>(ApiPaths.authLogout, null, (_) => null);
  }
}
