import '../../data/models/empresas_response_model.dart';
import '../repositories/empresas_repository.dart';

class ListEmpresasUseCase {
  const ListEmpresasUseCase(this._repository);
  final EmpresasRepository _repository;
  Future<List<EmpresasResponseModel>> call() => _repository.list();
}
