import '../../data/models/inventario_response_model.dart';
import '../repositories/inventario_repository.dart';

class CreateInventarioUseCase {
  const CreateInventarioUseCase(this._repository);
  final InventarioRepository _repository;
  Future<InventarioResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
