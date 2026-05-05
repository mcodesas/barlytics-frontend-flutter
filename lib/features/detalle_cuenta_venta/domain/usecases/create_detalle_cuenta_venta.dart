import '../../data/models/detalle_cuenta_venta_response_model.dart';
import '../repositories/detalle_cuenta_venta_repository.dart';

class CreateDetalleCuentaVentaUseCase {
  const CreateDetalleCuentaVentaUseCase(this._repository);
  final DetalleCuentaVentaRepository _repository;
  Future<DetalleCuentaVentaResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
