/// Excepción base funcional de la aplicación.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'AppException($statusCode, $code, $message)';
}

class ApiException extends AppException {
  const ApiException(super.message, {super.code, super.statusCode});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.statusCode});
}
