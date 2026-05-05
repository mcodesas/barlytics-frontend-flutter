import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/menus_repository.dart';
import '../models/menus_response_model.dart';

class MenusRepositoryImpl implements MenusRepository {
  MenusRepositoryImpl(this._repository);
  final CrudRepository<MenusResponseModel> _repository;

  @override
  Future<List<MenusResponseModel>> list() => _repository.list();
  @override
  Future<MenusResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MenusResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MenusResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
