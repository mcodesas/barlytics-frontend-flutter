import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/producto_catalogo_base_model.dart';
import '../models/productos_response_model.dart';

class ProductosSetupRemoteDataSource {
  ProductosSetupRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Uint8List> downloadTemplate() {
    return _apiClient.getBytes('/api/v1/productos/setup/template');
  }

  Future<Uint8List> downloadProductList(int sucursalId) {
    return _apiClient.getBytes(
      '/api/v1/productos/setup/export',
      queryParameters: <String, dynamic>{'sucursalId': sucursalId},
    );
  }

  Future<List<ProductosResponseModel>> branchProducts(int sucursalId) async {
    final response = await _apiClient.get<List<ProductosResponseModel>>(
      '/api/v1/productos/sucursal/$sucursalId',
      (json) => (json as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => ProductosResponseModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
    );
    return response.data ?? const <ProductosResponseModel>[];
  }

  Future<List<ProductoCatalogoBaseModel>> baseCatalog(int sucursalId) async {
    final response = await _apiClient.get<List<ProductoCatalogoBaseModel>>(
      '/api/v1/productos/setup/catalogo-base',
      (json) => (json as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => ProductoCatalogoBaseModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      queryParameters: <String, dynamic>{'sucursalId': sucursalId},
    );
    return response.data ?? const <ProductoCatalogoBaseModel>[];
  }

  Future<Map<String, dynamic>> importBaseCatalog({
    required int sucursalId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/productos/setup/catalogo-base/importar',
      <String, dynamic>{
        'sucursalId': sucursalId,
        'items': items,
      },
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data ?? const <String, dynamic>{};
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
