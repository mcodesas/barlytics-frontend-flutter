import '../../data/models/monedas_response_model.dart';
import '../repositories/monedas_repository.dart';

class GetMonedasUseCase {
  const GetMonedasUseCase(this._repository);
  final MonedasRepository _repository;
  Future<MonedasResponseModel> call(Object id) => _repository.findById(id);
}
