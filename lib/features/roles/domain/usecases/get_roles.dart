import '../../data/models/roles_response_model.dart';
import '../repositories/roles_repository.dart';

class GetRolesUseCase {
  const GetRolesUseCase(this._repository);
  final RolesRepository _repository;
  Future<RolesResponseModel> call(Object id) => _repository.findById(id);
}
