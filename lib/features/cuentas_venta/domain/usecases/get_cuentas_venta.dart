import '../../data/models/cuentas_venta_response_model.dart';
import '../repositories/cuentas_venta_repository.dart';

class GetCuentasVentaUseCase {
  const GetCuentasVentaUseCase(this._repository);
  final CuentasVentaRepository _repository;
  Future<CuentasVentaResponseModel> call(Object id) => _repository.findById(id);
}
