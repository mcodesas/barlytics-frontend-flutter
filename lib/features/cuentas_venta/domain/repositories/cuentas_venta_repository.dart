import '../../data/models/cuentas_venta_response_model.dart';

abstract class CuentasVentaRepository {
  Future<List<CuentasVentaResponseModel>> list();
  Future<CuentasVentaResponseModel> findById(Object id);
  Future<CuentasVentaResponseModel> create(Map<String, dynamic> body);
  Future<CuentasVentaResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
