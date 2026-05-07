import '../../data/models/pagos_response_model.dart';

abstract class PagosRepository {
  Future<List<PagosResponseModel>> list();
  Future<PagosResponseModel> findById(Object id);
  Future<PagosResponseModel> create(Map<String, dynamic> body);
  Future<PagosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
