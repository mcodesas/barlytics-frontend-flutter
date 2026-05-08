import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/module_visuals.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/navigation/data/models/user_menu_item.dart';
import '../../features/navigation/presentation/providers/user_menu_provider.dart';
import '../utils/responsive_utils.dart';
import 'tech_background.dart';

final ScrollController _desktopNavigationScrollController = ScrollController();
final ScrollController _mobileNavigationScrollController = ScrollController();

/// Scaffold principal con navegación adaptable y diseño tecnológico unificado.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.softTechGradient),
          child: Row(
            children: [
              _SideNavigation(onLogout: () => _logout(context, ref)),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarLytics'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.techGradient),
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
      width: 312,
      decoration: const BoxDecoration(gradient: AppColors.techGradient),
      child: Stack(
        children: [
          const Positioned(top: -80, right: -90, child: GlowCircle(size: 240, opacity: 0.20)),
          const Positioned(bottom: -90, left: -120, child: GlowCircle(size: 300, opacity: 0.14)),
          SafeArea(
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
                      _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile', dark: true),
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
        ],
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

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.softTechGradient),
      child: Column(
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
                _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile'),
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
      ),
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
            foregroundColor: dark ? Colors.white : AppColors.secondaryDark,
            side: BorderSide(color: dark ? Colors.white54 : AppColors.secondary.withOpacity(0.35)),
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
          color: dark ? Colors.white.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: dark ? Colors.white.withOpacity(0.16) : AppColors.border),
          boxShadow: [
            if (!dark) BoxShadow(color: AppColors.secondary.withOpacity(0.10), blurRadius: 22, offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            const TechBrandMark(size: 56, icon: Icons.analytics_rounded),
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
                    'Gestión inteligente para bares',
                    style: TextStyle(color: dark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w700),
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
          style: TextStyle(color: Colors.white.withOpacity(0.58), fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 11),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? (dark ? Colors.white.withOpacity(0.15) : AppColors.secondary.withOpacity(0.10)) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final router = GoRouter.of(context);
            final shouldCloseDrawer = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
            if (shouldCloseDrawer) Navigator.of(context).pop();
            router.go(path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.bluePurpleGradient : null,
                    color: selected ? null : (dark ? Colors.white.withOpacity(0.12) : visual.color.withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: dark ? Colors.white.withOpacity(0.08) : Colors.transparent),
                  ),
                  child: Icon(visual.icon, size: 20, color: selected || dark ? Colors.white : visual.color),
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
                if (selected) Icon(Icons.circle, color: dark ? AppColors.accent : AppColors.secondary, size: 8),
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
          color: dark ? Colors.white.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dark ? Colors.white24 : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: dark ? AppColors.accent : AppColors.secondaryDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: dark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: dark ? Colors.white70 : AppColors.textSecondary, fontSize: 12, height: 1.25)),
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
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Icon(Icons.logout_rounded, color: dark ? Colors.white : AppColors.danger),
          title: Text('Cerrar sesión', style: TextStyle(color: dark ? Colors.white : AppColors.danger, fontWeight: FontWeight.w900)),
          onTap: onLogout,
        ),
      );
}
