import '../../data/models/parametros_response_model.dart';
import '../repositories/parametros_repository.dart';

class DeleteParametrosUseCase {
  const DeleteParametrosUseCase(this._repository);
  final ParametrosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
