import 'package:dio/dio.dart';

/// Convierte errores de guardado en mensajes breves y útiles para el negocio.
/// Evita mostrar el stack o el texto técnico completo de Dio en SnackBar.
String menuDigitalSaveErrorMessage(Object error, {required String style}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final detail = body is Map ? (body['message'] ?? '').toString().trim() : '';
    const newStyles = <String>{
      'DOCUMENTO', 'ELEGANTE', 'TIENDA_WEB', 'BISTRO', 'NOCTURNO',
    };
    if (status == 409 && newStyles.contains(style)) {
      return 'El servidor rechazó el diseño $style (HTTP 409). '
          'Comprueba que la base de datos tenga aplicada la migración '
          'Flyway V75, que habilita los 10 estilos. '
          'Si ya la tiene, revisa los registros del backend.';
    }
    if (status == 409) {
      return detail.isEmpty
          ? 'No se pudo guardar por un conflicto de datos (HTTP 409). '
              'Comprueba los registros del backend.'
          : 'No se pudo guardar por un conflicto de datos (HTTP 409): '
              '${detail.length > 160 ? detail.substring(0, 160) : detail}';
    }
    if (status == 413) {
      return 'Las imágenes superan el tamaño permitido por el servidor. '
          'Reduce alguna fotografía y vuelve a guardar.';
    }
    if (status == 401 || status == 403) {
      return 'No tienes autorización para guardar esta carta. '
          'Verifica tu sesión y los permisos del rol.';
    }
    if (status != null && status >= 500) {
      return 'El servidor no pudo guardar la carta (HTTP $status). '
          'Revisa el Centro de errores e inténtalo nuevamente.';
    }
    if (status == null) {
      return 'No hubo respuesta del servidor al guardar la carta. '
          'Comprueba la conexión y que el backend esté funcionando.';
    }
    return 'No se pudo guardar la carta (HTTP $status). '
        '${detail.isEmpty ? 'Revisa los datos del formulario.' : detail}';
  }
  return 'No se pudo guardar la carta. Revisa el Centro de errores '
      'y vuelve a intentarlo.';
}
