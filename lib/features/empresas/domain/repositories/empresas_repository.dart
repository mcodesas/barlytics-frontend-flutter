import '../../data/models/empresas_response_model.dart';

abstract class EmpresasRepository {
  Future<List<EmpresasResponseModel>> list();
  Future<EmpresasResponseModel> findById(Object id);
  Future<EmpresasResponseModel> create(Map<String, dynamic> body);
  Future<EmpresasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
