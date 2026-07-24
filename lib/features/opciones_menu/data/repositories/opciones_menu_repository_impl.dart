import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/opciones_menu_repository.dart';
import '../models/opciones_menu_response_model.dart';

class OpcionesMenuRepositoryImpl implements OpcionesMenuRepository {
  OpcionesMenuRepositoryImpl(this._repository);
  final CrudRepository<OpcionesMenuResponseModel> _repository;

  @override
  Future<List<OpcionesMenuResponseModel>> list() => _repository.list();
  @override
  Future<OpcionesMenuResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<OpcionesMenuResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<OpcionesMenuResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
