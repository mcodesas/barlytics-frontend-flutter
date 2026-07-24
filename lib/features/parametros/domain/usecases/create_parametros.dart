import '../../data/models/parametros_response_model.dart';
import '../repositories/parametros_repository.dart';

class CreateParametrosUseCase {
  const CreateParametrosUseCase(this._repository);
  final ParametrosRepository _repository;
  Future<ParametrosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
