import '../../data/models/cuentas_venta_response_model.dart';
import '../repositories/cuentas_venta_repository.dart';

class DeleteCuentasVentaUseCase {
  const DeleteCuentasVentaUseCase(this._repository);
  final CuentasVentaRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
