import '../../data/models/zonas_horarias_response_model.dart';
import '../repositories/zonas_horarias_repository.dart';

class CreateZonasHorariasUseCase {
  const CreateZonasHorariasUseCase(this._repository);
  final ZonasHorariasRepository _repository;
  Future<ZonasHorariasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
