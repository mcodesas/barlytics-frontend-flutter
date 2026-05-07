import '../../data/models/pagos_response_model.dart';
import '../repositories/pagos_repository.dart';

class GetPagosUseCase {
  const GetPagosUseCase(this._repository);
  final PagosRepository _repository;
  Future<PagosResponseModel> call(Object id) => _repository.findById(id);
}
