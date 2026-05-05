import '../../data/models/reportes_response_model.dart';

abstract class ReportesRepository {
  Future<List<ReportesResponseModel>> list();
  Future<ReportesResponseModel> findById(Object id);
  Future<ReportesResponseModel> create(Map<String, dynamic> body);
  Future<ReportesResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
