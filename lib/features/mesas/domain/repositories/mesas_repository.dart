import '../../data/models/mesas_response_model.dart';

abstract class MesasRepository {
  Future<List<MesasResponseModel>> list();
  Future<MesasResponseModel> findById(Object id);
  Future<MesasResponseModel> create(Map<String, dynamic> body);
  Future<MesasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
