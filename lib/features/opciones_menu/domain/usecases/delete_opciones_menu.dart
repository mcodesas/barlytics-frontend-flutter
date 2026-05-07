import '../../data/models/opciones_menu_response_model.dart';
import '../repositories/opciones_menu_repository.dart';

class DeleteOpcionesMenuUseCase {
  const DeleteOpcionesMenuUseCase(this._repository);
  final OpcionesMenuRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
