import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/ciudades_repository.dart';
import '../models/ciudades_response_model.dart';

class CiudadesRepositoryImpl implements CiudadesRepository {
  CiudadesRepositoryImpl(this._repository);
  final CrudRepository<CiudadesResponseModel> _repository;

  @override
  Future<List<CiudadesResponseModel>> list() => _repository.list();
  @override
  Future<CiudadesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<CiudadesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<CiudadesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
