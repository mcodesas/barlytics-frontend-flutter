import '../../data/models/roles_response_model.dart';

abstract class RolesRepository {
  Future<List<RolesResponseModel>> list();
  Future<RolesResponseModel> findById(Object id);
  Future<RolesResponseModel> create(Map<String, dynamic> body);
  Future<RolesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
