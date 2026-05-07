import '../../data/models/opciones_menu_response_model.dart';
import '../repositories/opciones_menu_repository.dart';

class GetOpcionesMenuUseCase {
  const GetOpcionesMenuUseCase(this._repository);
  final OpcionesMenuRepository _repository;
  Future<OpcionesMenuResponseModel> call(Object id) => _repository.findById(id);
}
