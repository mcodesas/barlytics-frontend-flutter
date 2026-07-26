import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import 'manager_home_page.dart';
import 'role_home_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final menuAsync = ref.watch(userMenuProvider);
    final isManager = authState.roles.any(_isManagerRole);

    return AppScaffold(
      child: menuAsync.when(
        loading: () => Scaffold(
          backgroundColor: Colors.transparent,
          body: AppLoader(
            message: isManager
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
          if (isManager) {
            return ManagerHomePage(
              items: _sortManagerItems(items),
              rolesCount: authState.roles.length,
            );
          }

          return RoleHomePage(
            items: items,
            roles: authState.roles,
          );
        },
      ),
    );
  }
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
  const priority = <String, int>{
    'reportes': 0,
    'ganancias': 1,
    'ventas': 2,
    'inventario': 3,
    'proximo_pedido': 4,
    'productos': 5,
    'movimientos': 6,
    'precios': 7,
    'pagos': 8,
    'usuarios': 9,
    'roles_personalizados': 10,
    'sucursales': 11,
    'empresas': 12,
    'parametros': 13,
  };
  final sorted = List<UserMenuItem>.of(items);
  sorted.sort((a, b) {
    final byPriority =
        (priority[a.keyName] ?? 999).compareTo(priority[b.keyName] ?? 999);
    if (byPriority != 0) return byPriority;
    return a.title.compareTo(b.title);
  });
  return sorted;
}
