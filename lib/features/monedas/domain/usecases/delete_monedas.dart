import '../../data/models/monedas_response_model.dart';
import '../repositories/monedas_repository.dart';

class DeleteMonedasUseCase {
  const DeleteMonedasUseCase(this._repository);
  final MonedasRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
