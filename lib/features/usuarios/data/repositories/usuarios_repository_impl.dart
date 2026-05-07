import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/usuarios_repository.dart';
import '../models/usuarios_response_model.dart';

class UsuariosRepositoryImpl implements UsuariosRepository {
  UsuariosRepositoryImpl(this._repository);
  final CrudRepository<UsuariosResponseModel> _repository;

  @override
  Future<List<UsuariosResponseModel>> list() => _repository.list();
  @override
  Future<UsuariosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<UsuariosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<UsuariosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
