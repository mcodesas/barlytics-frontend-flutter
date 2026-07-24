import '../../data/models/monedas_response_model.dart';
import '../repositories/monedas_repository.dart';

class UpdateMonedasUseCase {
  const UpdateMonedasUseCase(this._repository);
  final MonedasRepository _repository;
  Future<MonedasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
