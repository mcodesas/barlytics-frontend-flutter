import '../../data/models/usuarios_response_model.dart';
import '../repositories/usuarios_repository.dart';

class DeleteUsuariosUseCase {
  const DeleteUsuariosUseCase(this._repository);
  final UsuariosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
