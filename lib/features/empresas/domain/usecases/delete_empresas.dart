import '../../data/models/empresas_response_model.dart';
import '../repositories/empresas_repository.dart';

class DeleteEmpresasUseCase {
  const DeleteEmpresasUseCase(this._repository);
  final EmpresasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
