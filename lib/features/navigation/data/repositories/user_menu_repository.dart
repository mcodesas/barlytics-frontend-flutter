import '../../../../app/router/module_registry.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../menus/data/models/menus_response_model.dart';
import '../../../opciones_menu/data/models/opciones_menu_response_model.dart';
import '../../../roles/data/models/roles_response_model.dart';
import '../models/user_menu_item.dart';

/// Repositorio que construye el menú visible del usuario desde el backend.
///
/// El modelo de datos define la relación:
/// USUARIOROL -> ROLES -> OPCIONMENU -> MENUS.
/// El login devuelve los nombres de roles del usuario; con esos nombres se
/// resuelven los IDs reales de roles, luego se filtran las opciones de menú y
/// finalmente se obtienen los MENUS que Flutter debe mostrar.
class UserMenuRepository {
  const UserMenuRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserMenuItem>> findMenuForRoles(List<String> roleNames) async {
    final normalizedRoleNames = roleNames.map(_normalizeRole).where((role) => role.isNotEmpty).toSet();
    if (normalizedRoleNames.isEmpty) return const <UserMenuItem>[];

    final roles = await _loadRoles();
    final authorizedRoleIds = roles
        .where((role) {
          final byName = normalizedRoleNames.contains(_normalizeRole(role.roleNombre));
          final byId = role.roleId != null && normalizedRoleNames.contains(role.roleId.toString());
          return byName || byId;
        })
        .map((role) => role.roleId)
        .whereType<int>()
        .toSet();

    if (authorizedRoleIds.isEmpty) return const <UserMenuItem>[];

    final options = await _loadOptions();
    final authorizedOptions = options.where((option) => authorizedRoleIds.contains(option.roleId)).toList(growable: false);
    final authorizedMenuIds = authorizedOptions.map((option) => option.menuId).whereType<int>().toSet();

    if (authorizedMenuIds.isEmpty) return const <UserMenuItem>[];

    final menus = await _loadMenus();
    final optionsByMenuId = <int, OpcionesMenuResponseModel>{
      for (final option in authorizedOptions)
        if (option.menuId != null) option.menuId!: option,
    };

    final byKey = <String, UserMenuItem>{};
    for (final menu in menus.where((menu) => authorizedMenuIds.contains(menu.menuId))) {
      final keyName = _moduleKeyFromMenu(menu);
      if (keyName == null) continue;

      final module = moduleByKey[keyName];
      final option = menu.menuId == null ? null : optionsByMenuId[menu.menuId];
      final title = _cleanTitle(option?.opmeNombre) ?? _cleanTitle(menu.menuNombre) ?? module?.title ?? (keyName == 'reportes' ? 'Reportes' : _fallbackTitle(keyName));

      byKey[keyName] = UserMenuItem(
        keyName: keyName,
        title: title,
        path: '/$keyName',
        description: option?.opmeDescripcion ?? menu.menuDescripcion,
        menuId: menu.menuId,
        roleId: option?.roleId,
        optionId: option?.opmeId,
      );
    }

    final items = byKey.values.toList(growable: false);
    return _sortByRegistry(items);
  }

  Future<List<RolesResponseModel>> _loadRoles() async {
    final response = await _apiClient.get<List<RolesResponseModel>>(
      ApiPaths.roles,
      (json) => (json as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => RolesResponseModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
    return response.data ?? const <RolesResponseModel>[];
  }

  Future<List<OpcionesMenuResponseModel>> _loadOptions() async {
    final response = await _apiClient.get<List<OpcionesMenuResponseModel>>(
      ApiPaths.opcionesmenu,
      (json) => (json as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => OpcionesMenuResponseModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
    return response.data ?? const <OpcionesMenuResponseModel>[];
  }

  Future<List<MenusResponseModel>> _loadMenus() async {
    final response = await _apiClient.get<List<MenusResponseModel>>(
      ApiPaths.menus,
      (json) => (json as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => MenusResponseModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
    return response.data ?? const <MenusResponseModel>[];
  }

  String? _moduleKeyFromMenu(MenusResponseModel menu) {
    final raw = menu.menuParametro?.trim().isNotEmpty == true ? menu.menuParametro : menu.menuNombre;
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = _normalizeModuleKey(raw);
    return moduleAliases[normalized] ?? (moduleByKey.containsKey(normalized) || normalized == 'reportes' ? normalized : null);
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

  String _normalizeRole(String? value) {
    return (value ?? '')
        .trim()
        .toUpperCase()
        .replaceFirst(RegExp(r'^ROLE_'), '')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
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

  String? _cleanTitle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _fallbackTitle(String keyName) {
    return keyName.split('_').map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1);
    }).join(' ');
  }
}

/// Acceso rápido a los módulos existentes en el router.
final moduleByKey = <String, dynamic>{
  for (final module in moduleRegistry) module.key: module,
};

/// Alias para soportar tanto nombres del frontend como nombres REST del backend.
/// Ejemplo: el endpoint es /api/v1/cuentasventa, pero la ruta Flutter es /cuentas_venta.
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
