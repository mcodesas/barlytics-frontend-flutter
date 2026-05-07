import '../../data/models/precios_response_model.dart';
import '../repositories/precios_repository.dart';

class UpdatePreciosUseCase {
  const UpdatePreciosUseCase(this._repository);
  final PreciosRepository _repository;
  Future<PreciosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
