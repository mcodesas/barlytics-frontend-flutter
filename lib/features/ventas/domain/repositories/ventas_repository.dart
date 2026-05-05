import '../../data/models/ventas_response_model.dart';

abstract class VentasRepository {
  Future<List<VentasResponseModel>> list();
  Future<VentasResponseModel> findById(Object id);
  Future<VentasResponseModel> create(Map<String, dynamic> body);
  Future<VentasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
