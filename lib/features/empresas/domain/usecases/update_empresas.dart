import '../../data/models/empresas_response_model.dart';
import '../repositories/empresas_repository.dart';

class UpdateEmpresasUseCase {
  const UpdateEmpresasUseCase(this._repository);
  final EmpresasRepository _repository;
  Future<EmpresasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
