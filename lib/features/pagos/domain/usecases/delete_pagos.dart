import '../../data/models/pagos_response_model.dart';
import '../repositories/pagos_repository.dart';

class DeletePagosUseCase {
  const DeletePagosUseCase(this._repository);
  final PagosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
