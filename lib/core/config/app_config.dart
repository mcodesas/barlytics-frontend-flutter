import 'environment.dart';

/// Configuración global consumida por servicios compartidos.
class AppConfig {
  static String get apiBaseUrl => Environment.baseUrl;
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
}
