import '../../data/models/detalle_cuenta_venta_response_model.dart';
import '../repositories/detalle_cuenta_venta_repository.dart';

class DeleteDetalleCuentaVentaUseCase {
  const DeleteDetalleCuentaVentaUseCase(this._repository);
  final DetalleCuentaVentaRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
