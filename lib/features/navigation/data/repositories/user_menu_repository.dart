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

  Future<List<UserMenuItem>> findMyMenu({bool preserveBackendOrder = false}) async {
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
      if (keyName.isEmpty) continue;
      final path = keyName == 'mesero_productos' ? '/mesero/productos' : '/$keyName';
      final normalizedItem = item.copyWith(keyName: keyName, path: path);
      final previous = byKey[keyName];
      if (previous == null) {
        byKey[keyName] = normalizedItem;
      } else {
        final mergedRoles = <String>{...previous.roles, ...normalizedItem.roles}.toList(growable: false);
        final bottomSource = normalizedItem.bottomVisible &&
                (!previous.bottomVisible || normalizedItem.bottomOrder < previous.bottomOrder)
            ? normalizedItem
            : previous;
        byKey[keyName] = previous.copyWith(
          roles: mergedRoles,
          roleTypes: <String>{...previous.roleTypes, ...normalizedItem.roleTypes}.toList(growable: false),
          bottomCode: bottomSource.bottomCode,
          bottomName: bottomSource.bottomName,
          bottomIcon: bottomSource.bottomIcon,
          bottomOrder: bottomSource.bottomOrder,
          bottomVisible: previous.bottomVisible || normalizedItem.bottomVisible,
          bottomPrimary: previous.bottomPrimary || normalizedItem.bottomPrimary,
        );
      }
    }


    final items = byKey.values.toList(growable: false);
    if (preserveBackendOrder) return items;
    return _sortByDatabaseNavigation(items);
  }

  List<UserMenuItem> _sortByDatabaseNavigation(Iterable<UserMenuItem> items) {
    final list = items.toList(growable: false);
    final hasDatabaseOrder = list.any((item) =>
        item.groupCode != 'OTROS' || item.groupOrder != 99 || item.menuOrder != 99);
    if (hasDatabaseOrder) {
      list.sort((a, b) {
        final group = a.groupOrder.compareTo(b.groupOrder);
        if (group != 0) return group;
        final menu = a.menuOrder.compareTo(b.menuOrder);
        if (menu != 0) return menu;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      return list;
    }
    return _sortByRegistry(list);
  }

  List<UserMenuItem> _sortByRegistry(Iterable<UserMenuItem> items) {
    final order = <String, int>{
      for (var i = 0; i < moduleRegistry.length; i++) moduleRegistry[i].key: i,
      'inventario_admin': moduleRegistry.length + 1,
      'dashboard': moduleRegistry.length + 2,
      'reportes': moduleRegistry.length + 3,
      'reporte_resumen_ejecutivo': moduleRegistry.length + 4,
      'reporte_ventas_fecha': moduleRegistry.length + 5,
      'reporte_ventas_medio_pago': moduleRegistry.length + 6,
      'reporte_stock_actual': moduleRegistry.length + 7,
      'ganancias': moduleRegistry.length + 8,
      'proximo_pedido': moduleRegistry.length + 9,
      'reporte_cruce_conteo': moduleRegistry.length + 10,
      'reporte_productos_mas_vendidos': moduleRegistry.length + 11,
      'reporte_movimientos_inventario': moduleRegistry.length + 12,
      'reporte_rotacion_inventario': moduleRegistry.length + 13,
      'reporte_alertas_inventario': moduleRegistry.length + 14,
      'reporte_salidas_responsable': moduleRegistry.length + 15,
      'roles_personalizados': moduleRegistry.length + 16,
      'soporte_global': moduleRegistry.length + 17,
      'explorador_datos': moduleRegistry.length + 18,
      'auditoria_soporte': moduleRegistry.length + 19,
      'diagnostico_sistema': moduleRegistry.length + 20,
      'soporte_clientes': moduleRegistry.length + 21,
      'soporte_accesos': moduleRegistry.length + 22,
      'soporte_operacion': moduleRegistry.length + 23,
      'soporte_configuracion': moduleRegistry.length + 24,
      'soporte_mantenimiento': moduleRegistry.length + 25,
      'sincronizar_catalogo': moduleRegistry.length + 26,
      'mesero_productos': moduleRegistry.length + 27,
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
  'inventarioadmin': 'inventario_admin',
  'inventario_admin': 'inventario_admin',
  'reporte': 'reportes',
  'reportes': 'reportes',
  'ganancia': 'ganancias',
  'ganancias': 'ganancias',
  'proximo_pedido': 'proximo_pedido',
  'proximopedido': 'proximo_pedido',
  'pedido': 'proximo_pedido',
  'dashboard': 'dashboard',
  'rolespersonalizados': 'roles_personalizados',
  'roles_personalizados': 'roles_personalizados',
  'pagocuentaventa': 'pagos',
  'pago_cuenta_venta': 'pagos',
  'soporteglobal': 'soporte_global',
  'soporte_global': 'soporte_global',
  'exploradordatos': 'explorador_datos',
  'explorador_datos': 'explorador_datos',
  'auditoriasoporte': 'auditoria_soporte',
  'auditoria_soporte': 'auditoria_soporte',
  'diagnosticosistema': 'diagnostico_sistema',
  'diagnostico_sistema': 'diagnostico_sistema',
  'soporteclientes': 'soporte_clientes',
  'soporte_clientes': 'soporte_clientes',
  'soporteaccesos': 'soporte_accesos',
  'soporte_accesos': 'soporte_accesos',
  'soporteoperacion': 'soporte_operacion',
  'soporte_operacion': 'soporte_operacion',
  'soporteconfiguracion': 'soporte_configuracion',
  'soporte_configuracion': 'soporte_configuracion',
  'soportemantenimiento': 'soporte_mantenimiento',
  'soporte_mantenimiento': 'soporte_mantenimiento',
  'sincronizarcatalogo': 'sincronizar_catalogo',
  'sincronizar_catalogo': 'sincronizar_catalogo',
};
