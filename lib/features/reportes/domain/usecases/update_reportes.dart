import '../../data/models/reportes_response_model.dart';
import '../repositories/reportes_repository.dart';

class UpdateReportesUseCase {
  const UpdateReportesUseCase(this._repository);
  final ReportesRepository _repository;
  Future<ReportesResponseModel> call(Object id, Map<String, dynamic> body) => _repository.update(id, body);
}
