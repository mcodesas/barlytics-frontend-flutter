import '../../data/models/precios_response_model.dart';
import '../repositories/precios_repository.dart';

class DeletePreciosUseCase {
  const DeletePreciosUseCase(this._repository);
  final PreciosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
