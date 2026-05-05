import '../../data/models/menus_response_model.dart';
import '../repositories/menus_repository.dart';

class CreateMenusUseCase {
  const CreateMenusUseCase(this._repository);
  final MenusRepository _repository;
  Future<MenusResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
