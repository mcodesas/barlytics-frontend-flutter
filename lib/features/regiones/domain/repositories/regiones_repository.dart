import '../../data/models/regiones_response_model.dart';

abstract class RegionesRepository {
  Future<List<RegionesResponseModel>> list();
  Future<RegionesResponseModel> findById(Object id);
  Future<RegionesResponseModel> create(Map<String, dynamic> body);
  Future<RegionesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
