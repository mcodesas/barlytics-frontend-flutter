import '../../data/models/productos_response_model.dart';
import '../repositories/productos_repository.dart';

class CreateProductosUseCase {
  const CreateProductosUseCase(this._repository);
  final ProductosRepository _repository;
  Future<ProductosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
