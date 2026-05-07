import '../../data/models/mesas_response_model.dart';
import '../repositories/mesas_repository.dart';

class DeleteMesasUseCase {
  const DeleteMesasUseCase(this._repository);
  final MesasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
