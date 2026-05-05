import '../../data/models/precios_response_model.dart';

abstract class PreciosRepository {
  Future<List<PreciosResponseModel>> list();
  Future<PreciosResponseModel> findById(Object id);
  Future<PreciosResponseModel> create(Map<String, dynamic> body);
  Future<PreciosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
