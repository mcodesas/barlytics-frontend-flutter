import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/pagos_repository.dart';
import '../models/pagos_response_model.dart';

class PagosRepositoryImpl implements PagosRepository {
  PagosRepositoryImpl(this._repository);
  final CrudRepository<PagosResponseModel> _repository;

  @override
  Future<List<PagosResponseModel>> list() => _repository.list();
  @override
  Future<PagosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<PagosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<PagosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
