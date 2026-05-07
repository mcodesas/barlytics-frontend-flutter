import '../../data/models/productos_response_model.dart';
import '../repositories/productos_repository.dart';

class DeleteProductosUseCase {
  const DeleteProductosUseCase(this._repository);
  final ProductosRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
