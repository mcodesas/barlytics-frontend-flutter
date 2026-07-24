import '../../data/models/movimientos_response_model.dart';
import '../repositories/movimientos_repository.dart';

class UpdateMovimientosUseCase {
  const UpdateMovimientosUseCase(this._repository);
  final MovimientosRepository _repository;
  Future<MovimientosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
