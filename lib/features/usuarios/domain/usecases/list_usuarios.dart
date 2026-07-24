import '../../data/models/usuarios_response_model.dart';
import '../repositories/usuarios_repository.dart';

class ListUsuariosUseCase {
  const ListUsuariosUseCase(this._repository);
  final UsuariosRepository _repository;
  Future<List<UsuariosResponseModel>> call() => _repository.list();
}
