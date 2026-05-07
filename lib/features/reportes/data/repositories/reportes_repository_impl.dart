import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/reportes_repository.dart';
import '../models/reportes_response_model.dart';

class ReportesRepositoryImpl implements ReportesRepository {
  ReportesRepositoryImpl(this._repository);
  final CrudRepository<ReportesResponseModel> _repository;

  @override
  Future<List<ReportesResponseModel>> list() => _repository.list();
  @override
  Future<ReportesResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<ReportesResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<ReportesResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
