import '../../data/models/sucursales_response_model.dart';
import '../repositories/sucursales_repository.dart';

class GetSucursalesUseCase {
  const GetSucursalesUseCase(this._repository);
  final SucursalesRepository _repository;
  Future<SucursalesResponseModel> call(Object id) => _repository.findById(id);
}
