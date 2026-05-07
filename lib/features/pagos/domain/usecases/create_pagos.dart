import '../../data/models/pagos_response_model.dart';
import '../repositories/pagos_repository.dart';

class CreatePagosUseCase {
  const CreatePagosUseCase(this._repository);
  final PagosRepository _repository;
  Future<PagosResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
