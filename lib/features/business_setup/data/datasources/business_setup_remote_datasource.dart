import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/business_setup_models.dart';

class BusinessSetupRemoteDataSource {
  BusinessSetupRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<BusinessSetupStatusModel> status() async {
    final response = await _apiClient.get<BusinessSetupStatusModel>(
      ApiPaths.businessSetupStatus,
      (json) => BusinessSetupStatusModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) {
      throw StateError('No fue posible consultar la configuración inicial del negocio.');
    }
    return response.data!;
  }
}
