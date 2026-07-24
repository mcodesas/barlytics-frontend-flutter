import '../../data/models/pagos_response_model.dart';
import '../repositories/pagos_repository.dart';

class ListPagosUseCase {
  const ListPagosUseCase(this._repository);
  final PagosRepository _repository;
  Future<List<PagosResponseModel>> call() => _repository.list();
}
