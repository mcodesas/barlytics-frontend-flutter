import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_menu_item.dart';
import '../../data/repositories/user_menu_repository.dart';
import 'active_role_provider.dart';

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
  final allItems = await ref.watch(userMenuRepositoryProvider).findMyMenu(
        preserveBackendOrder: hasCustomRole && activeRoles.length == 1,
      );
  // El JWT usa la categoría PERSONALIZADO; el backend informa el nombre
  // real del rol y su categoría tomada de commerce.roles.role_tipo.
  // Filtrar por tipo solamente para PERSONALIZADO, nunca por coincidencias
  // aproximadas de nombres (pueden corresponder a roles distintos).
  final filteredItems = activeRoles.length == authState.roles.length
      ? allItems
      : allItems.where((item) {
          if (item.roles.isEmpty && item.roleTypes.isEmpty) return false;
          return item.roles.any((role) => roleMatches(role, activeRoles)) ||
              (hasCustomRole &&
                  item.roleTypes.any(
                    (type) => normalizeRoleName(type) == 'PERSONALIZADO',
                  ));
        }).toList(growable: false);

  final normalizedActive = activeRoles.map(normalizeRoleName).toSet();
  final withCommands = filteredItems;

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
