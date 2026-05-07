import '../../data/models/regiones_response_model.dart';
import '../repositories/regiones_repository.dart';

class DeleteRegionesUseCase {
  const DeleteRegionesUseCase(this._repository);
  final RegionesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
