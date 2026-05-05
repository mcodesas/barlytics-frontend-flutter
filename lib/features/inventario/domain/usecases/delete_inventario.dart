import '../../data/models/inventario_response_model.dart';
import '../repositories/inventario_repository.dart';

class DeleteInventarioUseCase {
  const DeleteInventarioUseCase(this._repository);
  final InventarioRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
