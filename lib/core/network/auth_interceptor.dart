import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../telemetry/error_telemetry.dart';

import '../constants/api_paths.dart';
import '../constants/storage_keys.dart';
import '../storage/secure_storage_service.dart';
import 'session_expiration_notifier.dart';

/// Interceptor que agrega JWT y fuerza el cierre local de sesión cuando una
/// petición autenticada deja de ser confiable.
///
/// Solo un 401 invalida la sesión local. Un 403 significa que la sesión sigue
/// siendo válida pero la operación no está autorizada, y una caída de red tampoco
/// debe borrar las credenciales del usuario. Las peticiones
/// públicas, como el login, no disparan este comportamiento porque no llevan
/// cabecera Authorization.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._sessionExpirationNotifier, this._dio);

  final SecureStorageService _storage;
  final SessionExpirationNotifier _sessionExpirationNotifier;
  final Dio _dio;
  Future<bool>? _refreshInFlight;

  bool get _native => !kIsWeb && <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    _ => 'web',
  };

  bool _invalidatingSession = false;

  static const Set<String> _publicPaths = <String>{
    ApiPaths.authLogin,
    '/api/v1/auth/refresh',
    '/api/v1/auth/device/revoke',
    ApiPaths.authGoogleConfig,
    ApiPaths.authGoogleIdentity,
    ApiPaths.authGoogleLogin,
    ApiPaths.authAppleLogin,
    ApiPaths.authForgotPassword,
    ApiPaths.authPasswordRecoveryValidate,
    ApiPaths.authResetPassword,
    ApiPaths.onboardingCatalogs,
    ApiPaths.onboardingRegister,
    ApiPaths.onboardingRegisterGoogle,
    ApiPaths.publicSubscriptionPlans,
    ApiPaths.publicSiteConfig,
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Nunca enviamos un JWT antiguo a endpoints públicos. En particular, esto
    // evita que /auth/google/config falle con 401 al volver al login después
    // de que una sesión haya expirado y desaparezca el botón de Google.
    final isPublicRequest = _publicPaths.contains(options.path) || options.path.startsWith('/api/v1/eventos/public/');
    // Web también recibe una sesión renovable para persistir al cerrar el navegador.
    options.headers['X-BarLytics-Platform'] = kIsWeb ? 'web' : _platform;
    final explicitAuthorization =
        options.headers['Authorization']?.toString().trim();

    if (isPublicRequest) {
      options.headers.remove('Authorization');
    } else if (explicitAuthorization == null || explicitAuthorization.isEmpty) {
      final token = await _storage.read(StorageKeys.authToken);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
    }
    // El backend no puede deducir el cambio de sucursal desde el JWT:
    // el token conserva la sede inicial. Enviar la sede activa por petición.
    if (!isPublicRequest) {
      final selectedBranch = await _storage.read(StorageKeys.sucursalId);
      final id = int.tryParse(selectedBranch ?? '');
      if (id != null && id > 0) {
        options.headers['X-Sucursal-Id'] = id.toString();
      } else {
        options.headers.remove('X-Sucursal-Id');
      }
    }
    options.headers['Accept'] = 'application/json';
    if (options.extra['skipTelemetry'] == true &&
        options.path == '/api/v1/error-center/report' &&
        options.headers['Authorization'] == null) {
      // Si no se ha iniciado sesión, conservar la cola en memoria y no
      // generar una cadena de HTTP 401 mientras la página es pública.
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'Telemetría pendiente de autenticación',
      ));
      return;
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final hadAuthenticatedRequest =
        err.requestOptions.headers['Authorization']?.toString().trim().isNotEmpty == true;
    final statusCode = err.response?.statusCode;

    // Un 402 significa suscripción vencida, no sesión caducada. Se conserva el
    // JWT y el router dirige al usuario a renovar, incluso con la sesión abierta.
    if (hadAuthenticatedRequest && statusCode == 402 &&
        err.requestOptions.path.startsWith('/api/v1/') &&
        !err.requestOptions.path.startsWith('/api/v1/subscriptions/')) {
      _sessionExpirationNotifier.subscriptionExpired();
    }

    // 401 = token ausente/expirado/inválido.
    // 403 = sesión válida sin permiso: se conserva la sesión y la pantalla puede
    // mostrar el error funcional sin expulsar al usuario.
    // Los reportes de monitoreo son auxiliares: un 401 específico de esta
    // ruta no puede expulsar al usuario ni interrumpir una venta en curso.
    final telemetryRequest =
        err.requestOptions.extra['skipTelemetry'] == true;
    final mustInvalidateSession =
        !telemetryRequest && hadAuthenticatedRequest && statusCode == 401;

    if (mustInvalidateSession && err.requestOptions.extra['sessionRetried'] != true) {
      final pendingRefresh = _refreshInFlight ??= _refreshDeviceSession();
      bool refreshed;
      try {
        refreshed = await pendingRefresh;
      } finally {
        if (identical(_refreshInFlight, pendingRefresh)) _refreshInFlight = null;
      }
      if (refreshed) {
        try {
          final token = await _storage.read(StorageKeys.authToken);
          final original = err.requestOptions;
          original.headers['Authorization'] = 'Bearer $token';
          original.extra['sessionRetried'] = true;
          final response = await _dio.fetch<dynamic>(original);
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
          handler.next(retryError);
          return;
        }
      }
    }
    if (mustInvalidateSession) {
      await _invalidateSessionOnce();
    }

    super.onError(err, handler);
  }

  Future<bool> _refreshDeviceSession() async {
    final refreshToken = await _storage.read(StorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      // Cliente aislado para no recursar por el interceptor de autenticación.
      final client = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ));
      final response = await client.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final data = body?['data'];
      if (body?['success'] != true || data is! Map) return false;
      final token = data['token']?.toString();
      final nextRefresh = data['refreshToken']?.toString();
      if (token == null || token.isEmpty || nextRefresh == null || nextRefresh.isEmpty) return false;
      await _storage.write(StorageKeys.authToken, token);
      await _storage.write(StorageKeys.refreshToken, nextRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _invalidateSessionOnce() async {
    if (_invalidatingSession) return;
    _invalidatingSession = true;
    ErrorTelemetry.instance.clearSession();

    // La navegación debe reaccionar en el mismo instante en que llega el 401.
    // No esperamos a Secure Storage ni mostramos primero el error de la vista.
    _sessionExpirationNotifier.sessionExpired();

    try {
      await _storage.clear();
    } finally {
      _invalidatingSession = false;
    }
  }
}
