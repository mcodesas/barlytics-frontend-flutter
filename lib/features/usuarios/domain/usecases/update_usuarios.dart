import '../../data/models/usuarios_response_model.dart';
import '../repositories/usuarios_repository.dart';

class UpdateUsuariosUseCase {
  const UpdateUsuariosUseCase(this._repository);
  final UsuariosRepository _repository;
  Future<UsuariosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
