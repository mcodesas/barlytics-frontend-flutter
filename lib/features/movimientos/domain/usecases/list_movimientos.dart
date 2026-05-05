import '../../data/models/movimientos_response_model.dart';
import '../repositories/movimientos_repository.dart';

class ListMovimientosUseCase {
  const ListMovimientosUseCase(this._repository);
  final MovimientosRepository _repository;
  Future<List<MovimientosResponseModel>> call() => _repository.list();
}
