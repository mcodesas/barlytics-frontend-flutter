import '../../data/models/usuarios_response_model.dart';

abstract class UsuariosRepository {
  Future<List<UsuariosResponseModel>> list();
  Future<UsuariosResponseModel> findById(Object id);
  Future<UsuariosResponseModel> create(Map<String, dynamic> body);
  Future<UsuariosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
