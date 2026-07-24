import '../../data/models/menus_response_model.dart';
import '../repositories/menus_repository.dart';

class GetMenusUseCase {
  const GetMenusUseCase(this._repository);
  final MenusRepository _repository;
  Future<MenusResponseModel> call(Object id) => _repository.findById(id);
}
