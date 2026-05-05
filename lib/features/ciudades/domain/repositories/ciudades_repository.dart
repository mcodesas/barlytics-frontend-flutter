import '../../data/models/ciudades_response_model.dart';

abstract class CiudadesRepository {
  Future<List<CiudadesResponseModel>> list();
  Future<CiudadesResponseModel> findById(Object id);
  Future<CiudadesResponseModel> create(Map<String, dynamic> body);
  Future<CiudadesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
