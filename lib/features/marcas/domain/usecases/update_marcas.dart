import '../../data/models/marcas_response_model.dart';
import '../repositories/marcas_repository.dart';

class UpdateMarcasUseCase {
  const UpdateMarcasUseCase(this._repository);
  final MarcasRepository _repository;
  Future<MarcasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
