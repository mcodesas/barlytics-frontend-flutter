import '../network/api_client.dart';
import 'crud_module_config.dart';

/// DataSource genérico para CRUDs REST.
class CrudRemoteDataSource<T> {
  CrudRemoteDataSource(this._apiClient, this._config);

  final ApiClient _apiClient;
  final CrudModuleConfig<T> _config;

  Future<List<T>> list() async {
    final response = await _apiClient.get<List<T>>(
      _config.basePath,
      (json) => (json as List? ?? const [])
          .whereType<Map>()
          .map((e) => _config.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
    return response.data ?? <T>[];
  }

  Future<T> findById(Object id) async {
    final response = await _apiClient.get<T>(
      '${_config.basePath}/$id',
      (json) => _config.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data as T;
  }

  Future<T> create(Map<String, dynamic> body) async {
    final response = await _apiClient.post<T>(
      _config.basePath,
      body,
      (json) => _config.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data as T;
  }

  Future<T> update(Object id, Map<String, dynamic> body) async {
    final response = await _apiClient.put<T>(
      '${_config.basePath}/$id',
      body,
      (json) => _config.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data as T;
  }

  Future<void> delete(Object id) async {
    await _apiClient.delete<void>('${_config.basePath}/$id', (_) => null);
  }

  Future<List<T>> getListByPath(String path) async {
    final response = await _apiClient.get<List<T>>(
      path,
      (json) => (json as List? ?? const [])
          .whereType<Map>()
          .map((e) => _config.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
    return response.data ?? <T>[];
  }
}
