import '../../data/models/regiones_response_model.dart';
import '../repositories/regiones_repository.dart';

class GetRegionesUseCase {
  const GetRegionesUseCase(this._repository);
  final RegionesRepository _repository;
  Future<RegionesResponseModel> call(Object id) => _repository.findById(id);
}
