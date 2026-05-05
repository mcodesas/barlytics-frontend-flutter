import '../../data/models/opciones_menu_response_model.dart';
import '../repositories/opciones_menu_repository.dart';

class ListOpcionesMenuUseCase {
  const ListOpcionesMenuUseCase(this._repository);
  final OpcionesMenuRepository _repository;
  Future<List<OpcionesMenuResponseModel>> call() => _repository.list();
}
