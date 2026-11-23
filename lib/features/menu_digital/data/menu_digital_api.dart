import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/branch/branch_scope_provider.dart';

final menuDigitalApiProvider = Provider<MenuDigitalApi>((ref) {
  return MenuDigitalApi(ref.watch(dioProvider),
      () => ref.read(branchScopeProvider).activeBranchId);
});

class MenuDigitalApi {
  const MenuDigitalApi(this.dio, this.currentBranchId);
  final Dio dio;
  final int? Function() currentBranchId;

  int get branch {
    final id = currentBranchId();
    if (id == null) throw StateError('Selecciona una sucursal.');
    return id;
  }

  String get server => AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> _row(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  Future<Map<String, dynamic>> admin() async =>
      _row((await dio.get<dynamic>('/api/v1/menu-digital',
        queryParameters: {'sucursalId': branch})).data);

  Future<List<Map<String, dynamic>>> catalogo() async =>
      _rows((await dio.get<dynamic>('/api/v1/menu-digital/catalogo',
        queryParameters: {'sucursalId': branch})).data);

  Future<Map<String, dynamic>> guardar(Map<String, dynamic> values) async {
    if (values['sucursalId'] != branch) {
      throw StateError('No es posible guardar en otra sucursal.');
    }
    return _row((await dio.put<dynamic>('/api/v1/menu-digital',
      queryParameters: {'sucursalId': branch},
      data: values)).data);
  }

  Future<Map<String, dynamic>> publicar(bool enabled) async =>
      _row((await dio.post<dynamic>(
        enabled ? '/api/v1/menu-digital/publicar' : '/api/v1/menu-digital/ocultar',
        queryParameters: {'sucursalId': branch})).data);

  Future<Map<String, dynamic>> publico(String slug) async =>
      _row((await dio.get<dynamic>(
        '/api/v1/menu-digital/public/' + Uri.encodeComponent(slug))).data);

  Future<void> reportarContenido(String slug, String motivo, String detalles) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}
      'https://www.barlytics.com.co/#/carta/' + Uri.encodeComponent(slug);
}
).hasMatch(slug)) {
      throw StateError('El enlace de la carta no es válido.');
    }
    await dio.post<dynamic>(
      '/api/v1/menu-digital/public/' + Uri.encodeComponent(slug) + '/report',
      data: <String, dynamic>{
        'motivo': motivo,
        'detalles': detalles.trim(),
      },
    );
  }

  String publicUrl(String slug) =>
      'https://www.barlytics.com.co/#/carta/' + Uri.encodeComponent(slug);
}
