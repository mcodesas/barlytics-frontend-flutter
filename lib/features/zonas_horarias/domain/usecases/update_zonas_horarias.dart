import '../../data/models/zonas_horarias_response_model.dart';
import '../repositories/zonas_horarias_repository.dart';

class UpdateZonasHorariasUseCase {
  const UpdateZonasHorariasUseCase(this._repository);
  final ZonasHorariasRepository _repository;
  Future<ZonasHorariasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
