import '../../data/models/precios_response_model.dart';
import '../repositories/precios_repository.dart';

class GetPreciosUseCase {
  const GetPreciosUseCase(this._repository);
  final PreciosRepository _repository;
  Future<PreciosResponseModel> call(Object id) => _repository.findById(id);
}
