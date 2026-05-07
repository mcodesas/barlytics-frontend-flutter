import '../../data/models/reportes_response_model.dart';
import '../repositories/reportes_repository.dart';

class ListReportesUseCase {
  const ListReportesUseCase(this._repository);
  final ReportesRepository _repository;
  Future<List<ReportesResponseModel>> call() => _repository.list();
}
