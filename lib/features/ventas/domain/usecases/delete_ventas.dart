import '../../data/models/ventas_response_model.dart';
import '../repositories/ventas_repository.dart';

class DeleteVentasUseCase {
  const DeleteVentasUseCase(this._repository);
  final VentasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
