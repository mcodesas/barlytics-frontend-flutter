import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/network/session_expiration_notifier.dart';
import 'package:barlytics_frontend/features/subscription/data/models/subscription_models.dart';

void main() {
  test('deserializa los avisos y el periodo restante del backend', () {
    final subscription = SubscriptionModel.fromJson({
      'status': 'ACTIVE',
      'active': true,
      'currentPeriodEnd': '2026-10-23T14:00:00',
      'daysUntilExpiry': 2,
      'expiryWarning': true,
      'renewalRequired': false,
      'automaticRenewal': false,
    });
    expect(subscription.active, isTrue);
    expect(subscription.daysUntilExpiry, 2);
    expect(subscription.expiryWarning, isTrue);
    expect(subscription.renewalRequired, isFalse);
  });

  test('HTTP 402 no se interpreta como cierre de sesion', () {
    final notifier = SessionExpirationNotifier();
    var notifications = 0;
    notifier.addListener(() => notifications++);
    notifier.subscriptionExpired();
    expect(notifier.subscriptionRequired, isTrue);
    expect(notifications, 1);
    notifier.sessionExpired();
    expect(notifier.subscriptionRequired, isFalse);
    expect(notifications, 2);
    notifier.dispose();
  });
}
