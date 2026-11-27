import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_menu_item.dart';
import '../../data/repositories/user_menu_repository.dart';
import 'active_role_provider.dart';
import 'user_assigned_roles_provider.dart';
import 'menu_preferences_provider.dart';

final userMenuRepositoryProvider = Provider<UserMenuRepository>((ref) {
  return UserMenuRepository(ref.watch(apiClientProvider));
});

/// Menú autorizado del usuario autenticado.
///
/// Se consulta desde el backend usando el JWT. El frontend no descarga todas
/// las tablas de roles, opciones y menús para resolver permisos.
final userMenuProvider = FutureProvider<List<UserMenuItem>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (!authState.authenticated) return const <UserMenuItem>[];
  final activeRoles = ref.watch(activeRolesProvider);
  final hasCustomRole = activeRoles.any(
    (role) => normalizeRoleName(role) == 'PERSONALIZADO',
  );
  final selection = ref.watch(selectedRolesProvider);
  final customIds = selection?.map(customRoleIdFromSelection)
          .whereType<int>().toSet() ?? <int>{};
  final onlyCustomView = hasCustomRole && activeRoles.length == 1 &&
      (selection == null || (selection.length == 1 &&
          (customIds.length == 1 ||
           selection.any((value) => normalizeRoleName(value) == 'PERSONALIZADO'))));

  // Capturar dependencias de Riverpod ANTES de cualquier await.
  final repository = ref.watch(userMenuRepositoryProvider);
  // Si aún no se desplegó el endpoint nuevo, conservar el menú tradicional.
  final preferencesFuture = ref.watch(menuPreferencesProvider.future)
      .catchError((_) => const MenuPreferences());
  final allItems = await repository.findMyMenu(
    preserveBackendOrder: onlyCustomView,
  );
  final preferences = await preferencesFuture;
  final filteredItems = filterMenusBySelectedRoles(allItems, selection);

  final customFiltered = onlyCustomView
      ? orderMenusForCustomRole(filteredItems,
          roleId: customIds.length == 1 ? customIds.first : null)
      : filteredItems;

  final normalizedActive = activeRoles.map(normalizeRoleName).toSet();
  // Si el usuario selecciona una vista de rol nativo, su prioridad de menú
  // prevalece sobre la de los demás roles que tenga asignados.
  final withCommands = onlyCustomView
      ? customFiltered
      : orderMenusForSelectedDefaultRoles(customFiltered, selection);

  final commandsOnly = normalizedActive.isNotEmpty &&
      normalizedActive.every(
        (role) => const {'COCINA', 'BARRA', 'COMANDAS'}.contains(role),
      );
  if (commandsOnly) {
    return personalizeAuthorizedMenu(withCommands
        .where((item) => item.keyName == 'comandas' || item.keyName == 'intelligence')
        .toList(growable: false), preferences);
  }

  // La personalización se aplica DESPUÉS de filtrar por rol.
  return personalizeAuthorizedMenu(withCommands, preferences);
});


/// Aplica posiciones guardadas por rol predefinido en cada vista.
/// El orden personal/favoritos del usuario sigue aplicándose posteriormente.
List<UserMenuItem> orderMenusForSelectedDefaultRoles(
    Iterable<UserMenuItem> items, Set<String>? selection) {
  final values = List<UserMenuItem>.of(items);
  if (selection == null || selection.isEmpty) return values;
  final selectedIds = selection.map(systemRoleIdFromSelection)
      .whereType<int>().toSet();
  if (selectedIds.isEmpty) return values;
  int? position(UserMenuItem item) {
    final positions = [
      for (final id in selectedIds)
        if (item.defaultOrderByRole[id] != null) item.defaultOrderByRole[id]!,
    ];
    if (positions.isEmpty) return null;
    positions.sort();
    return positions.first;
  }
  if (!values.any((item) => position(item) != null)) return values;
  final indices = <UserMenuItem, int>{
    for (var i = 0; i < values.length; i++) values[i]: i,
  };
  values.sort((a, b) {
    final byRole = (position(a) ?? 0x7fffffff)
        .compareTo(position(b) ?? 0x7fffffff);
    if (byRole != 0) return byRole;
    return indices[a]!.compareTo(indices[b]!);
  });
  return values;
}

/// Respeta la secuencia guardada en OPCIONMENU para cada rol personalizado.
/// El menú 'home' no se inserta ni se reordena artificialmente.
List<UserMenuItem> orderMenusForCustomRole(
    Iterable<UserMenuItem> items, {int? roleId}) {
  final ordered = List<UserMenuItem>.of(items);
  int position(UserMenuItem item) => roleId == null
      ? item.customOrder ?? 0x7fffffff
      : item.customOrderByRole[roleId] ?? 0x7fffffff;
  ordered.sort((a, b) {
    final byConfiguredOrder = position(a).compareTo(position(b));
    if (byConfiguredOrder != 0) return byConfiguredOrder;
    return a.menuOrder.compareTo(b.menuOrder);
  });
  return ordered;
}


/// Selecciona permisos de un rol PERSONALIZADO por ID, nunca por nombre ni
/// por su categoría genérica. Permite varios roles propios simultáneos sin
/// filtrar los módulos de otro rol personalizado de la misma empresa.
List<UserMenuItem> filterMenusBySelectedRoles(
    Iterable<UserMenuItem> items, Set<String>? selected) {
  if (selected == null) return items.toList(growable: false);
  final customIds = selected.map(customRoleIdFromSelection)
      .whereType<int>().toSet();
  final systemIds = selected.map(systemRoleIdFromSelection)
      .whereType<int>().toSet();
  // Compatibilidad con valores de selección anteriores al despliegue.
  final legacyNames = selected.where((key) =>
      customRoleIdFromSelection(key) == null &&
      systemRoleIdFromSelection(key) == null).toList();
  final legacyCustom = customIds.isEmpty && legacyNames.any(
      (key) => normalizeRoleName(key) == 'PERSONALIZADO');
  return items.where((item) =>
      item.roleIds.any(customIds.contains) ||
      item.roleIds.any(systemIds.contains) ||
      item.roles.any((role) => roleMatches(role, legacyNames)) ||
      (legacyCustom && item.roleTypes.any(
          (type) => normalizeRoleName(type) == 'PERSONALIZADO'))
  ).toList(growable: false);
}
