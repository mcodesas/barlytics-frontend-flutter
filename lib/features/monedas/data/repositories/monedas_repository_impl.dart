import '../../../../core/crud/crud_repository.dart';
import '../../domain/repositories/monedas_repository.dart';
import '../models/monedas_response_model.dart';

class MonedasRepositoryImpl implements MonedasRepository {
  MonedasRepositoryImpl(this._repository);
  final CrudRepository<MonedasResponseModel> _repository;

  @override
  Future<List<MonedasResponseModel>> list() => _repository.list();
  @override
  Future<MonedasResponseModel> findById(Object id) => _repository.findById(id);
  @override
  Future<MonedasResponseModel> create(Map<String, dynamic> body) => _repository.create(body);
  @override
  Future<MonedasResponseModel> update(Object id, Map<String, dynamic> body) => _repository.update(id, body);
  @override
  Future<void> delete(Object id) => _repository.delete(id);
}
