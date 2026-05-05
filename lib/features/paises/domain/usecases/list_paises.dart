import '../../data/models/paises_response_model.dart';
import '../repositories/paises_repository.dart';

class ListPaisesUseCase {
  const ListPaisesUseCase(this._repository);
  final PaisesRepository _repository;
  Future<List<PaisesResponseModel>> call() => _repository.list();
}
