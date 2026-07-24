import 'package:dio/dio.dart';

import '../constants/storage_keys.dart';
import '../storage/secure_storage_service.dart';

/// Interceptor que agrega JWT y limpia sesión ante respuestas 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorageService _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _storage.clear();
    }
    super.onError(err, handler);
  }
}
