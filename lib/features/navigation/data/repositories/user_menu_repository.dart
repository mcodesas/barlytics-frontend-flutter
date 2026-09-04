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
      final normalizedItem = item.copyWith(keyName: keyName, path: '/$keyName');
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
      'reportes': moduleRegistry.length + 1,
      'ganancias': moduleRegistry.length + 2,
      'proximo_pedido': moduleRegistry.length + 3,
      'roles_personalizados': moduleRegistry.length + 4,
      'soporte_global': moduleRegistry.length + 5,
      'explorador_datos': moduleRegistry.length + 6,
      'auditoria_soporte': moduleRegistry.length + 7,
      'diagnostico_sistema': moduleRegistry.length + 8,
      'soporte_clientes': moduleRegistry.length + 9,
      'soporte_accesos': moduleRegistry.length + 10,
      'soporte_operacion': moduleRegistry.length + 11,
      'soporte_configuracion': moduleRegistry.length + 12,
      'soporte_mantenimiento': moduleRegistry.length + 13,
      'sincronizar_catalogo': moduleRegistry.length + 14,
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
  'reporte': 'reportes',
  'reportes': 'reportes',
  'ganancia': 'ganancias',
  'ganancias': 'ganancias',
  'proximo_pedido': 'proximo_pedido',
  'proximopedido': 'proximo_pedido',
  'pedido': 'proximo_pedido',
  'dashboard': 'reportes',
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
