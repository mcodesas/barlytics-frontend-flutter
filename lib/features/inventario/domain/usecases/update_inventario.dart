import '../../data/models/inventario_response_model.dart';
import '../repositories/inventario_repository.dart';

class UpdateInventarioUseCase {
  const UpdateInventarioUseCase(this._repository);
  final InventarioRepository _repository;
  Future<InventarioResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
