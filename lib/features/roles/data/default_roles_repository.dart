import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

final defaultRolesRepositoryProvider = Provider<DefaultRolesRepository>(
  (ref) => DefaultRolesRepository(ref.watch(apiClientProvider)),
);

/// Edición de roles predefinidos; el backend exige perfil administrador global.
class DefaultRolesRepository {
  const DefaultRolesRepository(this._api);
  final ApiClient _api;

  static Map<String, dynamic> toMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> toList(Object? value) =>
      value is List
          ? value.whereType<Map>()
              .map((element) => Map<String, dynamic>.from(element))
              .toList(growable: false)
          : const [];

  Future<List<Map<String, dynamic>>> roles() async {
    final response = await _api.get<List<Map<String, dynamic>>>(
      '/api/v1/roles/predefinidos',
      toList,
    );
    return response.data ?? const [];
  }

  Future<Map<String, dynamic>> details(int id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/roles/predefinidos/$id/menus',
      toMap,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> save(
      int id, List<int> menuIds, String description) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/v1/roles/predefinidos/$id/menus',
      {
        'menuIds': menuIds,
        'description': description.trim(),
      },
      toMap,
    );
    return response.data ?? {};
  }

  static int asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
