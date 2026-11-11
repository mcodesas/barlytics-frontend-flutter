import 'package:dio/dio.dart';

/// Interceptor para cabeceras generales y trazabilidad no sensible.
class ApiInterceptor extends Interceptor {
  static int _sequence = 0;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Content-Type'] = 'application/json';
    // Identificador técnico para unir el HTTP 500 del cliente con su
    // excepción Spring Boot; no es un token ni contiene datos del usuario.
    _sequence = (_sequence + 1) % 1000000;
    options.headers.putIfAbsent('X-Request-Id', () =>
        'bl-' + DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        '-' + _sequence.toRadixString(16));
    super.onRequest(options, handler);
  }
}
