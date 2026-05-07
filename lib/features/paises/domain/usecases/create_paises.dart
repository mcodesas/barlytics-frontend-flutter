import '../../data/models/paises_response_model.dart';
import '../repositories/paises_repository.dart';

class CreatePaisesUseCase {
  const CreatePaisesUseCase(this._repository);
  final PaisesRepository _repository;
  Future<PaisesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
