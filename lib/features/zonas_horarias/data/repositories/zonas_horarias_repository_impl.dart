import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/zonas_horarias_repository.dart';
import '../models/zonas_horarias_response_model.dart';

class ZonasHorariasRepositoryImpl implements ZonasHorariasRepository {
  ZonasHorariasRepositoryImpl(this._repository);
  final CrudRepository<ZonasHorariasResponseModel> _repository;

  @override
  Future<List<ZonasHorariasResponseModel>> list() => _repository.list();
  @override
  Future<ZonasHorariasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<ZonasHorariasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<ZonasHorariasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
