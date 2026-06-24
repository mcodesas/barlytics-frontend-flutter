import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/module_visuals.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/mesero/presentation/providers/mesero_tab_provider.dart';
import '../../features/navigation/data/models/user_menu_item.dart';
import '../../features/navigation/presentation/providers/user_menu_provider.dart';
import '../utils/responsive_utils.dart';
import 'tech_background.dart';

final ScrollController _desktopNavigationScrollController = ScrollController();
final ScrollController _mobileNavigationScrollController = ScrollController();

bool _isInventoryRole(String role) {
  final normalized = role.toUpperCase();
  return normalized.contains('INVENTARIO') ||
      normalized.contains('INVENTORY') ||
      normalized.contains('BODEGA') ||
      normalized.contains('ALMACEN') ||
      normalized.contains('ALMACÉN');
}

bool _isMesaCashierSellerRole(String role) {
  final normalized = role.toUpperCase();
  return normalized.contains('MESER') ||
      normalized.contains('CAJER') ||
      normalized.contains('VENDEDOR') ||
      normalized.contains('VENTA') ||
      normalized.contains('SELLER');
}

bool _isOperationalRole(String role) => _isMesaCashierSellerRole(role) || _isInventoryRole(role);

/// Scaffold principal con navegación adaptable y diseño tecnológico unificado.
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _mainMenuCollapsed = true;
  bool _operationalMenuCollapsed = true;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final palette = ref.watch(selectedAppPaletteProvider);
    final roles = ref.watch(authControllerProvider).roles;
    final isOperativo = roles.any(_isOperationalRole);
    final isInventario = roles.any(_isInventoryRole);

    if (isOperativo) {
      return _MeseroScaffold(
        child: widget.child,
        onLogout: () => _logout(context),
        collapsed: _operationalMenuCollapsed,
        onToggleCollapsed: () => setState(() => _operationalMenuCollapsed = !_operationalMenuCollapsed),
        palette: palette,
        bottomMenuType: isInventario ? _OperationalBottomMenuType.inventory : _OperationalBottomMenuType.mesa,
      );
    }

    if (isDesktop) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: palette.softGradient),
          child: Row(
            children: [
              _SideNavigation(
                onLogout: () => _logout(context),
                collapsed: _mainMenuCollapsed,
                onToggleCollapsed: () => setState(() => _mainMenuCollapsed = !_mainMenuCollapsed),
                palette: palette,
              ),
              Expanded(child: _PaletteAwareBody(child: widget.child, palette: palette)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarLytics'),
        foregroundColor: palette.onTitle,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: palette.mainGradient)),
      ),
      drawer: Drawer(child: _DrawerContent(onLogout: () => _logout(context), palette: palette)),
      body: _PaletteAwareBody(child: widget.child, palette: palette),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(userMenuProvider);
    if (context.mounted) context.go('/login');
  }
}

class _PaletteAwareBody extends StatelessWidget {
  const _PaletteAwareBody({required this.child, required this.palette});

