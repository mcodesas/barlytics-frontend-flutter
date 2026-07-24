import '../../data/models/paises_response_model.dart';
import '../repositories/paises_repository.dart';

class GetPaisesUseCase {
  const GetPaisesUseCase(this._repository);
  final PaisesRepository _repository;
  Future<PaisesResponseModel> call(Object id) => _repository.findById(id);
}
