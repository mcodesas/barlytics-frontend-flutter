import '../../data/models/marcas_response_model.dart';
import '../repositories/marcas_repository.dart';

class CreateMarcasUseCase {
  const CreateMarcasUseCase(this._repository);
  final MarcasRepository _repository;
  Future<MarcasResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
