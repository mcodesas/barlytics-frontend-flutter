import '../../data/models/login_response_model.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;
  Future<LoginResponseModel> call(String identificador, String password) => _repository.login(identificador, password);
}
