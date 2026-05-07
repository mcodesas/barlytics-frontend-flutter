import '../../data/models/marcas_response_model.dart';
import '../repositories/marcas_repository.dart';

class DeleteMarcasUseCase {
  const DeleteMarcasUseCase(this._repository);
  final MarcasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
