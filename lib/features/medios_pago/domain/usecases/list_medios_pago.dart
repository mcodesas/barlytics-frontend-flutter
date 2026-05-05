import '../../data/models/medios_pago_response_model.dart';
import '../repositories/medios_pago_repository.dart';

class ListMediosPagoUseCase {
  const ListMediosPagoUseCase(this._repository);
  final MediosPagoRepository _repository;
  Future<List<MediosPagoResponseModel>> call() => _repository.list();
}
