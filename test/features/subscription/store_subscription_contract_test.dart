import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/network/api_client.dart';
import 'package:barlytics_frontend/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:barlytics_frontend/features/subscription/presentation/widgets/store_subscription_panel.dart';

void main() {
  test('La compra no entrega empresa, precio, fecha ni estado desde Flutter', () async {
    final seen = <String, Map<String, dynamic>>{};
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final payload = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : <String, dynamic>{};
      seen[options.path] = payload;
      final data = options.path.endsWith('/prepare')
          ? {'appAccountToken': '00000000-0000-0000-0000-000000000001'}
          : {'active': true};
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'code': '200', 'message': 'OK', 'data': data},
      ));
    }));
    final remote = SubscriptionRemoteDataSource(ApiClient(dio));

    final token = await remote.prepareStorePurchase(
        'APPLE', 'com.mcode.barlytics.pro.monthly');
    expect(token, '00000000-0000-0000-0000-000000000001');
    final active = await remote.confirmStorePurchase(
        'APPLE', 'com.mcode.barlytics.pro.monthly', 'transaction-123');
    expect(active, isTrue);
    final prepare = seen['/api/v1/subscriptions/store/prepare']!;
    final confirm = seen['/api/v1/subscriptions/store/confirm']!;
    expect(prepare.keys.toSet(), {'provider', 'productId'});
    expect(confirm.keys.toSet(), {'provider', 'productId', 'purchaseReference'});
    for (final payload in [prepare, confirm]) {
      expect(payload.containsKey('companyId'), isFalse);
      expect(payload.containsKey('expiresAt'), isFalse);
      expect(payload.containsKey('active'), isFalse);
      expect(payload.containsKey('price'), isFalse);
    }
  });

  testWidgets('La página IAP no se muestra en web o escritorio', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(StoreSubscriptionPanel.availablePlatform, isFalse);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: StoreSubscriptionPanel(
        planCode: 'BARLYTICS_PRO_MENSUAL',
        onConfirmed: () async {},
      ),
    )));
    await tester.pump();
    expect(find.text('Suscripción mensual con App Store'), findsNothing);
    expect(find.text('Suscripción mensual con Google Play'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
