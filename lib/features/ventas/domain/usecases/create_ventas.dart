import '../../data/models/ventas_response_model.dart';
import '../repositories/ventas_repository.dart';

class CreateVentasUseCase {
  const CreateVentasUseCase(this._repository);
  final VentasRepository _repository;
  Future<VentasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
