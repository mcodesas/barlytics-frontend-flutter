import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/subscription/data/models/subscription_models.dart';

void main() {
  test('Reconoce App Store como proveedor de la suscripción', () {
    final subscription = SubscriptionModel.fromJson(<String, dynamic>{
      'status': 'ACTIVE',
      'active': true,
      'provider': 'apple',
      'paymentMethod': 'APPLE_IAP',
      'automaticRenewal': true,
    });

    expect(subscription.provider, 'APPLE');
    expect(subscription.paymentMethod, 'APPLE_IAP');
    expect(subscription.automaticRenewal, isTrue);
  });

  test('Reconoce Google Play como proveedor de la suscripción', () {
    final subscription = SubscriptionModel.fromJson(<String, dynamic>{
      'status': 'ACTIVE',
      'active': true,
      'provider': 'GOOGLE',
      'paymentMethod': 'GOOGLE_IAP',
    });

    expect(subscription.provider, 'GOOGLE');
  });

  test('Conserva compatibilidad con respuestas anteriores sin provider', () {
    final subscription = SubscriptionModel.fromJson(<String, dynamic>{
      'status': 'ACTIVE',
      'active': true,
      'paymentMethod': 'CARD',
    });

    expect(subscription.provider, isNull);
    expect(subscription.active, isTrue);
  });

  test('Reconoce suscripciones de Mercado Pago', () {
    final subscription = SubscriptionModel.fromJson(<String, dynamic>{
      'status': 'ACTIVE',
      'active': true,
      'provider': 'MERCADOPAGO',
    });

    expect(subscription.provider, 'MERCADOPAGO');
  });
}
