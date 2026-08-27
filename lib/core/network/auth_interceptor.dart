import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../constants/storage_keys.dart';
import '../storage/secure_storage_service.dart';
import 'session_expiration_notifier.dart';

/// Interceptor que agrega JWT y fuerza el cierre local de sesión cuando una
/// petición autenticada deja de ser confiable.
///
/// Se invalida la sesión ante 401/403 y también cuando el backend no entrega
/// ninguna respuesta (caída, timeout o error de conexión). Las peticiones
/// públicas, como el login, no disparan este comportamiento porque no llevan
/// cabecera Authorization.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._sessionExpirationNotifier);

  final SecureStorageService _storage;
  final SessionExpirationNotifier _sessionExpirationNotifier;

  bool _invalidatingSession = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isPublicRequest = options.path == ApiPaths.publicSiteConfig ||
        options.path == ApiPaths.publicSubscriptionPlans;
    final token = isPublicRequest ? null : await _storage.read(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }
    options.headers['Accept'] = 'application/json';
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final hadAuthenticatedRequest =
        err.requestOptions.headers['Authorization']?.toString().trim().isNotEmpty == true;
    final statusCode = err.response?.statusCode;

    // En Flutter Web, una caída del backend suele llegar como DioException sin
    // response (XMLHttpRequest onError). Cancelaciones voluntarias no deben
    // cerrar la sesión.
    final backendUnavailable =
        err.response == null && err.type != DioExceptionType.cancel;

    final mustInvalidateSession = hadAuthenticatedRequest &&
        (statusCode == 401 || statusCode == 403 || backendUnavailable);

    if (mustInvalidateSession) {
      await _invalidateSessionOnce();
    }

    super.onError(err, handler);
  }

  Future<void> _invalidateSessionOnce() async {
    if (_invalidatingSession) return;
    _invalidatingSession = true;
    try {
      await _storage.clear();
    } finally {
      // La navegación depende del estado de autenticación, no de que el
      // backend haya podido responder. Por eso siempre notificamos.
      _sessionExpirationNotifier.sessionExpired();
      _invalidatingSession = false;
    }
  }
}
