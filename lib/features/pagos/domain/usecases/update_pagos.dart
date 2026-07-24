import '../../data/models/pagos_response_model.dart';
import '../repositories/pagos_repository.dart';

class UpdatePagosUseCase {
  const UpdatePagosUseCase(this._repository);
  final PagosRepository _repository;
  Future<PagosResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
