import '../../data/models/movimientos_response_model.dart';
import '../repositories/movimientos_repository.dart';

class DeleteMovimientosUseCase {
  const DeleteMovimientosUseCase(this._repository);
  final MovimientosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
