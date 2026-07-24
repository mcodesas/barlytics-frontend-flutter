import '../../data/models/roles_response_model.dart';
import '../repositories/roles_repository.dart';

class UpdateRolesUseCase {
  const UpdateRolesUseCase(this._repository);
  final RolesRepository _repository;
  Future<RolesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
