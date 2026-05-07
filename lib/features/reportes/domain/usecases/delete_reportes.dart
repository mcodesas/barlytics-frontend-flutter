import '../../data/models/reportes_response_model.dart';
import '../repositories/reportes_repository.dart';

class DeleteReportesUseCase {
  const DeleteReportesUseCase(this._repository);
  final ReportesRepository _repository;
  Future<void> call(Object id) => _repository.delete(id);
}
