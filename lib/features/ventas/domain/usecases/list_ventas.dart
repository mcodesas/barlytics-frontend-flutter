import '../../data/models/ventas_response_model.dart';
import '../repositories/ventas_repository.dart';

class ListVentasUseCase {
  const ListVentasUseCase(this._repository);
  final VentasRepository _repository;
  Future<List<VentasResponseModel>> call() => _repository.list();
}
