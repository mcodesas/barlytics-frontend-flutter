import '../../data/models/marcas_response_model.dart';
import '../repositories/marcas_repository.dart';

class ListMarcasUseCase {
  const ListMarcasUseCase(this._repository);
  final MarcasRepository _repository;
  Future<List<MarcasResponseModel>> call() => _repository.list();
}
