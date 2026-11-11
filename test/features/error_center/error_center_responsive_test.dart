import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/network/api_client.dart';
import 'package:barlytics_frontend/features/error_center/data/error_center_repository.dart';
import 'package:barlytics_frontend/features/error_center/presentation/pages/error_center_page.dart';

class _FakeErrorCenterRepository extends ErrorCenterRepository {
  _FakeErrorCenterRepository() : super(ApiClient(Dio()));

  @override
  Future<Map<String, dynamic>> metrics() async => {
    'total': 1,
    'open': 1,
    'critical': 0,
    'recentOccurrences': 7,
    'affectedCompanies': 1,
    'platforms': <Map<String, Object?>>[
      {'platform': 'android', 'occurrences': 7},
    ],
    'categories': <Map<String, Object?>>[
      {'category': 'layout', 'occurrences': 7},
    ],
  };

  @override
  Future<Map<String, dynamic>> issues({
    String status = '',
    String severity = '',
    String platform = '',
    String origin = '',
    String category = '',
    String search = '',
    int? companyId,
    int page = 0,
    int size = 25,
  }) async => {
    'items': <Map<String, Object?>>[
      {
        'id': 12,
        'title': 'RenderFlex overflowed by 25 pixels',
        'status': 'OPEN',
        'severity': 'WARNING',
        'platform': 'android',
        'module': 'inventario',
        'route': '/inventario',
        'empresaId': 8,
        'occurrences': 7,
        'suggestedCause': 'Desbordamiento de widgets en móvil',
        'lastSeen': '2026-11-06T18:45:00',
      },
    ],
    'total': 1,
  };
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0]) {
    testWidgets('Centro de errores adaptable a ' +
        width.toInt().toString() + ' px', (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          errorCenterRepositoryProvider.overrideWithValue(
            _FakeErrorCenterRepository(),
          ),
        ],
        child: const MaterialApp(home: ErrorCenterPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Centro de errores'), findsOneWidget);
      // En móviles la sección está por debajo de las cinco tarjetas.
      // En un CustomScrollView los slivers fuera de pantalla aún no
      // se construyen: desplazar realmente hasta los filtros.
      await tester.scrollUntilVisible(
        find.text('Filtros y búsqueda'),
        130,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Filtros y búsqueda'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
