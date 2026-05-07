import '../../../../app/router/module_registry.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_menu_item.dart';

/// Repositorio de menú autorizado.
///
/// El frontend ya no consulta ROLES, OPCIONMENU ni MENUS completos. El backend
/// resuelve la seguridad con el JWT y devuelve solo las opciones que pertenecen
/// al usuario autenticado.
class UserMenuRepository {
  const UserMenuRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserMenuItem>> findMyMenu() async {
    final response = await _apiClient.get<List<UserMenuItem>>(
      ApiPaths.authMeMenus,
      (json) => (json as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => UserMenuItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.keyName.isNotEmpty)
          .toList(growable: false),
    );

    final byKey = <String, UserMenuItem>{};
    for (final item in response.data ?? const <UserMenuItem>[]) {
      final normalizedKey = _normalizeModuleKey(item.keyName);
      final keyName = moduleAliases[normalizedKey] ?? normalizedKey;
      if (!moduleByKey.containsKey(keyName) && keyName != 'reportes') continue;
      byKey[keyName] = item.copyWith(keyName: keyName, path: '/$keyName');
    }
    return _sortByRegistry(byKey.values);
  }

  List<UserMenuItem> _sortByRegistry(Iterable<UserMenuItem> items) {
    final order = <String, int>{
      for (var i = 0; i < moduleRegistry.length; i++) moduleRegistry[i].key: i,
      'reportes': moduleRegistry.length + 1,
    };
    final list = items.toList(growable: false);
    list.sort((a, b) => (order[a.keyName] ?? 9999).compareTo(order[b.keyName] ?? 9999));
    return list;
  }

  String _normalizeModuleKey(String value) {
    var result = value.trim().toLowerCase();
    result = result.replaceFirst(RegExp(r'^/'), '');
    result = result.replaceFirst(RegExp(r'^api/v1/'), '');
    result = result.replaceAll('-', '_').replaceAll(' ', '_');
    result = result.replaceAll(RegExp(r'[^a-z0-9_/]'), '');
    if (result.contains('/')) {
      result = result.split('/').where((part) => part.isNotEmpty).last;
    }
    return result;
  }
}

final moduleByKey = <String, dynamic>{
  for (final module in moduleRegistry) module.key: module,
};

const moduleAliases = <String, String>{
  'cuentasventa': 'cuentas_venta',
  'cuentas_venta': 'cuentas_venta',
  'detallecuentaventa': 'detalle_cuenta_venta',
  'detalle_cuenta_venta': 'detalle_cuenta_venta',
  'mediospago': 'medios_pago',
  'medios_pago': 'medios_pago',
  'opcionesmenu': 'opciones_menu',
  'opciones_menu': 'opciones_menu',
  'tiposproducto': 'tipos_producto',
  'tipos_producto': 'tipos_producto',
  'zonashorarias': 'zonas_horarias',
  'zonas_horarias': 'zonas_horarias',
  'inventarios': 'inventario',
  'reporte': 'reportes',
  'reportes': 'reportes',
  'dashboard': 'reportes',
  'pagocuentaventa': 'pagos',
  'pago_cuenta_venta': 'pagos',
};
