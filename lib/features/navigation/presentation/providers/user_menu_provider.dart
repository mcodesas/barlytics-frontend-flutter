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
  final filteredItems = activeRoles.length == authState.roles.length
      ? allItems
      : allItems.where((item) {
          if (item.roles.isEmpty) return true;
          return item.roles.any((role) =>
              roleMatches(role, activeRoles) ||
              (hasCustomRole && _isCustomRoleName(role)));
        }).toList(growable: false);

  final normalizedActive = activeRoles.map(normalizeRoleName).toSet();
  final canUseCommands = normalizedActive.any((role) => const {
        'MESERO',
        'MESERA',
        'CAJERO',
        'CAJERA',
        'VENDEDOR',
        'VENDEDORA',
        'VENTAS',
        'SELLER',
        'GERENTE',
        'MANAGER',
        'SUPERVISOR',
        'COCINA',
        'BARRA',
        'COMANDAS',
        'ADMIN',
        'ADMINISTRADOR',
        'SUPERADMIN',
        'SUPER_ADMIN',
      }.contains(role));

  final withCommands = canUseCommands &&
          !filteredItems.any((item) => item.keyName == 'comandas')
      ? <UserMenuItem>[
          ...filteredItems,
          const UserMenuItem(
            keyName: 'comandas',
            title: 'Comandas',
            path: '/comandas',
            description: 'Pedidos pendientes de Cocina y Barra',
            groupCode: 'OPERACION',
            groupName: 'Operación',
            groupIcon: 'room_service',
            groupOrder: 2,
            menuOrder: 4,
            bottomCode: 'COMANDAS',
            bottomName: 'Comandas',
            bottomIcon: 'room_service',
            bottomOrder: 4,
            bottomVisible: true,
            system: true,
          ),
        ]
      : filteredItems;

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


// El backend devuelve el nombre real del rol personalizado, mientras que
// la selección de la vista utiliza la categoría PERSONALIZADO.
// La lista ya fue autorizada por /auth/me/menus en el backend.
bool _isCustomRoleName(String name) {
  final normalized = normalizeRoleName(name);
  if (normalized.isEmpty) return false;
  const standardRoles = <String>{
    'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN',
    'GERENTE', 'MANAGER', 'SUPERVISOR',
    'CAJERO', 'CAJERA', 'MESERO', 'MESERA',
    'VENDEDOR', 'VENDEDORA', 'VENTAS', 'SELLER',
    'INVENTARIO', 'INVENTORY', 'BODEGA', 'ALMACEN',
    'MOVIMIENTOS', 'MOVIMIENTO', 'COCINA', 'BARRA',
    'COMANDAS', 'PERSONALIZADO',
  };
  return !standardRoles.contains(normalized);
}
