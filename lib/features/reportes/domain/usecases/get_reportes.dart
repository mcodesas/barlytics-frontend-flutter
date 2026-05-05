import '../../data/models/reportes_response_model.dart';
import '../repositories/reportes_repository.dart';

class GetReportesUseCase {
  const GetReportesUseCase(this._repository);
  final ReportesRepository _repository;
  Future<ReportesResponseModel> call(Object id) => _repository.findById(id);
}
