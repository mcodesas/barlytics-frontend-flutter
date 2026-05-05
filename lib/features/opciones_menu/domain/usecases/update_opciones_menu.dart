import '../../data/models/opciones_menu_response_model.dart';
import '../repositories/opciones_menu_repository.dart';

class UpdateOpcionesMenuUseCase {
  const UpdateOpcionesMenuUseCase(this._repository);
  final OpcionesMenuRepository _repository;
  Future<OpcionesMenuResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
