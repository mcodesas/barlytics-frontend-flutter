import 'app_exception.dart';
import 'failure.dart';

/// Convierte excepciones técnicas en fallos funcionales para la UI.
class ErrorMapper {
  static Failure map(Object error) {
    if (error is AppException) {
      return switch (error.statusCode) {
        401 => UnauthorizedFailure(error.message, code: error.code, statusCode: error.statusCode),
        403 => UnauthorizedFailure(error.message, code: error.code, statusCode: error.statusCode),
        404 => NotFoundFailure(error.message, code: error.code, statusCode: error.statusCode),
        >= 500 => ServerFailure(error.message, code: error.code, statusCode: error.statusCode),
        _ => ValidationFailure(error.message, code: error.code, statusCode: error.statusCode),
      };
    }
    return ServerFailure(error.toString());
  }
}
