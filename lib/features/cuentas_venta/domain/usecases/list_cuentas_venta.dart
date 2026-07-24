import '../../data/models/cuentas_venta_response_model.dart';
import '../repositories/cuentas_venta_repository.dart';

class ListCuentasVentaUseCase {
  const ListCuentasVentaUseCase(this._repository);
  final CuentasVentaRepository _repository;
  Future<List<CuentasVentaResponseModel>> call() => _repository.list();
}
