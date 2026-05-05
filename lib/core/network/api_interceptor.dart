import 'package:dio/dio.dart';

/// Interceptor para cabeceras generales y trazabilidad no sensible.
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Content-Type'] = 'application/json';
    super.onRequest(options, handler);
  }
}
