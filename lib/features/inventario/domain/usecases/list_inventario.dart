import '../../data/models/inventario_response_model.dart';
import '../repositories/inventario_repository.dart';

class ListInventarioUseCase {
  const ListInventarioUseCase(this._repository);
  final InventarioRepository _repository;
  Future<List<InventarioResponseModel>> call() => _repository.list();
}
