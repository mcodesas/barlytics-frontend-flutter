import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'device_context.dart';

/// Centraliza incidencias técnicas sin enviar usuarios, JWT ni solicitudes.
///
/// Mantiene como máximo 60 eventos pendientes en memoria. No persiste
/// excepciones en almacenamiento compartido para evitar filtrarlas entre
/// usuarios del mismo dispositivo. Al reconectar, reintenta mientras la
/// sesión vigente permita reportar eventos.
class ErrorTelemetry {
  ErrorTelemetry._();
  static final ErrorTelemetry instance = ErrorTelemetry._();

  // También en flutter run -d chrome: los fallos de layout y render
  // ocurren en depuración y deben llegar al mismo Centro de errores.
  // Puede desactivarse expresamente con --dart-define=BARLYTICS_TELEMETRY_ENABLED=false.
  static const bool enabled = bool.fromEnvironment(
    'BARLYTICS_TELEMETRY_ENABLED',
    defaultValue: true,
  );

  final Queue<Map<String, Object?>> _pending = Queue<Map<String, Object?>>();
  final Queue<String> _breadcrumbs = Queue<String>();
  final Map<String, DateTime> _recent = <String, DateTime>{};
  DateTime? _lastLayoutRootAt;
  String _lastLayoutRootRoute = '';
  Dio? _dio;
  CancelToken? _inFlight;
  int _sessionEpoch = 0;
  Timer? _retryTimer;
  bool _sending = false;
  String _route = '';
  int get pendingCount => _pending.length;
  String get currentRoute => _route;

  void attach(Dio dio) {
    if (!enabled || identical(_dio, dio)) return;
    _dio = dio;
    _retryTimer ??= Timer.periodic(const Duration(minutes: 2), (_) => flush());
    flush();
  }

