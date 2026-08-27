import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/subscription_models.dart';

class SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSource(this._api);
  final ApiClient _api;

  Future<SubscriptionModel> current() async {
    final response = await _api.get<SubscriptionModel>(
      ApiPaths.subscriptionMe,
      (json) => SubscriptionModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible consultar la suscripción.');
    return response.data!;
  }

  Future<List<SubscriptionPlanModel>> plans() async {
    final response = await _api.get<List<SubscriptionPlanModel>>(
      ApiPaths.subscriptionPlans,
      (json) => (json as List? ?? const <dynamic>[])
          .map((item) => SubscriptionPlanModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <SubscriptionPlanModel>[];
  }

  Future<List<SubscriptionPlanModel>> publicPlans() async {
    final response = await _api.get<List<SubscriptionPlanModel>>(
      ApiPaths.publicSubscriptionPlans,
      (json) => (json as List? ?? const <dynamic>[])
          .map((item) => SubscriptionPlanModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <SubscriptionPlanModel>[];
  }

  Future<SubscriptionModel> changePlan(String planCode) async {
    final response = await _api.put<SubscriptionModel>(
      ApiPaths.subscriptionPlan,
      <String, dynamic>{'planCode': planCode},
      (json) => SubscriptionModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible cambiar el plan.');
    return response.data!;
  }

  Future<SubscriptionPaymentConfigModel> paymentConfig() async {
    final response = await _api.get<SubscriptionPaymentConfigModel>(
      ApiPaths.subscriptionPaymentConfig,
      (json) => SubscriptionPaymentConfigModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible cargar el formulario de pago.');
    return response.data!;
  }

  Future<SubscriptionCheckoutModel> oneTimeCheckout(int prepaidPeriods) async {
    final response = await _api.post<SubscriptionCheckoutModel>(
      ApiPaths.subscriptionOneTimeCheckout,
      <String, dynamic>{'prepaid_periods': prepaidPeriods},
      (json) => SubscriptionCheckoutModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible iniciar el checkout de Mercado Pago.');
    return response.data!;
  }

  Future<SubscriptionModel> sync({
    String? paymentId,
    String? preapprovalId,
    String? externalReference,
    String? preferenceId,
  }) async {
    final response = await _api.post<SubscriptionModel>(
      ApiPaths.subscriptionSync,
      null,
      (json) => SubscriptionModel.fromJson(Map<String, dynamic>.from(json as Map)),
      queryParameters: <String, dynamic>{
        if (paymentId != null && paymentId.isNotEmpty) 'paymentId': paymentId,
        if (preapprovalId != null && preapprovalId.isNotEmpty) 'preapprovalId': preapprovalId,
        if (externalReference != null && externalReference.isNotEmpty) 'externalReference': externalReference,
        if (preferenceId != null && preferenceId.isNotEmpty) 'preferenceId': preferenceId,
      },
    );
    if (response.data == null) throw StateError('No fue posible verificar el pago.');
    return response.data!;
  }
}
