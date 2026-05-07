import '../../data/models/movimientos_response_model.dart';

abstract class MovimientosRepository {
  Future<List<MovimientosResponseModel>> list();
  Future<MovimientosResponseModel> findById(Object id);
  Future<MovimientosResponseModel> create(Map<String, dynamic> body);
  Future<MovimientosResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
