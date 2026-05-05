import '../../data/models/parametros_response_model.dart';
import '../repositories/parametros_repository.dart';

class UpdateParametrosUseCase {
  const UpdateParametrosUseCase(this._repository);
  final ParametrosRepository _repository;
  Future<ParametrosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
