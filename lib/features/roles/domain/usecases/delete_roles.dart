import '../../data/models/roles_response_model.dart';
import '../repositories/roles_repository.dart';

class DeleteRolesUseCase {
  const DeleteRolesUseCase(this._repository);
  final RolesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
