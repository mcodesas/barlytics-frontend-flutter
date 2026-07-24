import '../../data/models/menus_response_model.dart';
import '../repositories/menus_repository.dart';

class UpdateMenusUseCase {
  const UpdateMenusUseCase(this._repository);
  final MenusRepository _repository;
  Future<MenusResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
