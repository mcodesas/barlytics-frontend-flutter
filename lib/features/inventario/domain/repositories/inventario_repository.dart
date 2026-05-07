import '../../data/models/inventario_response_model.dart';

abstract class InventarioRepository {
  Future<List<InventarioResponseModel>> list();
  Future<InventarioResponseModel> findById(Object id);
  Future<InventarioResponseModel> create(Map<String, dynamic> body);
  Future<InventarioResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
