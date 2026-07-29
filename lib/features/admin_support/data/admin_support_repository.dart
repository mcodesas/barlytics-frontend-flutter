import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

final adminSupportRepositoryProvider = Provider<AdminSupportRepository>((ref) {
  return AdminSupportRepository(ref.watch(apiClientProvider));
});

class AdminSupportRepository {
  const AdminSupportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> overview() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/overview',
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> catalog() async {
    final response = await _apiClient.get<List<Map<String, dynamic>>>(
      '/api/v1/admin/support/catalog',
      _list,
    );
    return response.data ?? const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> tables() async {
    final response = await _apiClient.get<List<Map<String, dynamic>>>(
      '/api/v1/admin/support/tables',
      _list,
    );
    return response.data ?? const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> records({
    required String table,
    int page = 0,
    int size = 25,
    String? search,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/tables/$table/records',
      _map,
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createRecord({
    required String table,
    required Map<String, dynamic> values,
    String? reason,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/tables/$table/records',
      <String, dynamic>{
        'values': values,
        'reason': reason,
      },
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateRecord({
    required String table,
    required Map<String, dynamic> keys,
    required Map<String, dynamic> changes,
    String? reason,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/admin/support/tables/$table/records',
      <String, dynamic>{
        'keys': keys,
        'changes': changes,
        'reason': reason,
      },
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteRecord({
    required String table,
    required Map<String, dynamic> keys,
    required String confirmation,
    String? reason,
  }) async {
    await _apiClient.deleteWithBody<void>(
      '/api/v1/admin/support/tables/$table/records',
      <String, dynamic>{
        'keys': keys,
        'confirmation': confirmation,
        'reason': reason,
      },
      (_) {},
    );
  }

  Future<Map<String, dynamic>> audit({
    int page = 0,
    int size = 30,
    String? search,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/audit',
      _map,
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> diagnostics() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/diagnostics',
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> repairSequences() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/repair/sequences',
      const <String, dynamic>{},
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> repairOrphans() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/repair/orphans',
      const <String, dynamic>{},
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> repairAdminPermissions() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/repair/admin-permissions',
      const <String, dynamic>{},
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> unlockUser(int userId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/users/$userId/unlock',
      const <String, dynamic>{},
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }


  Future<Map<String, dynamic>> productCatalogSyncOptions() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/product-catalog-sync/options',
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> previewProductCatalogSync({
    required int sourceCompanyId,
    required int sourceBranchId,
    required int targetCompanyId,
    required List<int> targetBranchIds,
    required String mode,
    List<int> productIds = const <int>[],
    String? search,
    bool includeImages = true,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/product-catalog-sync/preview',
      <String, dynamic>{
        'sourceCompanyId': sourceCompanyId,
        'sourceBranchId': sourceBranchId,
        'targetCompanyId': targetCompanyId,
        'targetBranchIds': targetBranchIds,
        'mode': mode,
        'productIds': productIds,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'includeImages': includeImages,
      },
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> executeProductCatalogSync({
    required int sourceCompanyId,
    required int sourceBranchId,
    required int targetCompanyId,
    required List<int> targetBranchIds,
    required String mode,
    required List<int> productIds,
    required String reason,
    bool includeImages = true,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/admin/support/product-catalog-sync/execute',
      <String, dynamic>{
        'sourceCompanyId': sourceCompanyId,
        'sourceBranchId': sourceBranchId,
        'targetCompanyId': targetCompanyId,
        'targetBranchIds': targetBranchIds,
        'mode': mode,
        'productIds': productIds,
        'includeImages': includeImages,
        'reason': reason.trim(),
      },
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> productCatalogSyncHistory({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/product-catalog-sync/history',
      _map,
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> productCatalogSyncHistoryDetail(int runId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/admin/support/product-catalog-sync/history/$runId',
      _map,
    );
    return response.data ?? <String, dynamic>{};
  }

  static Map<String, dynamic> _map(Object? json) {
    if (json is Map) return Map<String, dynamic>.from(json);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(Object? json) {
    return (json as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
