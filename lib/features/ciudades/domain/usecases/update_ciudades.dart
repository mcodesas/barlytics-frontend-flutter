import '../../data/models/ciudades_response_model.dart';
import '../repositories/ciudades_repository.dart';

class UpdateCiudadesUseCase {
  const UpdateCiudadesUseCase(this._repository);
  final CiudadesRepository _repository;
  Future<CiudadesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
