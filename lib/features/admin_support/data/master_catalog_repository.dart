import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

final masterCatalogRepositoryProvider = Provider<MasterCatalogRepository>((ref) {
  return MasterCatalogRepository(ref.watch(apiClientProvider));
});

class MasterCatalogRepository {
  const MasterCatalogRepository(this.client);
  final ApiClient client;

  static const String endpoint = '/api/v1/admin/catalogo-maestro';

  Future<List<Map<String, dynamic>>> list() async {
    final result = await client.get<List<Map<String, dynamic>>>(
      endpoint,
      (json) => (json as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
    );
    return result.data ?? const <Map<String, dynamic>>[];
  }

  Future<void> create(Map<String, dynamic> item) async {
    await client.post<Map<String, dynamic>>(
      endpoint,
      item,
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> update(int id, Map<String, dynamic> item) async {
    await client.put<Map<String, dynamic>>(
      '$endpoint/$id',
      item,
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> setActive(int id, bool active) async {
    await client.put<Map<String, dynamic>>(
      '$endpoint/$id/estado',
      <String, dynamic>{'activo': active},
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }
}
