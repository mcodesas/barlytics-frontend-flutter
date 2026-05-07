import '../../data/models/cuentas_venta_response_model.dart';
import '../repositories/cuentas_venta_repository.dart';

class UpdateCuentasVentaUseCase {
  const UpdateCuentasVentaUseCase(this._repository);
  final CuentasVentaRepository _repository;
  Future<CuentasVentaResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
