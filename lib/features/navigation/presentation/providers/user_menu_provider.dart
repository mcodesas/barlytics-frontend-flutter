import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_menu_item.dart';
import '../../data/repositories/user_menu_repository.dart';
import 'active_role_provider.dart';
import 'user_assigned_roles_provider.dart';

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
  final predefinedSelections = selection
          ?.where((key) => customRoleIdFromSelection(key) == null).toList() ??
      <String>[];
  final legacyCustomSelection = predefinedSelections.any(
      (key) => normalizeRoleName(key) == 'PERSONALIZADO');
  final onlyCustomView = hasCustomRole && activeRoles.length == 1 &&
      (selection == null || (selection.length == 1 &&
          (customIds.length == 1 || legacyCustomSelection)));

  final allItems = await ref.watch(userMenuRepositoryProvider).findMyMenu(
        preserveBackendOrder: onlyCustomView,
      );
  // En roles personalizados usar IDs de commerce.roles, no el tipo genérico
  // PERSONALIZADO. Seleccionar uno NO debe filtrar menús de otros roles custom.
  final filteredItems = selection == null
      ? allItems
      : allItems.where((item) {
          final byCustomId = item.roleIds.any(customIds.contains);
          final byPredefined = item.roles.any(
              (name) => roleMatches(name, predefinedSelections));
          final byLegacyCustomType = legacyCustomSelection &&
              customIds.isEmpty &&
              item.roleTypes.any((type) =>
                  normalizeRoleName(type) == 'PERSONALIZADO');
          return byCustomId || byPredefined || byLegacyCustomType;
        }).toList(growable: false);

  final customFiltered = onlyCustomView
      ? orderMenusForCustomRole(filteredItems,
          roleId: customIds.length == 1 ? customIds.first : null)
      : filteredItems;

  final normalizedActive = activeRoles.map(normalizeRoleName).toSet();
  final withCommands = customFiltered;

  final commandsOnly = normalizedActive.isNotEmpty &&
      normalizedActive.every(
        (role) => const {'COCINA', 'BARRA', 'COMANDAS'}.contains(role),
      );
  if (commandsOnly) {
    return withCommands
        .where((item) => item.keyName == 'comandas')
        .toList(growable: false);
  }

  // Los nombres y destinos se toman exclusivamente de commerce.menus.
  return withCommands;
});


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
