import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

final errorCenterRepositoryProvider = Provider<ErrorCenterRepository>((ref) =>
    ErrorCenterRepository(ref.watch(apiClientProvider)));

/// Solo el administrador global puede llamar a las consultas del backend.
/// Los filtros se aplican en SQL; no se descarga el log de todos los clientes.
class ErrorCenterRepository {
  const ErrorCenterRepository(this._client);

  final ApiClient _client;
  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  Future<Map<String, dynamic>> metrics() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/error-center/metrics', _map);
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> issues({
    String status = '',
    String severity = '',
    String platform = '',
    String origin = '',
    String category = '',
    String search = '',
    int? companyId,
    int page = 0,
    int size = 25,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/error-center/issues',
      _map,
      queryParameters: {
        if (status.isNotEmpty) 'status': status,
        if (severity.isNotEmpty) 'severity': severity,
        if (platform.isNotEmpty) 'platform': platform,
        if (origin.isNotEmpty) 'origin': origin,
        if (category.isNotEmpty) 'category': category,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (companyId != null) 'companyId': companyId,
        'page': page,
        'size': size,
      },
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/error-center/issues/$id', _map);
    return response.data ?? {};
  }

  Future<void> updateStatus(int id, String status) async {
    await _client.put<Map<String, dynamic>>(
      '/api/v1/error-center/issues/$id/status',
      {'status': status},
      _map,
    );
  }

  Future<void> addNote(int id, String note) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v1/error-center/issues/$id/notes',
      {'note': note},
      _map,
    );
  }

  static List<Map<String, dynamic>> rows(Object? raw) =>
      (raw is List ? raw : const <Object>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  static int number(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
}
