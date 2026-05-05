import '../../data/models/monedas_response_model.dart';
import '../repositories/monedas_repository.dart';

class CreateMonedasUseCase {
  const CreateMonedasUseCase(this._repository);
  final MonedasRepository _repository;
  Future<MonedasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
