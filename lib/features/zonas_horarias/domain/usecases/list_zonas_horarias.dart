import '../../data/models/zonas_horarias_response_model.dart';
import '../repositories/zonas_horarias_repository.dart';

class ListZonasHorariasUseCase {
  const ListZonasHorariasUseCase(this._repository);
  final ZonasHorariasRepository _repository;
  Future<List<ZonasHorariasResponseModel>> call() => _repository.list();
}
