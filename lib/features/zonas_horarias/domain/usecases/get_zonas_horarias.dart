import '../../data/models/zonas_horarias_response_model.dart';
import '../repositories/zonas_horarias_repository.dart';

class GetZonasHorariasUseCase {
  const GetZonasHorariasUseCase(this._repository);
  final ZonasHorariasRepository _repository;
  Future<ZonasHorariasResponseModel> call(Object id) => _repository.findById(id);
}
