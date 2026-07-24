import '../../data/models/tipos_producto_response_model.dart';
import '../repositories/tipos_producto_repository.dart';

class UpdateTiposProductoUseCase {
  const UpdateTiposProductoUseCase(this._repository);
  final TiposProductoRepository _repository;
  Future<TiposProductoResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
