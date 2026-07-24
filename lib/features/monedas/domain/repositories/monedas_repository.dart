import '../../data/models/monedas_response_model.dart';

abstract class MonedasRepository {
  Future<List<MonedasResponseModel>> list();
  Future<MonedasResponseModel> findById(Object id);
  Future<MonedasResponseModel> create(Map<String, dynamic> body);
  Future<MonedasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
