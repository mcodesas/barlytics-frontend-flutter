import '../../data/models/parametros_response_model.dart';

abstract class ParametrosRepository {
  Future<List<ParametrosResponseModel>> list();
  Future<ParametrosResponseModel> findById(Object id);
  Future<ParametrosResponseModel> create(Map<String, dynamic> body);
  Future<ParametrosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
