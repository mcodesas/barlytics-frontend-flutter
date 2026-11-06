import 'app_exception.dart';
import 'failure.dart';
import '../telemetry/error_telemetry.dart';

/// Convierte excepciones técnicas en fallos funcionales para la UI.
class ErrorMapper {
  static Failure map(Object error) {
    if (error is AppException) {
      final statusCode = error.statusCode ?? 0;
      if (statusCode >= 500) {
        ErrorTelemetry.instance.capture(
          category: 'handled_http_5xx',
          errorType: error.runtimeType.toString(),
          message: 'Error HTTP ' + statusCode.toString(),
          module: 'error_mapper',
          httpStatus: statusCode,
        );
      }

      return switch (statusCode) {
        401 => UnauthorizedFailure(error.message, code: error.code, statusCode: error.statusCode),
        403 => UnauthorizedFailure(error.message, code: error.code, statusCode: error.statusCode),
        404 => NotFoundFailure(error.message, code: error.code, statusCode: error.statusCode),
        >= 500 => ServerFailure(error.message, code: error.code, statusCode: error.statusCode),
        _ => ValidationFailure(error.message, code: error.code, statusCode: error.statusCode),
      };
    }
    // Errores que fueron atrapados y mostrados en pantalla también deben
    // reportarse: sin esto el manejador global nunca los recibe.
    ErrorTelemetry.instance.capture(
      category: 'handled_unexpected',
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      stacktrace: StackTrace.current.toString(),
      module: 'error_mapper',
    );
    return ServerFailure(error.toString());
  }
}
