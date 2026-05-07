import '../../data/models/menus_response_model.dart';
import '../repositories/menus_repository.dart';

class DeleteMenusUseCase {
  const DeleteMenusUseCase(this._repository);
  final MenusRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
