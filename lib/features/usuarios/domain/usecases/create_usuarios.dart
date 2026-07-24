import '../../data/models/usuarios_response_model.dart';
import '../repositories/usuarios_repository.dart';

class CreateUsuariosUseCase {
  const CreateUsuariosUseCase(this._repository);
  final UsuariosRepository _repository;
  Future<UsuariosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
