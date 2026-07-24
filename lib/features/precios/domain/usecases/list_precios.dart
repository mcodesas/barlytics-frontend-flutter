import '../../data/models/precios_response_model.dart';
import '../repositories/precios_repository.dart';

class ListPreciosUseCase {
  const ListPreciosUseCase(this._repository);
  final PreciosRepository _repository;
  Future<List<PreciosResponseModel>> call() => _repository.list();
}
