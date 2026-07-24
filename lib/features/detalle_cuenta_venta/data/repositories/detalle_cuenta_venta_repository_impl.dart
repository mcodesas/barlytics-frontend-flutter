import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/detalle_cuenta_venta_repository.dart';
import '../models/detalle_cuenta_venta_response_model.dart';

class DetalleCuentaVentaRepositoryImpl implements DetalleCuentaVentaRepository {
  DetalleCuentaVentaRepositoryImpl(this._repository);
  final CrudRepository<DetalleCuentaVentaResponseModel> _repository;

  @override
  Future<List<DetalleCuentaVentaResponseModel>> list() => _repository.list();
  @override
  Future<DetalleCuentaVentaResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<DetalleCuentaVentaResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<DetalleCuentaVentaResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
