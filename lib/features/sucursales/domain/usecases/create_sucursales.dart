import '../../data/models/sucursales_response_model.dart';
import '../repositories/sucursales_repository.dart';

class CreateSucursalesUseCase {
  const CreateSucursalesUseCase(this._repository);
  final SucursalesRepository _repository;
  Future<SucursalesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
