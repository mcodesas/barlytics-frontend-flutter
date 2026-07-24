import '../../data/models/ciudades_response_model.dart';
import '../repositories/ciudades_repository.dart';

class CreateCiudadesUseCase {
  const CreateCiudadesUseCase(this._repository);
  final CiudadesRepository _repository;
  Future<CiudadesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
