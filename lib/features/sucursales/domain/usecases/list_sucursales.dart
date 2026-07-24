import '../../data/models/sucursales_response_model.dart';
import '../repositories/sucursales_repository.dart';

class ListSucursalesUseCase {
  const ListSucursalesUseCase(this._repository);
  final SucursalesRepository _repository;
  Future<List<SucursalesResponseModel>> call() => _repository.list();
}
