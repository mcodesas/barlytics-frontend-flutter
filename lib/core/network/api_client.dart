import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import 'api_response.dart';

/// Cliente HTTP centralizado. Ningún widget debe llamar directamente a Dio.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<ApiResponse<T>> get<T>(
    String path,
    T Function(Object? json) parser, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _send(() => _dio.get(path, queryParameters: queryParameters), parser);
  }

  Future<ApiResponse<T>> post<T>(
    String path,
    Object? body,
    T Function(Object? json) parser, {
    Map<String, dynamic>? headers,
  }) async {
    return _send(
      () => _dio.post(
        path,
        data: body,
        options: headers == null ? null : Options(headers: headers),
      ),
      parser,
    );
  }

  Future<ApiResponse<T>> put<T>(String path, Object? body, T Function(Object? json) parser) async {
    return _send(() => _dio.put(path, data: body), parser);
  }

  Future<ApiResponse<T>> delete<T>(String path, T Function(Object? json) parser) async {
    return _send(() => _dio.delete(path), parser);
  }

  Future<ApiResponse<T>> deleteWithBody<T>(
    String path,
    Object? body,
    T Function(Object? json) parser,
  ) async {
    return _send(() => _dio.delete(path, data: body), parser);
  }

  Future<ApiResponse<T>> _send<T>(Future<Response<dynamic>> Function() request, T Function(Object? json) parser) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final apiResponse = ApiResponse<T>.fromJson(data, parser);
        if (!apiResponse.success) {
          final message = apiResponse.errors.isNotEmpty ? apiResponse.errors.first.message : apiResponse.message;
          throw ApiException(message, code: apiResponse.code, statusCode: response.statusCode);
        }
        return apiResponse;
      }
      throw const ApiException('Respuesta inválida del servidor');
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        final errors = body['errors'];
        String? detailMessage;
        String? detailCode;
        if (errors is List && errors.isNotEmpty && errors.first is Map) {
          final firstError = Map<String, dynamic>.from(errors.first as Map);
          detailMessage = firstError['message']?.toString();
          detailCode = firstError['code']?.toString();
        }
        final message = (detailMessage != null && detailMessage.trim().isNotEmpty)
            ? detailMessage
            : body['message']?.toString() ?? 'Error de servidor';
        throw ApiException(message, code: detailCode ?? body['code']?.toString(), statusCode: e.response?.statusCode);
      }
      throw NetworkException(e.message ?? 'No fue posible conectar con el backend', statusCode: e.response?.statusCode);
    }
  }
}
