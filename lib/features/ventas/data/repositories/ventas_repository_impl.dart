import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/ventas_repository.dart';
import '../models/ventas_response_model.dart';

class VentasRepositoryImpl implements VentasRepository {
  VentasRepositoryImpl(this._repository);
  final CrudRepository<VentasResponseModel> _repository;

  @override
  Future<List<VentasResponseModel>> list() => _repository.list();
  @override
  Future<VentasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<VentasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<VentasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
