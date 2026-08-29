import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/onboarding_models.dart';

class OnboardingRemoteDataSource {
  OnboardingRemoteDataSource(this._api);
  final ApiClient _api;

  Future<PublicOnboardingCatalogsModel> catalogs() async {
    final response = await _api.get<PublicOnboardingCatalogsModel>(
      ApiPaths.onboardingCatalogs,
      (json) => PublicOnboardingCatalogsModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data ?? const PublicOnboardingCatalogsModel();
  }

  Future<PublicRegistrationModel> register(Map<String, dynamic> payload) async {
    final response = await _api.post<PublicRegistrationModel>(
      ApiPaths.onboardingRegister,
      payload,
      (json) => PublicRegistrationModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('El backend no devolvió la sesión creada.');
    return response.data!;
  }

  Future<PublicRegistrationModel> registerGoogle(Map<String, dynamic> payload) async {
    final response = await _api.post<PublicRegistrationModel>(
      ApiPaths.onboardingRegisterGoogle,
      payload,
      (json) => PublicRegistrationModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('El backend no devolvió la sesión creada.');
    return response.data!;
  }
}
