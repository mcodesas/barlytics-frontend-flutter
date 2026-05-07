import '../../data/models/detalle_cuenta_venta_response_model.dart';
import '../repositories/detalle_cuenta_venta_repository.dart';

class GetDetalleCuentaVentaUseCase {
  const GetDetalleCuentaVentaUseCase(this._repository);
  final DetalleCuentaVentaRepository _repository;
  Future<DetalleCuentaVentaResponseModel> call(Object id) => _repository.findById(id);
}
