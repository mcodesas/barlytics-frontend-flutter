import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/mesas_repository.dart';
import '../models/mesas_response_model.dart';

class MesasRepositoryImpl implements MesasRepository {
  MesasRepositoryImpl(this._repository);
  final CrudRepository<MesasResponseModel> _repository;

  @override
  Future<List<MesasResponseModel>> list() => _repository.list();
  @override
  Future<MesasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MesasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MesasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
