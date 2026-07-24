import '../../data/models/marcas_response_model.dart';
import '../repositories/marcas_repository.dart';

class GetMarcasUseCase {
  const GetMarcasUseCase(this._repository);
  final MarcasRepository _repository;
  Future<MarcasResponseModel> call(Object id) => _repository.findById(id);
}
