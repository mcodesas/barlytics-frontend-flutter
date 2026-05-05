import '../../data/models/tipos_producto_response_model.dart';
import '../repositories/tipos_producto_repository.dart';

class CreateTiposProductoUseCase {
  const CreateTiposProductoUseCase(this._repository);
  final TiposProductoRepository _repository;
  Future<TiposProductoResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
