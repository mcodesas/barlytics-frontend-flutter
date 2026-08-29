import 'package:dio/dio.dart';

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

    // 401 = token ausente/expirado/inválido.
    // 403 = sesión válida sin permiso: se conserva la sesión y la pantalla puede
    // mostrar el error funcional sin expulsar al usuario.
    final mustInvalidateSession = hadAuthenticatedRequest && statusCode == 401;

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
