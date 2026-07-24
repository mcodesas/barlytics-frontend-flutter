import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/inventario_repository.dart';
import '../models/inventario_response_model.dart';

class InventarioRepositoryImpl implements InventarioRepository {
  InventarioRepositoryImpl(this._repository);
  final CrudRepository<InventarioResponseModel> _repository;

  @override
  Future<List<InventarioResponseModel>> list() => _repository.list();
  @override
  Future<InventarioResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<InventarioResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<InventarioResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
