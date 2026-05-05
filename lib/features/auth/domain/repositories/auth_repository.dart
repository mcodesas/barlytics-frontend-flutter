import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<LoginResponseModel> login(String identificador, String password);
  Future<void> logout();
  Future<bool> hasSession();
}
