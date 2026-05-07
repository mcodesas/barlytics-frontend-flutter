import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/cuentas_venta_repository.dart';
import '../models/cuentas_venta_response_model.dart';

class CuentasVentaRepositoryImpl implements CuentasVentaRepository {
  CuentasVentaRepositoryImpl(this._repository);
  final CrudRepository<CuentasVentaResponseModel> _repository;

  @override
  Future<List<CuentasVentaResponseModel>> list() => _repository.list();
  @override
  Future<CuentasVentaResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<CuentasVentaResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<CuentasVentaResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
