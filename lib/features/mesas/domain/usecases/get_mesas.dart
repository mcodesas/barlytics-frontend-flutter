import '../../data/models/mesas_response_model.dart';
import '../repositories/mesas_repository.dart';

class GetMesasUseCase {
  const GetMesasUseCase(this._repository);
  final MesasRepository _repository;
  Future<MesasResponseModel> call(Object id) => _repository.findById(id);
}
