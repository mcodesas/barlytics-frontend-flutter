import '../../data/models/medios_pago_response_model.dart';
import '../repositories/medios_pago_repository.dart';

class UpdateMediosPagoUseCase {
  const UpdateMediosPagoUseCase(this._repository);
  final MediosPagoRepository _repository;
  Future<MediosPagoResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
