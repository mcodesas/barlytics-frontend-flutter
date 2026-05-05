import '../../data/models/monedas_response_model.dart';
import '../repositories/monedas_repository.dart';

class ListMonedasUseCase {
  const ListMonedasUseCase(this._repository);
  final MonedasRepository _repository;
  Future<List<MonedasResponseModel>> call() => _repository.list();
}
