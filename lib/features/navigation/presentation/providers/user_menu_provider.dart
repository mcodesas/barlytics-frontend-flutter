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

  final operationalOnly = normalizedActive.isNotEmpty &&
      normalizedActive.every((role) => const {
            'INVENTARIO',
            'INVENTORY',
            'BODEGA',
            'ALMACEN',
            'MOVIMIENTOS',
            'MOVIMIENTO',
          }.contains(role));

  if (!operationalOnly) return withCommands;

  return withCommands.map((item) {
    if (item.keyName == 'inventario' &&
        normalizedActive.any((role) => const {
              'INVENTARIO',
              'INVENTORY',
              'BODEGA',
              'ALMACEN',
            }.contains(role))) {
      return item.copyWith(title: 'Tomar inventario');
    }
    if (item.keyName == 'productos' &&
        normalizedActive.any((role) => const {
              'MOVIMIENTOS',
              'MOVIMIENTO',
            }.contains(role))) {
      return item.copyWith(title: 'Registrar movimientos');
    }
    return item;
  }).toList(growable: false);
});
