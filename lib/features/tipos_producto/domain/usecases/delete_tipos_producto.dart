import '../../data/models/tipos_producto_response_model.dart';
import '../repositories/tipos_producto_repository.dart';

class DeleteTiposProductoUseCase {
  const DeleteTiposProductoUseCase(this._repository);
  final TiposProductoRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
