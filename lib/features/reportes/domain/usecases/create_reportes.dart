import '../../data/models/reportes_response_model.dart';
import '../repositories/reportes_repository.dart';

class CreateReportesUseCase {
  const CreateReportesUseCase(this._repository);
  final ReportesRepository _repository;
  Future<ReportesResponseModel> call(Map<String, dynamic> body) => _repository.create(body);
}
