import '../../data/models/inventario_response_model.dart';
import '../repositories/inventario_repository.dart';

class GetInventarioUseCase {
  const GetInventarioUseCase(this._repository);
  final InventarioRepository _repository;
  Future<InventarioResponseModel> call(Object id) => _repository.findById(id);
}
