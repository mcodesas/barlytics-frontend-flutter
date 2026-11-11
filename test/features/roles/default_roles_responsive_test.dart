import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/network/api_client.dart';
import 'package:barlytics_frontend/features/navigation/presentation/providers/active_role_provider.dart';
import 'package:barlytics_frontend/features/roles/data/default_roles_repository.dart';
import 'package:barlytics_frontend/features/roles/presentation/pages/roles_form_page.dart';
import 'package:barlytics_frontend/features/roles/presentation/pages/roles_list_page.dart';

class _FakeRepository extends DefaultRolesRepository {
  _FakeRepository() : super(ApiClient(Dio()));

  @override
  Future<List<Map<String, dynamic>>> roles() async => [
    {
      'roleId': 12,
      'roleNombre': 'CAJERO',
      'roleDescripcion': 'Caja y pagos',
      'roleEstado': 1,
      'menuCount': 2,
      'manuallyConfigured': false,
    },
  ];

  @override
  Future<Map<String, dynamic>> details(int id) async => {
    'role': {
      'roleId': id,
      'roleNombre': 'CAJERO',
      'roleDescripcion': 'Caja y pagos',
      'roleEstado': 1,
      'roleTipo': 'PREDEFINIDO',
    },
    'menus': [
      {
        'menuId': 1,
        'nombre': 'Ventas',
        'descripcion': 'Registrar ventas',
        'parametro': 'ventas',
        'grupo': 'Operación',
        'assigned': true,
        'restricted': false,
      },
      {
        'menuId': 2,
        'nombre': 'Caja',
        'descripcion': 'Control de caja y cierres',
        'parametro': 'cierre_caja',
        'grupo': 'Operación',
        'assigned': true,
        'restricted': false,
      },
      {
        'menuId': 3,
        'nombre': 'Centro de errores',
        'descripcion': 'Monitor global',
        'parametro': 'centro_errores',
        'grupo': 'Administración',
        'assigned': false,
        'restricted': true,
      },
    ],
  };
}

void main() {
  testWidgets('Un rol operativo no puede abrir el panel nativo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeRolesProvider.overrideWithValue(['GERENTE']),
        defaultRolesRepositoryProvider.overrideWithValue(_FakeRepository()),
      ],
      child: const MaterialApp(home: RolesListPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Solo administración del sistema'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 390.0, 768.0, 1200.0]) {
    testWidgets('Panel de roles adaptable a ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeRolesProvider.overrideWithValue(['ADMIN']),
          defaultRolesRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const MaterialApp(home: RolesListPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Administración de roles'), findsOneWidget);
      expect(find.text('CAJERO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Editor de permisos adaptable a ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activeRolesProvider.overrideWithValue(['ADMIN']),
          defaultRolesRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const MaterialApp(home: RolesFormPage(id: '12')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('CAJERO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
