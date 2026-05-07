import '../../data/models/zonas_horarias_response_model.dart';

abstract class ZonasHorariasRepository {
  Future<List<ZonasHorariasResponseModel>> list();
  Future<ZonasHorariasResponseModel> findById(Object id);
  Future<ZonasHorariasResponseModel> create(Map<String, dynamic> body);
  Future<ZonasHorariasResponseModel> update(Object id, Map<String, dynamic> body);
  Future<void> delete(Object id);
}
