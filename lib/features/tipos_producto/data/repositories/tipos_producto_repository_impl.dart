import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/tipos_producto_repository.dart';
import '../models/tipos_producto_response_model.dart';

class TiposProductoRepositoryImpl implements TiposProductoRepository {
  TiposProductoRepositoryImpl(this._repository);
  final CrudRepository<TiposProductoResponseModel> _repository;

  @override
  Future<List<TiposProductoResponseModel>> list() => _repository.list();
  @override
  Future<TiposProductoResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<TiposProductoResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<TiposProductoResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
