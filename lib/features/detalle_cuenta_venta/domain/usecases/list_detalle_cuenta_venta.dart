import '../../data/models/detalle_cuenta_venta_response_model.dart';
import '../repositories/detalle_cuenta_venta_repository.dart';

class ListDetalleCuentaVentaUseCase {
  const ListDetalleCuentaVentaUseCase(this._repository);
  final DetalleCuentaVentaRepository _repository;
  Future<List<DetalleCuentaVentaResponseModel>> call() => _repository.list();
}
