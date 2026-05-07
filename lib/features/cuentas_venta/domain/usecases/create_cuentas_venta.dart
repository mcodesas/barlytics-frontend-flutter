import '../../data/models/cuentas_venta_response_model.dart';
import '../repositories/cuentas_venta_repository.dart';

class CreateCuentasVentaUseCase {
  const CreateCuentasVentaUseCase(this._repository);
  final CuentasVentaRepository _repository;
  Future<CuentasVentaResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
