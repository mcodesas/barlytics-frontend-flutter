import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/movimientos_repository.dart';
import '../models/movimientos_response_model.dart';

class MovimientosRepositoryImpl implements MovimientosRepository {
  MovimientosRepositoryImpl(this._repository);
  final CrudRepository<MovimientosResponseModel> _repository;

  @override
  Future<List<MovimientosResponseModel>> list() => _repository.list();
  @override
  Future<MovimientosResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MovimientosResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MovimientosResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
