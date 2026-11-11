import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barlytics_frontend/core/telemetry/error_telemetry.dart';
import 'package:barlytics_frontend/core/widgets/app_empty_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flutter en debug reporta errores a menos que se desactive expresamente',
      () {
    // El perfil normal flutter run no suministra este dart-define.
    if (!const bool.hasEnvironment('BARLYTICS_TELEMETRY_ENABLED')) {
      expect(kDebugMode, isTrue);
      expect(ErrorTelemetry.enabled, isTrue);
    }
  });

  test('Identifica errores de layout y cascadas secundarias', () {
    expect(
      ErrorTelemetry.frameworkCategory(
        'LayoutBuilder does not support returning intrinsic dimensions.'),
      'layout',
    );
    expect(
      ErrorTelemetry.isRenderingCascade(
        'Unexpected null value.',
        'package:flutter/src/rendering/viewport.dart 694:64 layoutChildSequence',
      ),
      isTrue,
    );
    expect(
      ErrorTelemetry.isRenderingCascade(
        'Unexpected null value.',
        'package:barlytics_frontend/features/ventas.dart 13:1 callback',
      ),
      isFalse,
    );
    expect(
      ErrorTelemetry.isRenderingCascade(
        'Assertion failed: !_debugDuringDeviceUpdate',
        'package:flutter/src/rendering/mouse_tracker.dart 199:12',
      ),
      isTrue,
    );
  });

  test('FlutterError de render se transmite al backend con ruta y categoría',
      () async {
    final telemetry = ErrorTelemetry.instance;
    telemetry.detachForTesting();
    final sent = <Map<String, dynamic>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/api/v1/error-center/report') {
          sent.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(Response<dynamic>(
            requestOptions: options,
            statusCode: 202,
          ));
        }
        handler.reject(DioException(requestOptions: options));
      },
    ));
    addTearDown(() {
      telemetry.detachForTesting();
      dio.close(force: true);
    });

    telemetry.attach(dio);
    telemetry.navigation('/precios');
    telemetry.frameworkError(FlutterErrorDetails(
      exception: FlutterError(
        'LayoutBuilder does not support returning intrinsic dimensions.'),
      stack: StackTrace.fromString(
        'package:flutter/src/rendering/sliver_fill.dart 159:26 performLayout'),
      library: 'rendering library',
      context: ErrorDescription('during performLayout()'),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(sent, hasLength(1));
    expect(sent.single['category'], 'layout');
    expect(sent.single['module'], 'precios');
    expect(sent.single['route'], '/precios');
    expect(sent.single['origin'], 'flutter');
    expect(sent.single['stacktrace'],
        contains('LayoutBuilder does not support returning intrinsic dimensions'));

    // No transmitir el "Unexpected null value" de un viewport dañado como
    // otra incidencia independiente del primer fallo de renderizado.
    telemetry.frameworkError(FlutterErrorDetails(
      exception: StateError('Unexpected null value.'),
      stack: StackTrace.fromString(
        'package:flutter/src/rendering/viewport.dart 694:64 layoutChildSequence'),
      library: 'rendering library',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, hasLength(1));
  });

  testWidgets('Estado vacío de Precios usa sliver con altura acotada',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: 202)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 290,
                    child: AppEmptyView(message: 'No hay productos disponibles'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No hay productos disponibles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
