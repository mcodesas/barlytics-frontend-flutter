import '../../data/models/empresas_response_model.dart';
import '../repositories/empresas_repository.dart';

class CreateEmpresasUseCase {
  const CreateEmpresasUseCase(this._repository);
  final EmpresasRepository _repository;
  Future<EmpresasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
