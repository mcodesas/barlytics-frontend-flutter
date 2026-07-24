import '../../data/models/sucursales_response_model.dart';
import '../repositories/sucursales_repository.dart';

class DeleteSucursalesUseCase {
  const DeleteSucursalesUseCase(this._repository);
  final SucursalesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
