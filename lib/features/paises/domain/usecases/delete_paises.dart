import '../../data/models/paises_response_model.dart';
import '../repositories/paises_repository.dart';

class DeletePaisesUseCase {
  const DeletePaisesUseCase(this._repository);
  final PaisesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
