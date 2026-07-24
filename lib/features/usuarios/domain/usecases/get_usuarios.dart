import '../../data/models/usuarios_response_model.dart';
import '../repositories/usuarios_repository.dart';

class GetUsuariosUseCase {
  const GetUsuariosUseCase(this._repository);
  final UsuariosRepository _repository;
  Future<UsuariosResponseModel> call(Object id) => _repository.findById(id);
}
