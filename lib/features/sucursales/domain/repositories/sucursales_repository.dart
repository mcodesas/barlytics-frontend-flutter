import '../../data/models/sucursales_response_model.dart';

abstract class SucursalesRepository {
  Future<List<SucursalesResponseModel>> list();
  Future<SucursalesResponseModel> findById(Object id);
  Future<SucursalesResponseModel> create(Map<String, dynamic> body);
  Future<SucursalesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
