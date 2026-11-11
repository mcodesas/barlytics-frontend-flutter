import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../navigation/presentation/providers/menu_preferences_provider.dart';
import '../../../mesero/presentation/providers/mesero_tab_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../admin_support/presentation/pages/admin_home_page.dart';
import 'manager_home_page.dart';
import 'role_home_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final menuAsync = ref.watch(userMenuProvider);
    final activeRoles = ref.watch(activeRolesProvider);
    final isGlobalAdmin = activeRoles.any(_isGlobalAdminRole);
    final hasPersonalizedRole = activeRoles.any(_isPersonalizedRole);
    final isManager = !isGlobalAdmin &&
        !hasPersonalizedRole &&
        activeRoles.any(_isManagerRole);

    return AppScaffold(
      child: menuAsync.when(
        loading: () => Scaffold(
          backgroundColor: Colors.transparent,
          body: AppLoader(
            message: isGlobalAdmin
                ? 'Preparando centro de soporte global...'
                : isManager
                    ? 'Preparando centro de gerencia...'
                    : 'Preparando tu espacio de trabajo...',
          ),
        ),
        error: (error, _) => Scaffold(
          backgroundColor: Colors.transparent,
          body: AppErrorView(
            message: 'No fue posible cargar las funciones autorizadas para tu rol.',
            onRetry: () => ref.invalidate(userMenuProvider),
          ),
        ),
        data: (items) {
          final preferences = ref.watch(menuPreferencesProvider).valueOrNull ??
              const MenuPreferences();
          final favorites = preferences.showOnHome
              ? items.where((item) => item.isFavorite &&
                  item.path != '/home' && item.path.isNotEmpty)
                  .take(6).toList()
              : <UserMenuItem>[];
          final Widget content;
          if (isGlobalAdmin) {
            content = AdminHomePage(
              items: _sortAdminItems(items),
              rolesCount: activeRoles.length,
            );
          } else if (isManager) {
            content = ManagerHomePage(
              items: _sortManagerItems(items),
              rolesCount: activeRoles.length,
            );
          } else {
            content = RoleHomePage(items: items, roles: activeRoles);
          }
          if (favorites.isEmpty) return content;
          return Column(children: [
            _PersonalFavoritesHomeBar(items: favorites),
            Expanded(child: content),
          ]);
        },
      ),
    );
  }
}



class _PersonalFavoritesHomeBar extends ConsumerWidget {
  const _PersonalFavoritesHomeBar({required this.items});
  final List<UserMenuItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, size: 21,
              color: Color(0xFFE0A12A)),
          const SizedBox(width: 7),
          Expanded(child: Text('Mis accesos favoritos',
            style: TextStyle(color: palette.textPrimary,
              fontWeight: FontWeight.w900))),
          TextButton.icon(
            onPressed: () => context.go('/personalizar_menu'),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Editar')),
        ]),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: MediaQuery.sizeOf(context).width < 450 ? 146 : 180,
                child: Material(
                  color: palette.secondary.withOpacity(.09),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(color: palette.cardBorder)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () {
                      selectMeseroModeForMenuPath(ref, item.path);
                      context.go(item.path);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Icon(Icons.star_rounded, size: 17,
                          color: palette.secondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: 12))),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

bool _isPersonalizedRole(String role) {
  final normalized = _normalizeRole(role).replaceFirst(RegExp(r'^ROLE_'), '');
  return normalized == 'PERSONALIZADO';
}

bool _isGlobalAdminRole(String role) {
  final normalized = _normalizeRole(role).replaceFirst(RegExp(r'^ROLE_'), '');
  return normalized == 'ADMIN' ||
      normalized == 'ADMINISTRADOR' ||
      normalized == 'ADMIN_Y_SOPORTE' ||
      normalized == 'SUPERADMIN' ||
      normalized == 'SUPER_ADMIN';
}

List<UserMenuItem> _sortAdminItems(List<UserMenuItem> items) {
  const priority = <String, int>{
    'roles': 0,
    'roles_personalizados': 1,
    'usuarios': 2,
    'menus': 3,
    'opciones_menu': 4,
    'soporte_global': 5,
    'centro_errores': 6,
    'diagnostico_sistema': 7,
    'explorador_datos': 8,
    'auditoria_soporte': 9,
    'empresas': 10,
    'sucursales': 11,
    'ventas': 12,
    'pagos': 13,
    'inventario': 14,
    'movimientos': 15,
    'parametros': 16,
  };
  final sorted = List<UserMenuItem>.of(items);
  final hasRoleOrder = items.any((item) => item.defaultRoleOrder != null);
  final indices = <UserMenuItem, int>{
    for (var i = 0; i < items.length; i++) items[i]: i,
  };
  sorted.sort((a, b) {
    // Roles debe figurar primero en el inicio administrativo.
    if (a.keyName == 'roles' && b.keyName != 'roles') return -1;
    if (b.keyName == 'roles' && a.keyName != 'roles') return 1;
    // Para el resto, respetar la prioridad del rol o vista seleccionada.
    if (hasRoleOrder) return indices[a]!.compareTo(indices[b]!);
    final byPriority = (priority[a.keyName] ?? 999)
        .compareTo(priority[b.keyName] ?? 999);
    if (byPriority != 0) return byPriority;
    return a.title.compareTo(b.title);
  });
  return sorted;
}

bool _isManagerRole(String role) {
  final normalized = _normalizeRole(role);
  return normalized.contains('GERENTE') ||
      normalized.contains('MANAGER') ||
      normalized.contains('SUPERVISOR');
}

String _normalizeRole(String value) => value
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

List<UserMenuItem> _sortManagerItems(List<UserMenuItem> items) {
  const blocked = <String>{
    'planes_suscripcion',
    'soporte_global',
    'soporte_clientes',
    'soporte_accesos',
    'soporte_operacion',
    'soporte_configuracion',
    'soporte_mantenimiento',
    'explorador_datos',
    'auditoria_soporte',
    'diagnostico_sistema',
  };
  const priority = <String, int>{
    'reportes': 0,
    'ganancias': 1,
    'ventas': 2,
    'inventario': 3,
    'proximo_pedido': 4,
    'sincronizar_catalogo': 5,
    'productos': 6,
    'movimientos': 6,
    'precios': 7,
    'pagos': 8,
    'usuarios': 9,
    'roles_personalizados': 10,
    'sucursales': 11,
    'empresas': 12,
    'parametros': 13,
  };
  final sorted = items
      .where((item) => !blocked.contains(item.keyName.trim().toLowerCase()))
      .toList(growable: true);
  sorted.sort((a, b) {
    final byPriority =
        (priority[a.keyName] ?? 999).compareTo(priority[b.keyName] ?? 999);
    if (byPriority != 0) return byPriority;
    return a.title.compareTo(b.title);
  });
  return sorted;
}
