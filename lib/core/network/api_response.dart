/// Error de validación o negocio devuelto por el backend.
class ApiError {
  const ApiError({this.field, this.code, required this.message});

  final String? field;
  final String? code;
  final String message;

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        field: json['field']?.toString(),
        code: json['code']?.toString(),
        message: json['message']?.toString() ?? 'Error desconocido',
      );
}

/// Respuesta estándar del backend BarLytics.
class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.success,
    required this.data,
    required this.errors,
    required this.timestamp,
  });

  final String code;
  final String message;
  final bool success;
  final T? data;
  final List<ApiError> errors;
  final DateTime? timestamp;

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) parser) {
    final errorsJson = json['errors'];
    return ApiResponse<T>(
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      success: json['success'] == true,
      data: json.containsKey('data') ? parser(json['data']) : null,
      errors: errorsJson is List
          ? errorsJson.whereType<Map>().map((e) => ApiError.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    );
  }
}
