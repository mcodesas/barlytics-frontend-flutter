import '../../data/models/precios_response_model.dart';
import '../repositories/precios_repository.dart';

class CreatePreciosUseCase {
  const CreatePreciosUseCase(this._repository);
  final PreciosRepository _repository;
  Future<PreciosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
