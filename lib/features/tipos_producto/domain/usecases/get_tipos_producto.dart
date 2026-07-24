import '../../data/models/tipos_producto_response_model.dart';
import '../repositories/tipos_producto_repository.dart';

class GetTiposProductoUseCase {
  const GetTiposProductoUseCase(this._repository);
  final TiposProductoRepository _repository;
  Future<TiposProductoResponseModel> call(Object id) => _repository.findById(id);
}
