import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/productos_repository.dart';
import '../models/productos_response_model.dart';

class ProductosRepositoryImpl implements ProductosRepository {
  ProductosRepositoryImpl(this._repository);
  final CrudRepository<ProductosResponseModel> _repository;

  @override
  Future<List<ProductosResponseModel>> list() => _repository.list();
  @override
  Future<ProductosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<ProductosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<ProductosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
