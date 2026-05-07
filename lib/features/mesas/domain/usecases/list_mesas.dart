import '../../data/models/mesas_response_model.dart';
import '../repositories/mesas_repository.dart';

class ListMesasUseCase {
  const ListMesasUseCase(this._repository);
  final MesasRepository _repository;
  Future<List<MesasResponseModel>> call() => _repository.list();
}
