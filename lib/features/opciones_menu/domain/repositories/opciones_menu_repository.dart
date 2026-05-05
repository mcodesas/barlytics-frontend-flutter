import '../../data/models/opciones_menu_response_model.dart';

abstract class OpcionesMenuRepository {
  Future<List<OpcionesMenuResponseModel>> list();
  Future<OpcionesMenuResponseModel> findById(Object id);
  Future<OpcionesMenuResponseModel> create(Map<String, dynamic> body);
  Future<OpcionesMenuResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
