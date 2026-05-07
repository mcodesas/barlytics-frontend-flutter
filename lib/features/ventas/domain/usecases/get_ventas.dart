import '../../data/models/ventas_response_model.dart';
import '../repositories/ventas_repository.dart';

class GetVentasUseCase {
  const GetVentasUseCase(this._repository);
  final VentasRepository _repository;
  Future<VentasResponseModel> call(Object id) => _repository.findById(id);
}
