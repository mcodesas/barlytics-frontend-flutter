import '../../data/models/tipos_producto_response_model.dart';
import '../repositories/tipos_producto_repository.dart';

class ListTiposProductoUseCase {
  const ListTiposProductoUseCase(this._repository);
  final TiposProductoRepository _repository;
  Future<List<TiposProductoResponseModel>> call() => _repository.list();
}
