import '../../data/models/productos_response_model.dart';
import '../repositories/productos_repository.dart';

class ListProductosUseCase {
  const ListProductosUseCase(this._repository);
  final ProductosRepository _repository;
  Future<List<ProductosResponseModel>> call() => _repository.list();
}
