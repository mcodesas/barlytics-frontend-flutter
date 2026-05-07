import '../../data/models/parametros_response_model.dart';
import '../repositories/parametros_repository.dart';

class ListParametrosUseCase {
  const ListParametrosUseCase(this._repository);
  final ParametrosRepository _repository;
  Future<List<ParametrosResponseModel>> call() => _repository.list();
}
