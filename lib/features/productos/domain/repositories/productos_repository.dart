import '../../data/models/productos_response_model.dart';

abstract class ProductosRepository {
  Future<List<ProductosResponseModel>> list();
  Future<ProductosResponseModel> findById(Object id);
  Future<ProductosResponseModel> create(Map<String, dynamic> body);
  Future<ProductosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
