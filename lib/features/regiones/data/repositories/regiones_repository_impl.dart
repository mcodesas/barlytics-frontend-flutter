import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/regiones_repository.dart';
import '../models/regiones_response_model.dart';

class RegionesRepositoryImpl implements RegionesRepository {
  RegionesRepositoryImpl(this._repository);
  final CrudRepository<RegionesResponseModel> _repository;

  @override
  Future<List<RegionesResponseModel>> list() => _repository.list();
  @override
  Future<RegionesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<RegionesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<RegionesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
