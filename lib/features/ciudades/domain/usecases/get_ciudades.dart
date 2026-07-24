import '../../data/models/ciudades_response_model.dart';
import '../repositories/ciudades_repository.dart';

class GetCiudadesUseCase {
  const GetCiudadesUseCase(this._repository);
  final CiudadesRepository _repository;
  Future<CiudadesResponseModel> call(Object id) => _repository.findById(id);
}