  final Widget child;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Stack(
      children: [
        const Positioned.fill(child: AppPageBackground()),
        Positioned.fill(
          child: Theme(
            data: baseTheme.copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              canvasColor: palette.background,
              cardColor: palette.surface,
              colorScheme: baseTheme.colorScheme.copyWith(
                primary: palette.secondary,
                secondary: palette.accent,
                surface: palette.surface,
                onSurface: palette.textPrimary,
                background: palette.background,
                onBackground: palette.textPrimary,
              ),
              appBarTheme: baseTheme.appBarTheme.copyWith(
                backgroundColor: palette.titleBackground,
                foregroundColor: palette.titleText,
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
                filled: true,
                fillColor: palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.96),
                labelStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                hintStyle: TextStyle(color: palette.textSecondary.withOpacity(0.78)),
              ),
              textTheme: baseTheme.textTheme.apply(
                bodyColor: palette.textPrimary,
                displayColor: palette.textPrimary,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.actionColor,
                  foregroundColor: palette.onAction,
                  disabledBackgroundColor: palette.textSecondary.withOpacity(0.28),
                  disabledForegroundColor: palette.textSecondary.withOpacity(0.70),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.secondary,
                  side: BorderSide(color: palette.secondary.withOpacity(0.42)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: palette.secondary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              chipTheme: baseTheme.chipTheme.copyWith(
                backgroundColor: palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.94),
                selectedColor: palette.secondary.withOpacity(0.16),
                labelStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                secondaryLabelStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                side: BorderSide(color: palette.cardBorder),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

enum _OperationalBottomMenuType { mesa, inventory }

class _MeseroScaffold extends StatelessWidget {
  const _MeseroScaffold({
    required this.child,
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.palette,
    required this.bottomMenuType,
  });

  final Widget child;
  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final AppPalette palette;
  final _OperationalBottomMenuType bottomMenuType;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: palette.softGradient),
          child: Row(
            children: [
              _MeseroSideNavigation(
                onLogout: onLogout,
                collapsed: collapsed,
                onToggleCollapsed: onToggleCollapsed,
                palette: palette,
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _PaletteAwareBody(child: child, palette: palette)),
                    _OperationalBottomNavigation(type: bottomMenuType),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarLytics Operación'),
        foregroundColor: palette.onTitle,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: palette.mainGradient)),
      ),
      drawer: Drawer(child: _MeseroDrawerContent(onLogout: onLogout, palette: palette)),
      body: _PaletteAwareBody(child: child, palette: palette),
      bottomNavigationBar: _OperationalBottomNavigation(type: bottomMenuType),
    );
  }
}

class _MeseroSideNavigation extends StatelessWidget {
  const _MeseroSideNavigation({
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.palette,
  });

  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: collapsed ? 92 : 280,
        decoration: BoxDecoration(gradient: palette.mainGradient),
        child: Stack(
          children: [
            Positioned(top: -70, right: -100, child: GlowCircle(size: 240, opacity: 0.18, color: palette.accent)),
            Positioned(bottom: -90, left: -120, child: GlowCircle(size: 280, opacity: 0.12, color: palette.secondary)),
            SafeArea(
              child: Column(
                children: [
                  _NavigationCollapseButton(collapsed: collapsed, onPressed: onToggleCollapsed, dark: true),
                  if (collapsed) const _CollapsedBrand() else const _BrandHeader(dark: true),
                  Expanded(
                    child: ListView(
                      primary: false,
                      padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
                      children: [
                        _NavTile(title: 'Inicio', keyName: 'home', path: '/home', dark: true, compact: collapsed, palette: palette),
                        _NavTile(title: 'Apariencia', keyName: 'parametros', path: '__appearance__', dark: true, compact: collapsed, palette: palette, onTap: () => showPaletteSettingsDialog(context)),
                        _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile', dark: true, compact: collapsed, palette: palette),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(collapsed ? 10 : 14),
                    child: _LogoutTile(onLogout: onLogout, dark: true, compact: collapsed),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MeseroDrawerContent extends StatelessWidget {
  const _MeseroDrawerContent({required this.onLogout, required this.palette});
  final VoidCallback onLogout;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: palette.softGradient),
        child: Column(
          children: [
            const _BrandHeader(dark: false),
            Expanded(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _NavTile(title: 'Inicio', keyName: 'home', path: '/home', palette: palette),
                  _NavTile(title: 'Apariencia', keyName: 'parametros', path: '__appearance__', palette: palette, onTap: () => showPaletteSettingsDialog(context)),
                  _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile', palette: palette),
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

class _OperationalBottomNavigation extends ConsumerWidget {
  const _OperationalBottomNavigation({required this.type});

  final _OperationalBottomMenuType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == _OperationalBottomMenuType.inventory) {
      return _InventoryBottomNavigation();
    }

    final rawSelectedMode = ref.watch(meseroSelectedModeProvider);
    final palette = ref.watch(selectedAppPaletteProvider);
    final roles = ref.watch(authControllerProvider).roles;
    final isCajero = roles.any((role) => role.toUpperCase().contains('CAJER'));
    final selectedMode = !isCajero && (rawSelectedMode == MeseroPageMode.historial || rawSelectedMode == MeseroPageMode.cierreCaja)
        ? MeseroPageMode.resumen
        : rawSelectedMode;

    if (selectedMode != rawSelectedMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(meseroSelectedModeProvider.notifier).state = selectedMode;
      });
    }

    final entries = <({MeseroPageMode mode, BottomNavigationBarItem item})>[
      (mode: MeseroPageMode.mesas, item: const BottomNavigationBarItem(icon: Icon(Icons.table_bar_rounded), label: 'Mesas')),
      (mode: MeseroPageMode.productos, item: const BottomNavigationBarItem(icon: Icon(Icons.liquor_rounded), label: 'Productos')),
      (mode: MeseroPageMode.resumen, item: const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Resumen')),
      if (isCajero) ...[
        (mode: MeseroPageMode.historial, item: const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Historial')),
        (mode: MeseroPageMode.cierreCaja, item: const BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Cierre caja')),
      ],
    ];

    final selectedIndex = entries.indexWhere((entry) => entry.mode == selectedMode);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
        border: Border(top: BorderSide(color: palette.cardBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: selectedIndex < 0 ? 0 : selectedIndex,
          selectedItemColor: palette.secondary,
          unselectedItemColor: palette.textSecondary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            final mode = entries[index].mode;
            ref.read(meseroSelectedModeProvider.notifier).state = mode;
            final currentPath = GoRouterState.of(context).uri.path;
            if (!currentPath.startsWith('/mesero')) {
              context.go('/mesero');
            }
          },
          items: [for (final entry in entries) entry.item],
        ),
      ),
    );
  }
}


class _InventoryBottomNavigation extends ConsumerWidget {
  const _InventoryBottomNavigation();

  static const _items = <({String label, IconData icon, String path})>[
    (label: 'Productos', icon: Icons.inventory_2_rounded, path: '/productos'),
    (label: 'Inventario', icon: Icons.fact_check_rounded, path: '/inventario'),
    (label: 'Precios', icon: Icons.price_change_rounded, path: '/precios'),
    (label: 'Tipos', icon: Icons.category_rounded, path: '/tipos_producto'),
    (label: 'Marcas', icon: Icons.sell_rounded, path: '/marcas'),
    (label: 'Movimientos', icon: Icons.sync_alt_rounded, path: '/movimientos'),
    (label: 'Pagos', icon: Icons.payments_rounded, path: '/medios_pago'),
    (label: 'Reportes', icon: Icons.analytics_rounded, path: '/reportes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    var selectedIndex = _items.indexWhere((item) => currentPath == item.path || currentPath.startsWith('${item.path}/'));
    if (selectedIndex < 0) selectedIndex = 0;

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 640;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
        border: Border(top: BorderSide(color: palette.cardBorder.withOpacity(0.70))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.24 : 0.11),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: palette.secondary,
          unselectedItemColor: palette.textSecondary.withOpacity(0.86),
          selectedFontSize: isCompact ? 10.5 : 12,
          unselectedFontSize: isCompact ? 10 : 11.5,
          iconSize: isCompact ? 22 : 24,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) => context.go(_items[index].path),
          items: [
            for (final item in _items)
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Icon(item.icon),
                ),
                activeIcon: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(palette.darkBackground ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.secondary.withOpacity(0.28)),
                  ),
                  child: Icon(item.icon),
                ),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _SideNavigation extends ConsumerWidget {
  const _SideNavigation({
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.palette,
  });

  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: collapsed ? 92 : 312,
      decoration: BoxDecoration(gradient: palette.mainGradient),
      child: Stack(
        children: [
          Positioned(top: -80, right: -90, child: GlowCircle(size: 240, opacity: 0.20, color: palette.accent)),
          Positioned(bottom: -90, left: -120, child: GlowCircle(size: 300, opacity: 0.14, color: palette.secondary)),
          SafeArea(
            child: Column(
              children: [
                _NavigationCollapseButton(collapsed: collapsed, onPressed: onToggleCollapsed, dark: true),
                if (collapsed) const _CollapsedBrand() else const _BrandHeader(dark: true),
                Expanded(
                  child: ListView(
                    key: const PageStorageKey<String>('desktop-main-navigation-scroll'),
                    controller: _desktopNavigationScrollController,
                    primary: false,
                    padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
                    children: [
                      _NavTile(title: 'Inicio', keyName: 'home', path: '/home', dark: true, compact: collapsed, palette: palette),
                      _NavTile(title: 'Apariencia', keyName: 'parametros', path: '__appearance__', dark: true, compact: collapsed, palette: palette, onTap: () => showPaletteSettingsDialog(context)),
                      _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile', dark: true, compact: collapsed, palette: palette),
                      if (!collapsed) ...[
                        const SizedBox(height: 8),
                        const _NavSectionLabel('Opciones autorizadas'),
                      ],
                      ..._authorizedMenuWidgets(
                        context: context,
                        ref: ref,
                        menuAsync: menuAsync,
                        dark: true,
                        compact: collapsed,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(collapsed ? 10 : 14),
                  child: _LogoutTile(onLogout: onLogout, dark: true, compact: collapsed),
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
  const _DrawerContent({required this.onLogout, required this.palette});
  final VoidCallback onLogout;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);

    return Container(
      decoration: BoxDecoration(gradient: palette.softGradient),
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
                _NavTile(title: 'Inicio', keyName: 'home', path: '/home', palette: palette),
                _NavTile(title: 'Apariencia', keyName: 'parametros', path: '__appearance__', palette: palette, onTap: () => showPaletteSettingsDialog(context)),
                _NavTile(title: 'Mi perfil', keyName: 'usuarios', path: '/profile', palette: palette),
                const Divider(),
                ..._authorizedMenuWidgets(
                  context: context,
                  ref: ref,
                  menuAsync: menuAsync,
                  dark: false,
                  compact: false,
                  palette: palette,
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
  required bool compact,
  required AppPalette palette,
}) {
  return menuAsync.when(
    loading: () => compact
        ? [const SizedBox.shrink()]
        : [
            _MenuMessage(
              dark: dark,
              icon: Icons.hourglass_top_rounded,
              title: 'Cargando menú...',
              message: 'Consultando opciones según tu rol.',
            ),
          ],
    error: (error, _) => compact
        ? [
            Tooltip(
              message: 'Reintentar cargar menú',
              child: IconButton.filledTonal(
                onPressed: () => ref.invalidate(userMenuProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ]
        : [
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
                  foregroundColor: dark ? Colors.white : palette.secondary,
                  side: BorderSide(color: dark ? Colors.white54 : palette.secondary.withOpacity(0.35)),
                ),
                onPressed: () => ref.invalidate(userMenuProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ),
          ],
    data: (items) {
      if (items.isEmpty) {
        return compact
            ? [const SizedBox.shrink()]
            : [
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
            compact: compact,
            palette: palette,
          ),
      ];
    },
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final palette = ref.watch(selectedAppPaletteProvider);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth.isFinite && constraints.maxWidth < 170;
            if (compact) {
              return const _CollapsedBrand();
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? Colors.white.withOpacity(0.10) : palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.96),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: dark ? Colors.white.withOpacity(0.18) : palette.cardBorder),
                boxShadow: [
                  BoxShadow(color: palette.cardShadow, blurRadius: 26, offset: const Offset(0, 14)),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dark ? Colors.white : palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestión inteligente para bares',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: dark ? Colors.white70 : palette.textSecondary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CollapsedBrand extends StatelessWidget {
  const _CollapsedBrand();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 14),
        child: TechBrandMark(size: 48, icon: Icons.analytics_rounded),
      );
}

class _NavigationCollapseButton extends StatelessWidget {
  const _NavigationCollapseButton({
    required this.collapsed,
    required this.onPressed,
    required this.dark,
  });

  final bool collapsed;
  final VoidCallback onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) => Align(
        alignment: collapsed ? Alignment.center : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Tooltip(
            message: collapsed ? 'Abrir menú' : 'Encoger menú',
            child: IconButton.filledTonal(
              onPressed: onPressed,
              icon: Icon(collapsed ? Icons.menu_open_rounded : Icons.menu_rounded),
              color: dark ? Colors.white : AppColors.secondaryDark,
              style: IconButton.styleFrom(
                backgroundColor: dark ? Colors.white.withOpacity(0.12) : Colors.white,
              ),
            ),
          ),
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
  const _NavTile({
    required this.title,
    required this.keyName,
    required this.path,
    this.dark = false,
    this.compact = false,
    this.palette,
    this.onTap,
  });

  final String title;
  final String keyName;
  final String path;
  final bool dark;
  final bool compact;
  final AppPalette? palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(keyName);
    final appPalette = palette ?? appPalettes.first;
    final pathNow = _currentPath(context);
    final selected = pathNow == path || (path != '/home' && pathNow.startsWith('$path/'));
    final foreground = dark ? Colors.white : appPalette.textPrimary;

    Widget iconBox({required bool small}) => Container(
          width: small ? 36 : 38,
          height: small ? 36 : 38,
          decoration: BoxDecoration(
            gradient: selected ? appPalette.mainGradient : null,
            color: selected ? null : (dark ? Colors.white.withOpacity(0.12) : appPalette.secondary.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: dark ? Colors.white.withOpacity(0.08) : Colors.transparent),
          ),
          child: Icon(visual.icon, size: small ? 19 : 20, color: selected || dark ? Colors.white : appPalette.secondary),
        );

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? (dark ? Colors.white.withOpacity(0.15) : appPalette.secondary.withOpacity(0.10)) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final router = GoRouter.of(context);
            final shouldCloseDrawer = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
            if (shouldCloseDrawer) Navigator.of(context).pop();
            if (onTap != null) {
              onTap!();
              return;
            }
            router.go(path);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final effectiveCompact = compact || (constraints.maxWidth.isFinite && constraints.maxWidth < 110);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: effectiveCompact ? 6 : 12, vertical: 10),
                child: effectiveCompact
                    ? Center(child: iconBox(small: true))
                    : Row(
                        children: [
                          iconBox(small: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: foreground, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
                            ),
                          ),
                          if (selected) Icon(Icons.circle, color: dark ? appPalette.accent : appPalette.secondary, size: 8),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );

    return compact ? Tooltip(message: title, child: tile) : tile;
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
  const _LogoutTile({required this.onLogout, this.dark = false, this.compact = false});
  final VoidCallback onLogout;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveCompact = compact || (constraints.maxWidth.isFinite && constraints.maxWidth < 118);
        final content = Material(
          color: dark ? Colors.white.withOpacity(0.10) : AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onLogout,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: effectiveCompact ? 10 : 16, vertical: 12),
              child: effectiveCompact
                  ? Center(child: Icon(Icons.logout_rounded, color: dark ? Colors.white : AppColors.danger, size: 22))
                  : Row(
                      children: [
                        Icon(Icons.logout_rounded, color: dark ? Colors.white : AppColors.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cerrar sesión',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: dark ? Colors.white : AppColors.danger, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );

        return effectiveCompact ? Tooltip(message: 'Cerrar sesión', child: content) : content;
      },
    );
  }
}
