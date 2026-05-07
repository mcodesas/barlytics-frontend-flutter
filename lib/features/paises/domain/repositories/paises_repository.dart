import '../../data/models/paises_response_model.dart';

abstract class PaisesRepository {
  Future<List<PaisesResponseModel>> list();
  Future<PaisesResponseModel> findById(Object id);
  Future<PaisesResponseModel> create(Map<String, dynamic> body);
  Future<PaisesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
