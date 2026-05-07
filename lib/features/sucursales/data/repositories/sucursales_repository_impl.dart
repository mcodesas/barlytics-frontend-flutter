import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/sucursales_repository.dart';
import '../models/sucursales_response_model.dart';

class SucursalesRepositoryImpl implements SucursalesRepository {
  SucursalesRepositoryImpl(this._repository);
  final CrudRepository<SucursalesResponseModel> _repository;

  @override
  Future<List<SucursalesResponseModel>> list() => _repository.list();
  @override
  Future<SucursalesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<SucursalesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<SucursalesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
