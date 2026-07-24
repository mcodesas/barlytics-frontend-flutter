import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_interceptor.dart';
import 'auth_interceptor.dart';

/// Construye una instancia Dio configurada para el backend BarLytics.
class DioClient {
  static Dio create(SecureStorageService storage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ),
    );
    dio.interceptors.addAll([ApiInterceptor(), AuthInterceptor(storage)]);
    return dio;
  }
}
