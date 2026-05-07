import '../../data/models/menus_response_model.dart';
import '../repositories/menus_repository.dart';

class ListMenusUseCase {
  const ListMenusUseCase(this._repository);
  final MenusRepository _repository;
  Future<List<MenusResponseModel>> call() => _repository.list();
}
