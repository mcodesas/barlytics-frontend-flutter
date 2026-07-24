import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/paises_repository.dart';
import '../models/paises_response_model.dart';

class PaisesRepositoryImpl implements PaisesRepository {
  PaisesRepositoryImpl(this._repository);
  final CrudRepository<PaisesResponseModel> _repository;

  @override
  Future<List<PaisesResponseModel>> list() => _repository.list();
  @override
  Future<PaisesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<PaisesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<PaisesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
