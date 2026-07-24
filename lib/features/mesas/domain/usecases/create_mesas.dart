import '../../data/models/mesas_response_model.dart';
import '../repositories/mesas_repository.dart';

class CreateMesasUseCase {
  const CreateMesasUseCase(this._repository);
  final MesasRepository _repository;
  Future<MesasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
