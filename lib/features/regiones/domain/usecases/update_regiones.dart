import '../../data/models/regiones_response_model.dart';
import '../repositories/regiones_repository.dart';

class UpdateRegionesUseCase {
  const UpdateRegionesUseCase(this._repository);
  final RegionesRepository _repository;
  Future<RegionesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
