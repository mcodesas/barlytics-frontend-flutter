import '../../data/models/ciudades_response_model.dart';
import '../repositories/ciudades_repository.dart';

class DeleteCiudadesUseCase {
  const DeleteCiudadesUseCase(this._repository);
  final CiudadesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
