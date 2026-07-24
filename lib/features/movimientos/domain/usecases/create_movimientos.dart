import '../../data/models/movimientos_response_model.dart';
import '../repositories/movimientos_repository.dart';

class CreateMovimientosUseCase {
  const CreateMovimientosUseCase(this._repository);
  final MovimientosRepository _repository;
  Future<MovimientosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
