import '../../data/models/mesas_response_model.dart';
import '../repositories/mesas_repository.dart';

class UpdateMesasUseCase {
  const UpdateMesasUseCase(this._repository);
  final MesasRepository _repository;
  Future<MesasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
