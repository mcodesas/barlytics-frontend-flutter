import '../../data/models/roles_response_model.dart';
import '../repositories/roles_repository.dart';

class ListRolesUseCase {
  const ListRolesUseCase(this._repository);
  final RolesRepository _repository;
  Future<List<RolesResponseModel>> call() => _repository.list();
}
