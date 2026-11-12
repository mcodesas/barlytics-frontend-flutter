import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:barlytics_frontend/features/menu_digital/data/menu_digital_api.dart';
import 'package:barlytics_frontend/features/menu_digital/presentation/menu_digital_public_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(GoRouter router, Dio dio) => ProviderScope(
    overrides: [
      menuDigitalApiProvider.overrideWithValue(MenuDigitalApi(dio, () => null)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );

  Dio fakeMenuApi() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'titulo': 'Nuestra carta',
          'sucursal': 'Bar de prueba',
          'estilo': 'TIENDA',
          'productos': <Map<String, dynamic>>[],
        },
      ));
    }));
    return dio;
  }

  GoRouter router({String initial = '/menu_digital'}) => GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/menu_digital',
        builder: (context, state) => Scaffold(
          body: Column(children: [
            const Text('Administrar menú digital'),
            TextButton(
              onPressed: () => context.push('/carta/sucursal-demo?vista_previa=1'),
              child: const Text('Ver como cliente'),
            ),
          ]),
        ),
      ),
      GoRoute(
        path: '/carta/:slug',
        builder: (context, state) => MenuDigitalPublicPage(
          slug: state.pathParameters['slug']!,
          internalPreview: state.uri.queryParameters['vista_previa'] == '1',
        ),
      ),
    ],
  );

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('Vista interna a ${width.toInt()} px permite volver al administrador',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = fakeMenuApi();
      final appRouter = router();
      addTearDown(() { appRouter.dispose(); dio.close(force: true); });
      await tester.pumpWidget(buildApp(appRouter, dio));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver como cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Volver a BarLytics'), findsOneWidget);
      expect(find.text('Nuestra carta'), findsWidgets);
      await tester.tap(find.text('Volver a BarLytics'));
      await tester.pumpAndSettle();
      expect(find.text('Administrar menú digital'), findsOneWidget);
      expect(find.text('Volver a BarLytics'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Un enlace público compartido no muestra regreso administrativo',
      (tester) async {
    final dio = fakeMenuApi();
    final appRouter = router(initial: '/carta/sucursal-demo');
    addTearDown(() { appRouter.dispose(); dio.close(force: true); });
    await tester.pumpWidget(buildApp(appRouter, dio));
    await tester.pumpAndSettle();
    expect(find.text('Nuestra carta'), findsWidgets);
    expect(find.text('Volver a BarLytics'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vista interna directa sin historial tiene regreso seguro',
      (tester) async {
    final dio = fakeMenuApi();
    final appRouter = router(initial: '/carta/sucursal-demo?vista_previa=1');
    addTearDown(() { appRouter.dispose(); dio.close(force: true); });
    await tester.pumpWidget(buildApp(appRouter, dio));
    await tester.pumpAndSettle();
    expect(find.text('Volver a BarLytics'), findsOneWidget);
    await tester.tap(find.text('Volver a BarLytics'));
    await tester.pumpAndSettle();
    expect(find.text('Administrar menú digital'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
