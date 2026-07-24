import '../../data/models/regiones_response_model.dart';
import '../repositories/regiones_repository.dart';

class ListRegionesUseCase {
  const ListRegionesUseCase(this._repository);
  final RegionesRepository _repository;
  Future<List<RegionesResponseModel>> call() => _repository.list();
}
