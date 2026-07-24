import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/empresas_repository.dart';
import '../models/empresas_response_model.dart';

class EmpresasRepositoryImpl implements EmpresasRepository {
  EmpresasRepositoryImpl(this._repository);
  final CrudRepository<EmpresasResponseModel> _repository;

  @override
  Future<List<EmpresasResponseModel>> list() => _repository.list();
  @override
  Future<EmpresasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<EmpresasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<EmpresasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
