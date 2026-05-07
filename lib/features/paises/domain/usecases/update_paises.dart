import '../../data/models/paises_response_model.dart';
import '../repositories/paises_repository.dart';

class UpdatePaisesUseCase {
  const UpdatePaisesUseCase(this._repository);
  final PaisesRepository _repository;
  Future<PaisesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
