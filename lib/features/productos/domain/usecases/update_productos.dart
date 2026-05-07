import '../../data/models/productos_response_model.dart';
import '../repositories/productos_repository.dart';

class UpdateProductosUseCase {
  const UpdateProductosUseCase(this._repository);
  final ProductosRepository _repository;
  Future<ProductosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
