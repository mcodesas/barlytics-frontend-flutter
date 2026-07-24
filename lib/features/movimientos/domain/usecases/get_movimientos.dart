import '../../data/models/movimientos_response_model.dart';
import '../repositories/movimientos_repository.dart';

class GetMovimientosUseCase {
  const GetMovimientosUseCase(this._repository);
  final MovimientosRepository _repository;
  Future<MovimientosResponseModel> call(Object id) => _repository.findById(id);
}
