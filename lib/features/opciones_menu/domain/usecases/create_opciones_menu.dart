import '../../data/models/opciones_menu_response_model.dart';
import '../repositories/opciones_menu_repository.dart';

class CreateOpcionesMenuUseCase {
  const CreateOpcionesMenuUseCase(this._repository);
  final OpcionesMenuRepository _repository;
  Future<OpcionesMenuResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
