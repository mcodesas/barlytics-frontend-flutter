import '../../data/models/zonas_horarias_response_model.dart';
import '../repositories/zonas_horarias_repository.dart';

class DeleteZonasHorariasUseCase {
  const DeleteZonasHorariasUseCase(this._repository);
  final ZonasHorariasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
