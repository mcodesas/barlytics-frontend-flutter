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

  Future<SubscriptionModel> changePlan(String planCode) async {
    final response = await _api.put<SubscriptionModel>(
      ApiPaths.subscriptionPlan,
      <String, dynamic>{'planCode': planCode},
      (json) => SubscriptionModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('No fue posible cambiar el plan.');
    return response.data!;
  }

  Future<SubscriptionCheckoutModel> checkout(String paymentMethod) async {
    final response = await _api.post<SubscriptionCheckoutModel>(
      ApiPaths.subscriptionCheckout,
      <String, dynamic>{'paymentMethod': paymentMethod},
      (json) => SubscriptionCheckoutModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.data == null) throw StateError('Mercado Pago no devolvió una URL de pago.');
    return response.data!;
  }

  Future<SubscriptionModel> sync({String? paymentId, String? preapprovalId}) async {
    final response = await _api.post<SubscriptionModel>(
      ApiPaths.subscriptionSync,
      null,
      (json) => SubscriptionModel.fromJson(Map<String, dynamic>.from(json as Map)),
      queryParameters: <String, dynamic>{
        if (paymentId != null && paymentId.isNotEmpty) 'paymentId': paymentId,
        if (preapprovalId != null && preapprovalId.isNotEmpty) 'preapprovalId': preapprovalId,
      },
    );
    if (response.data == null) throw StateError('No fue posible verificar el pago.');
    return response.data!;
  }
}
