import '../../data/models/tipos_producto_response_model.dart';

abstract class TiposProductoRepository {
  Future<List<TiposProductoResponseModel>> list();
  Future<TiposProductoResponseModel> findById(Object id);
  Future<TiposProductoResponseModel> create(Map<String, dynamic> body);
  Future<TiposProductoResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
