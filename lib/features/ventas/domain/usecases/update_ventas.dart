import '../../data/models/ventas_response_model.dart';
import '../repositories/ventas_repository.dart';

class UpdateVentasUseCase {
  const UpdateVentasUseCase(this._repository);
  final VentasRepository _repository;
  Future<VentasResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
