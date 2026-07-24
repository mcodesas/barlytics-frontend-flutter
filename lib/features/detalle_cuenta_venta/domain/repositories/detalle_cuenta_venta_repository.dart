import '../../data/models/detalle_cuenta_venta_response_model.dart';

abstract class DetalleCuentaVentaRepository {
  Future<List<DetalleCuentaVentaResponseModel>> list();
  Future<DetalleCuentaVentaResponseModel> findById(Object id);
  Future<DetalleCuentaVentaResponseModel> create(Map<String, dynamic> body);
  Future<DetalleCuentaVentaResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
