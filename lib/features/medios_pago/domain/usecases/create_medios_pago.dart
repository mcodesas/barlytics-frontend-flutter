import '../../data/models/medios_pago_response_model.dart';
import '../repositories/medios_pago_repository.dart';

class CreateMediosPagoUseCase {
  const CreateMediosPagoUseCase(this._repository);
  final MediosPagoRepository _repository;
  Future<MediosPagoResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
