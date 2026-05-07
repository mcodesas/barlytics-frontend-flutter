import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/medios_pago_repository.dart';
import '../models/medios_pago_response_model.dart';

class MediosPagoRepositoryImpl implements MediosPagoRepository {
  MediosPagoRepositoryImpl(this._repository);
  final CrudRepository<MediosPagoResponseModel> _repository;

  @override
  Future<List<MediosPagoResponseModel>> list() => _repository.list();
  @override
  Future<MediosPagoResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MediosPagoResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MediosPagoResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
