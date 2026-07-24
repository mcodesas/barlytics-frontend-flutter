import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/marcas_repository.dart';
import '../models/marcas_response_model.dart';

class MarcasRepositoryImpl implements MarcasRepository {
  MarcasRepositoryImpl(this._repository);
  final CrudRepository<MarcasResponseModel> _repository;

  @override
  Future<List<MarcasResponseModel>> list() => _repository.list();
  @override
  Future<MarcasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MarcasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MarcasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
