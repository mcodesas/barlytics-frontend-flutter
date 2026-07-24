import '../../data/models/marcas_response_model.dart';

abstract class MarcasRepository {
  Future<List<MarcasResponseModel>> list();
  Future<MarcasResponseModel> findById(Object id);
  Future<MarcasResponseModel> create(Map<String, dynamic> body);
  Future<MarcasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
