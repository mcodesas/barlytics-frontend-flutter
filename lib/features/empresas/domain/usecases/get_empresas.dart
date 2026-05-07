import '../../data/models/empresas_response_model.dart';
import '../repositories/empresas_repository.dart';

class GetEmpresasUseCase {
  const GetEmpresasUseCase(this._repository);
  final EmpresasRepository _repository;
  Future<EmpresasResponseModel> call(Object id) => _repository.findById(id);
}
