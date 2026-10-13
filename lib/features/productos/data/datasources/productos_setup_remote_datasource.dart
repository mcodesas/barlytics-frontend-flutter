import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

class ProductosSetupRemoteDataSource {
  ProductosSetupRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Uint8List> downloadTemplate() {
    return _apiClient.getBytes('/api/v1/productos/setup/template');
  }

  Future<Map<String, dynamic>> importExcel({
    required int sucursalId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _apiClient.postMultipart<Map<String, dynamic>>(
      '/api/v1/productos/setup/import-excel',
      formData,
      (json) => Map<String, dynamic>.from(json as Map),
      queryParameters: <String, dynamic>{'sucursalId': sucursalId},
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> copySelected({
    required int sourceSucursalId,
    required int targetSucursalId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/productos/setup/copy-selected',
      <String, dynamic>{
        'sourceSucursalId': sourceSucursalId,
        'targetSucursalId': targetSucursalId,
        'items': items,
      },
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data ?? const <String, dynamic>{};
  }
}
