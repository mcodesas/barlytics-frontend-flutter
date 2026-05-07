import '../../data/models/productos_response_model.dart';
import '../repositories/productos_repository.dart';

class GetProductosUseCase {
  const GetProductosUseCase(this._repository);
  final ProductosRepository _repository;
  Future<ProductosResponseModel> call(Object id) => _repository.findById(id);
}
