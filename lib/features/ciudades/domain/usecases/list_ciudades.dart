import '../../data/models/ciudades_response_model.dart';
import '../repositories/ciudades_repository.dart';

class ListCiudadesUseCase {
  const ListCiudadesUseCase(this._repository);
  final CiudadesRepository _repository;
  Future<List<CiudadesResponseModel>> call() => _repository.list();
}
