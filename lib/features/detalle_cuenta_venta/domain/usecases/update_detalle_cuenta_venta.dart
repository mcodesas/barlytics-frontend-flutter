import '../../data/models/detalle_cuenta_venta_response_model.dart';
import '../repositories/detalle_cuenta_venta_repository.dart';

class UpdateDetalleCuentaVentaUseCase {
  const UpdateDetalleCuentaVentaUseCase(this._repository);
  final DetalleCuentaVentaRepository _repository;
  Future<DetalleCuentaVentaResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
