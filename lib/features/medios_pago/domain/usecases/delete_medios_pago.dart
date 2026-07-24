import '../../data/models/medios_pago_response_model.dart';
import '../repositories/medios_pago_repository.dart';

class DeleteMediosPagoUseCase {
  const DeleteMediosPagoUseCase(this._repository);
  final MediosPagoRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
