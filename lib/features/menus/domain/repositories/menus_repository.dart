import '../../data/models/menus_response_model.dart';

abstract class MenusRepository {
  Future<List<MenusResponseModel>> list();
  Future<MenusResponseModel> findById(Object id);
  Future<MenusResponseModel> create(Map<String, dynamic> body);
  Future<MenusResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
