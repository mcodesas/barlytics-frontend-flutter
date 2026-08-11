import '../../../auth/data/models/login_response_model.dart';

class PublicCatalogItemModel {
  const PublicCatalogItemModel({required this.id, required this.name, this.code, this.description});
  final int id;
  final String name;
  final String? code;
  final String? description;

  factory PublicCatalogItemModel.fromJson(Map<String, dynamic> json) => PublicCatalogItemModel(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString(),
        description: json['description']?.toString(),
      );
}

class PublicOnboardingCatalogsModel {
  const PublicOnboardingCatalogsModel({this.identificationTypes = const [], this.cities = const []});
  final List<PublicCatalogItemModel> identificationTypes;
  final List<PublicCatalogItemModel> cities;

  factory PublicOnboardingCatalogsModel.fromJson(Map<String, dynamic> json) => PublicOnboardingCatalogsModel(
        identificationTypes: (json['identificationTypes'] as List? ?? const [])
            .map((e) => PublicCatalogItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        cities: (json['cities'] as List? ?? const [])
            .map((e) => PublicCatalogItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class PublicRegistrationModel {
  const PublicRegistrationModel({required this.session, required this.subscriptionStatus, required this.subscriptionActive});
  final LoginResponseModel session;
  final String subscriptionStatus;
  final bool subscriptionActive;

  factory PublicRegistrationModel.fromJson(Map<String, dynamic> json) {
    final sessionJson = Map<String, dynamic>.from(json['session'] as Map? ?? const <String, dynamic>{});
    final subscriptionJson = Map<String, dynamic>.from(json['subscription'] as Map? ?? const <String, dynamic>{});
    return PublicRegistrationModel(
      session: LoginResponseModel.fromJson(sessionJson),
      subscriptionStatus: subscriptionJson['status']?.toString() ?? 'PENDING_PAYMENT',
      subscriptionActive: subscriptionJson['active'] == true,
    );
  }
}
