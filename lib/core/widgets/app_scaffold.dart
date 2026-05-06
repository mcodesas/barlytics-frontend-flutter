import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/module_visuals.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/navigation/data/models/user_menu_item.dart';
import '../../features/navigation/presentation/providers/user_menu_provider.dart';
import '../utils/responsive_utils.dart';

/// Controlador compartido para conservar la posición del menú lateral.
///
/// GoRouter reconstruye el AppScaffold al cambiar de módulo; por eso la lista
/// del menú perdía su offset y volvía al inicio. Estos controladores viven
/// durante toda la sesión de la aplicación y permiten que el usuario mantenga
/// el menú exactamente donde lo dejó.
final ScrollController _desktopNavigationScrollController = ScrollController();
final ScrollController _mobileNavigationScrollController = ScrollController();

/// Scaffold principal con navegación adaptable.
///
/// Las opciones del menú ya no están quemadas: se consultan al backend desde
/// MENUS, OPCIONMENU y ROLES, usando los roles devueltos por el login. El
/// dispositivo solo cambia la presentación visual, no las funcionalidades.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _SideNavigation(onLogout: () => _logout(context, ref)),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarLytics'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEFF6FF), Color(0xFFFFF7ED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: Drawer(child: _DrawerContent(onLogout: () => _logout(context, ref))),
      body: child,
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(userMenuProvider);
    if (context.mounted) context.go('/login');
  }
}

class _SideNavigation extends ConsumerWidget {
  const _SideNavigation({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);

    return Container(
      width: 304,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF1E3A8A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _BrandHeader(dark: true),
            Expanded(
              child: ListView(
                key: const PageStorageKey<String>('desktop-main-navigation-scroll'),
                controller: _desktopNavigationScrollController,
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  _NavTile(title: 'Inicio', keyName: 'home', path: '/home', dark: true),
                  const SizedBox(height: 8),
                  const _NavSectionLabel('Opciones autorizadas'),
                  ..._authorizedMenuWidgets(
                    context: context,
                    ref: ref,
                    menuAsync: menuAsync,
                    dark: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _LogoutTile(onLogout: onLogout, dark: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerContent extends ConsumerWidget {
  const _DrawerContent({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);

    return Column(
      children: [
        const _BrandHeader(dark: false),
        Expanded(
          child: ListView(
            key: const PageStorageKey<String>('mobile-main-navigation-scroll'),
            controller: _mobileNavigationScrollController,
            primary: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _NavTile(title: 'Inicio', keyName: 'home', path: '/home'),
              const Divider(),
              ..._authorizedMenuWidgets(
                context: context,
                ref: ref,
                menuAsync: menuAsync,
                dark: false,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _LogoutTile(onLogout: onLogout),
        ),
      ],
    );
  }
}

List<Widget> _authorizedMenuWidgets({
  required BuildContext context,
  required WidgetRef ref,
  required AsyncValue<List<UserMenuItem>> menuAsync,
  required bool dark,
}) {
  return menuAsync.when(
    loading: () => [
      _MenuMessage(
        dark: dark,
        icon: Icons.hourglass_top_rounded,
        title: 'Cargando menú...',
        message: 'Consultando opciones según tu rol.',
      ),
    ],
    error: (error, _) => [
      _MenuMessage(
        dark: dark,
        icon: Icons.warning_amber_rounded,
        title: 'No se pudo cargar el menú',
        message: 'Revisa que existan roles, menús y opciones asignadas.',
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: dark ? Colors.white : AppColors.primary,
            side: BorderSide(color: dark ? Colors.white54 : AppColors.primary.withOpacity(0.35)),
          ),
          onPressed: () => ref.invalidate(userMenuProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ),
    ],
    data: (items) {
      if (items.isEmpty) {
        return [
          _MenuMessage(
            dark: dark,
            icon: Icons.lock_outline_rounded,
            title: 'Sin opciones asignadas',
            message: 'Tu rol aún no tiene opciones de menú configuradas.',
          ),
        ];
      }

      return [
        for (final item in items)
          _NavTile(
            title: item.title,
            keyName: item.keyName,
            path: item.path,
            dark: dark,
          ),
      ];
    },
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.10) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: dark ? Colors.white.withOpacity(0.12) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent, AppColors.tertiary]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_bar_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BarLytics',
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestión para bares',
                    style: TextStyle(color: dark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _NavSectionLabel extends StatelessWidget {
  const _NavSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 11),
        ),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.title, required this.keyName, required this.path, this.dark = false});

  final String title;
  final String keyName;
  final String path;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(keyName);
    final pathNow = _currentPath(context);
    final selected = pathNow == path || (path != '/home' && pathNow.startsWith('$path/'));
    final foreground = dark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? (dark ? Colors.white.withOpacity(0.16) : visual.color.withOpacity(0.10)) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final router = GoRouter.of(context);
            final shouldCloseDrawer = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;

            // En móvil el menú vive dentro de un Drawer. Primero lo cerramos y
            // luego navegamos, manteniendo el offset del ScrollController.
            if (shouldCloseDrawer) {
              Navigator.of(context).pop();
            }

            router.go(path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(0.14) : visual.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(visual.icon, size: 20, color: dark ? Colors.white : visual.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
                  ),
                ),
                if (selected) Icon(Icons.circle, color: dark ? AppColors.accent : visual.color, size: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _currentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '';
    }
  }
}

class _MenuMessage extends StatelessWidget {
  const _MenuMessage({
    required this.dark,
    required this.icon,
    required this.title,
    required this.message,
  });

  final bool dark;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.10) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: dark ? Colors.white24 : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: dark ? Colors.white70 : AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: dark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: dark ? Colors.white70 : AppColors.textSecondary, fontSize: 12, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onLogout, this.dark = false});
  final VoidCallback onLogout;
  final bool dark;

  @override
  Widget build(BuildContext context) => Material(
        color: dark ? Colors.white.withOpacity(0.10) : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Icon(Icons.logout_rounded, color: dark ? Colors.white : AppColors.danger),
          title: Text('Cerrar sesión', style: TextStyle(color: dark ? Colors.white : AppColors.danger, fontWeight: FontWeight.w900)),
          onTap: onLogout,
        ),
      );
}
