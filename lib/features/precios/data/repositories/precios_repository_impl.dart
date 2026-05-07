import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/precios_repository.dart';
import '../models/precios_response_model.dart';

class PreciosRepositoryImpl implements PreciosRepository {
  PreciosRepositoryImpl(this._repository);
  final CrudRepository<PreciosResponseModel> _repository;

  @override
  Future<List<PreciosResponseModel>> list() => _repository.list();
  @override
  Future<PreciosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<PreciosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<PreciosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
