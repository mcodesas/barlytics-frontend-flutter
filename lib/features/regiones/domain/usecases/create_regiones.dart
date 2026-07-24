import '../../data/models/regiones_response_model.dart';
import '../repositories/regiones_repository.dart';

class CreateRegionesUseCase {
  const CreateRegionesUseCase(this._repository);
  final RegionesRepository _repository;
  Future<RegionesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
