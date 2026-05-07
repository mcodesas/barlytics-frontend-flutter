import '../../data/models/parametros_response_model.dart';
import '../repositories/parametros_repository.dart';

class GetParametrosUseCase {
  const GetParametrosUseCase(this._repository);
  final ParametrosRepository _repository;
  Future<ParametrosResponseModel> call(Object id) => _repository.findById(id);
}
