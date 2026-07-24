import '../../data/models/medios_pago_response_model.dart';

abstract class MediosPagoRepository {
  Future<List<MediosPagoResponseModel>> list();
  Future<MediosPagoResponseModel> findById(Object id);
  Future<MediosPagoResponseModel> create(Map<String, dynamic> body);
  Future<MediosPagoResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