  /// Permite verificar transporte real en pruebas, sin dejar temporizadores.
  @visibleForTesting
  void detachForTesting() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _inFlight?.cancel('Finalizó la prueba');
    _inFlight = null;
    _dio = null;
    _sending = false;
    clearSession();
  }

  /// Registrar solo el nombre del módulo/ruta, nunca sus parámetros.
  void navigation(String path) {
    final clean = normalizeRoute(path);
    if (clean.isEmpty || _route == clean) return;
    _route = clean;
    _breadcrumb('pantalla ' + clean);
  }

  void action(String category, {String? route}) {
    final name = sanitize(category, 60);
    if (name.isEmpty) return;
    _breadcrumb(name + (route == null ? '' : ' ' + normalizeRoute(route)));
  }

  void _breadcrumb(String text) {
    final now = DateTime.now().toUtc().toIso8601String();
    if (_breadcrumbs.length >= 12) _breadcrumbs.removeFirst();
    _breadcrumbs.addLast(now + ' ' + text);
  }

  /// Clasificación de fallos del motor de renderizado. Capturar también
  /// LayoutBuilder / SliverFillRemaining y no solo RenderFlex overflowed.
  static String frameworkCategory(String message) {
    const layoutPatterns = <String>[
      'LayoutBuilder does not support returning intrinsic dimensions',
      'RenderFlex', 'overflowed', 'RenderBox was not laid out',
      'RenderViewport', 'NEEDS-LAYOUT', 'BoxConstraints forces an infinite',
    ];
    return layoutPatterns.any(message.contains) ? 'layout' : 'flutter_framework';
  }

  /// Errores secundarios producidos por un RenderViewport ya inconsistente.
  /// No ocultar fallos diferentes: exige misma pantalla y raíz reciente.
  static bool isRenderingCascade(String message, String stack) {
    final downstream =
        message.contains('Unexpected null value') ||
        message.contains('!_debugDuringDeviceUpdate');
    final enginePath =
        stack.contains('rendering/viewport.dart') ||
        stack.contains('rendering/mouse_tracker.dart');
    return downstream && enginePath;
  }

  void frameworkError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final category = frameworkCategory(message);
    final route = normalizeRoute(_route);
    final now = DateTime.now();
    // Flutter puede emitir centenares de errores de gestos/pintado a causa
    // del primer error de layout. Reportar la causa raíz, no su cascada.
    if (_lastLayoutRootAt != null &&
        now.difference(_lastLayoutRootAt!) < const Duration(seconds: 90) &&
        route == _lastLayoutRootRoute &&
        isRenderingCascade(message, details.stack?.toString() ?? '')) {
      return;
    }
    if (category == 'layout') {
      _lastLayoutRootAt = now;
      _lastLayoutRootRoute = route;
    }
    final module = route == '/' ? (details.library ?? 'flutter') :
        route.split('/').where((part) => part.isNotEmpty).first;
    capture(
      category: category,
      errorType: details.exception.runtimeType.toString(),
      message: message,
      // FlutterErrorDetails incluye widget causante, archivo, línea y traza;
      // el saneamiento y límite de tamaño se aplican en capture().
      stacktrace: '$message\n${details.toString()}',
      module: module,
    );
  }

  void uncaughtError(Object error, StackTrace stack,
      {String module = 'uncaught'}) {
    capture(
      category: 'uncaught',
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      stacktrace: stack.toString(),
      module: module,
    );
  }

  void networkError(DioException error) {
    final options = error.requestOptions;
    if (options.extra['skipTelemetry'] == true ||
        options.uri.path.startsWith('/api/v1/error-center/')) return;
    final status = error.response?.statusCode;
    // Cancelar una solicitud al cambiar de pantalla no es un fallo.
    if (error.type == DioExceptionType.cancel) return;
    // Validaciones, autenticaciones y errores funcionales 4xx no son bugs.
    if (status != null && status < 500) return;
    final started = options.extra['telemetryStartMs'];
    final duration = started is int
        ? DateTime.now().millisecondsSinceEpoch - started : null;
    capture(
      category: status == null ? 'network' : 'http_5xx',
      errorType: 'DioException',
      message: status == null
          ? 'Fallo de red tipo ' + error.type.name
          : 'HTTP ' + status.toString(),
      module: 'api',
      route: options.uri.path,
      httpStatus: status,
      httpMethod: options.method,
      durationMs: duration,
      correlationId: options.headers['X-Request-Id']?.toString(),
    );
  }

  void capture({
    required String category,
    required String errorType,
    required String message,
    String? stacktrace,
    String module = '',
    String? route,
    String? httpMethod,
    int? httpStatus,
    int? durationMs,
    String? correlationId,
  }) {
    if (!enabled) return;
    final contextRoute = normalizeRoute(route ?? _route);
    final normalizedCategory = sanitize(category, 50);
    final safeMessage = sanitize(message, 500);
    final signature = normalizedCategory + '|' + errorType + '|' +
        contextRoute + '|' + safeMessage;
    final now = DateTime.now();
    final last = _recent[signature];
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _recent[signature] = now;
    if (_recent.length > 200) {
      _recent.removeWhere((_, timestamp) =>
          now.difference(timestamp) > const Duration(minutes: 3));
    }

    // No se captura la pantalla: solo las dimensiones lógicas para detectar
    // diálogos truncados, overflow y problemas de accesibilidad.
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isEmpty ? null : views.first;
    final ratio = view?.devicePixelRatio ?? 1;
    final width = view == null ? null : (view.physicalSize.width / ratio).round();
    final height = view == null ? null : (view.physicalSize.height / ratio).round();
    final recentActions = _breadcrumbs.toList(growable: false);
    final payload = <String, Object?>{
      'origin': 'flutter',
      'category': normalizedCategory,
      'errorType': sanitize(errorType, 120),
      'message': safeMessage,
      'stacktrace': sanitize(stacktrace ?? '', 6000),
      'module': sanitize(module, 120),
      'route': contextRoute,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appVersion': const String.fromEnvironment(
          'BARLYTICS_APP_VERSION', defaultValue: '1.0.0'),
      'appBuild': const String.fromEnvironment(
          'BARLYTICS_APP_BUILD', defaultValue: '1'),
      'deviceContext': sanitize(errorDeviceContext(), 120),
      'lastAction': recentActions.isEmpty ? '' :
          sanitize(recentActions.last, 120),
      'breadcrumbs': sanitize(recentActions.join('\n'), 1600),
      if (width != null && width >= 1 && width <= 20000) 'screenWidth': width,
      if (height != null && height >= 1 && height <= 20000) 'screenHeight': height,
      if (httpStatus != null && httpStatus >= 100 && httpStatus <= 599)
        'httpStatus': httpStatus,
      if (httpMethod != null) 'httpMethod': sanitize(httpMethod, 10),
      if (durationMs != null && durationMs >= 0 && durationMs <= 600000)
        'durationMs': durationMs,
      if (correlationId != null)
        'correlationId': sanitize(correlationId, 64),
    };
    if (_pending.length >= 60) _pending.removeFirst();
    _pending.addLast(payload);
    flush();
  }

  /// Evita que el error de una sesión aparezca asignado a otro usuario.
  void clearSession() {
    _sessionEpoch++;
    _inFlight?.cancel('Cambio de sesión');
    _inFlight = null;
    _pending.clear();
    _recent.clear();
    _breadcrumbs.clear();
    _route = '';
    _lastLayoutRootAt = null;
    _lastLayoutRootRoute = '';
  }

  /// Prueba de punta a punta iniciada por el administrador global.
  /// Funciona incluso con Flutter en debug y no provoca una excepción real.
  Future<bool> sendDiagnostic() async {
    final dio = _dio;
    if (dio == null) return false;
    try {
      await dio.post<void>(
        '/api/v1/error-center/report',
        data: {
          'origin': 'flutter',
          'category': 'diagnostic',
          'errorType': 'TelemetrySelfTest',
          'message': 'Prueba controlada de monitoreo ejecutada desde el panel',
          'stacktrace': 'Sin excepción: verificación manual del transporte.',
          'module': 'centro_errores',
          'route': '/centro_errores',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'appVersion': const String.fromEnvironment(
              'BARLYTICS_APP_VERSION', defaultValue: '1.0.0'),
          'appBuild': const String.fromEnvironment(
              'BARLYTICS_APP_BUILD', defaultValue: '1'),
          'deviceContext': sanitize(errorDeviceContext(), 120),
          'lastAction': 'prueba_manual',
          'breadcrumbs': 'Prueba solicitada por administrador global',
        },
        options: Options(extra: const {'skipTelemetry': true},
          sendTimeout: const Duration(seconds: 8)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void flush() {
    if (!enabled || _sending || _dio == null || _pending.isEmpty) return;
    _sending = true;
    unawaited(_sendQueued());
  }

  Future<void> _sendQueued() async {
    final epoch = _sessionEpoch;
    try {
      while (_pending.isNotEmpty && _dio != null && epoch == _sessionEpoch) {
        final event = _pending.first;
        final cancel = CancelToken();
        _inFlight = cancel;
        try {
          await _dio!.post<void>(
            '/api/v1/error-center/report',
            data: event,
            cancelToken: cancel,
            options: Options(
              extra: const {'skipTelemetry': true},
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          if (kDebugMode) {
            debugPrint('[Centro de errores] Reporte recibido (HTTP 202).');
          }
          if (_pending.isNotEmpty && identical(_pending.first, event)) {
            _pending.removeFirst();
          }
        } on DioException catch (error) {
          if (epoch != _sessionEpoch) break;
          final status = error.response?.statusCode;
          if (kDebugMode) {
            debugPrint('[Centro de errores] Envío no confirmado '
                '(HTTP ${status ?? 'sin respuesta'}). '
                'Pendientes: ${_pending.length}.');
          }
          if (status == 400 || status == 413 || status == 422) {
            if (_pending.isNotEmpty && identical(_pending.first, event)) {
              _pending.removeFirst();
            }
            continue;
          }
          // 401, 403, 429 y pérdida de red reintentan cuando corresponda.
          break;
        } catch (_) {
          break;
        } finally {
          if (identical(_inFlight, cancel)) _inFlight = null;
        }
      }
    } finally {
      _sending = false;
      // Una sesión nueva pudo crear eventos mientras se cancelaba el envío.
      if (_pending.isNotEmpty && epoch != _sessionEpoch) flush();
    }
  }

  /// Solo la navegación de módulo, sin slugs de eventos ni IDs de usuarios.
  static String normalizeRoute(String value) {
    final path = value.split('?').first.split('#').first;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '/';
    if (parts.length >= 3 &&
        parts[0].toLowerCase() == 'api' &&
        parts[1].toLowerCase() == 'v1') {
      // Conservar el endpoint sin introducir identificadores de clientes.
      final module = parts[2].toLowerCase();
      if (!RegExp(r'^[a-z][a-z_-]{1,49}$').hasMatch(module)) {
        return '/api/v1/:modulo';
      }
      const actions = <String>{
        'administracion', 'excel', 'inventario', 'productos', 'historial',
        'conteos', 'movimientos', 'ventas', 'pedidos', 'pagos', 'cierres',
        'resumen', 'reportes', 'usuarios', 'sucursales', 'configuracion',
        'public', 'login', 'auth', 'me', 'menus', 'datos', 'exportar',
        'compras', 'consultar', 'importar', 'publicar', 'recibir',
        'precios', 'saldos', 'descargas', 'catalogo', 'detalle', 'estado',
        'facturas', 'caja', 'medios', 'proveedores', 'reservas',
        'eventos', 'actualizar',
      };
      final segments = <String>['api', 'v1', module];
      for (final segment in parts.skip(3).take(3)) {
        final item = segment.toLowerCase();
        segments.add(actions.contains(item) ? item : ':id');
      }
      return '/' + segments.join('/');
    }

    final first = parts.first.toLowerCase();
    if (!RegExp(r'^[a-z_]{2,45}$').hasMatch(first)) return '/modulo';
    const known = <String>{
      'historial', 'productos', 'inventario', 'admin', 'conteos',
      'editar', 'crear', 'ventas', 'pedidos', 'detalle', 'reportes',
    };
    final extra = parts.length >= 2 &&
            known.contains(parts[1].toLowerCase())
        ? '/' + parts[1].toLowerCase()
        : '';
    return '/' + first + extra;
  }

  /// Se ejecuta antes de enviar. No captura bodies ni cabeceras.
  static String sanitize(String value, int limit) {
    if (limit <= 0) return '';
    var clean = value
        .replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), '[TOKEN]')
        .replaceAll(RegExp(
            r'(password|passwd|token|secret|authorization|api[_-]?key)\s*[:=]\s*\S+',
            caseSensitive: false), '[SECRET]')
        .replaceAll(RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}',
            caseSensitive: false), '[EMAIL]')
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[URL]')
        .replaceAll(RegExp(r'[A-Z]:\\Users\\[^\s]+',
            caseSensitive: false), '[RUTA_USUARIO]')
        .replaceAll(RegExp(r'/(?:home|Users)/[^/\s]+',
            caseSensitive: false), '/[USUARIO]')
        .replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[NUMERO]')
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '[IP]')
        // Conservar saltos de línea para que la traza sea investigable.
        .replaceAll(RegExp(r'[\x00-\x09\x0b-\x1f]'), ' ');
    if (clean.length > limit) clean = clean.substring(0, limit);
    return clean;
  }
}

/// Registra de manera transversal 5xx, errores de conexión y latencias
/// sin interferir en la respuesta normal del módulo.
class ErrorTelemetryInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipTelemetry'] != true) {
      options.extra['telemetryStartMs'] =
          DateTime.now().millisecondsSinceEpoch;
      ErrorTelemetry.instance.action(options.method,
          route: options.uri.path);
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ErrorTelemetry.instance.networkError(err);
    handler.next(err);
  }

  @override
  void onResponse(Response<dynamic> response,
      ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra['skipTelemetry'] != true) {
      if ((response.statusCode ?? 0) >= 500) {
        ErrorTelemetry.instance.capture(
          category: 'http_5xx',
          errorType: 'HTTP ' + response.statusCode.toString(),
          message: 'Respuesta 5xx',
          module: 'api',
          route: response.requestOptions.uri.path,
          httpMethod: response.requestOptions.method,
          httpStatus: response.statusCode,
        );
      }
      ErrorTelemetry.instance.flush();
    }
    handler.next(response);
  }
}

