import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/parametros_repository.dart';
import '../models/parametros_response_model.dart';

class ParametrosRepositoryImpl implements ParametrosRepository {
  ParametrosRepositoryImpl(this._repository);
  final CrudRepository<ParametrosResponseModel> _repository;

  @override
  Future<List<ParametrosResponseModel>> list() => _repository.list();
  @override
  Future<ParametrosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<ParametrosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<ParametrosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
