import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/roles_repository.dart';
import '../models/roles_response_model.dart';

class RolesRepositoryImpl implements RolesRepository {
  RolesRepositoryImpl(this._repository);
  final CrudRepository<RolesResponseModel> _repository;

  @override
  Future<List<RolesResponseModel>> list() => _repository.list();
  @override
  Future<RolesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<RolesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<RolesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
