import '../../data/models/medios_pago_response_model.dart';
import '../repositories/medios_pago_repository.dart';

class GetMediosPagoUseCase {
  const GetMediosPagoUseCase(this._repository);
  final MediosPagoRepository _repository;
  Future<MediosPagoResponseModel> call(Object id) => _repository.findById(id);
}
