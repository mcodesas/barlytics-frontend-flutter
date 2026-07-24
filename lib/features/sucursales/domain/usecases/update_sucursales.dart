import '../../data/models/sucursales_response_model.dart';
import '../repositories/sucursales_repository.dart';

class UpdateSucursalesUseCase {
  const UpdateSucursalesUseCase(this._repository);
  final SucursalesRepository _repository;
  Future<SucursalesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
