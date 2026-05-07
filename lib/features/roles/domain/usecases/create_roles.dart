import '../../data/models/roles_response_model.dart';
import '../repositories/roles_repository.dart';

class CreateRolesUseCase {
  const CreateRolesUseCase(this._repository);
  final RolesRepository _repository;
  Future<RolesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
