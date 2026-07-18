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

/// Controla la visibilidad del menú lateral operativo en escritorio.
final operationalMenuOpenProvider = StateProvider<bool>((ref) => false);

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

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final palette = ref.watch(selectedAppPaletteProvider);
    final roles = ref.watch(authControllerProvider).roles;
    final isOperativo = roles.any(_isOperationalRole);
    final isInventario = roles.any(_isInventoryRole);
    final operationalMenuOpen = ref.watch(operationalMenuOpenProvider);
    final pageTitle = _resolveCurrentPageTitle(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
    );
    final pageSubtitle = _resolveCurrentPageSubtitle(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
    );
    final pageEyebrow = _resolveCurrentPageEyebrow(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
    );
    final pageStatusText = _resolveCurrentPageStatusText(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
    );
    final pageIcon = _resolveCurrentPageIcon(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
    );

    if (isOperativo) {
      return _MeseroScaffold(
        child: widget.child,
        onLogout: () => _logout(context),
        collapsed: !operationalMenuOpen,
        onToggleCollapsed: () {
          ref.read(operationalMenuOpenProvider.notifier).state = !operationalMenuOpen;
        },
        palette: palette,
        pageTitle: pageTitle,
        pageSubtitle: pageSubtitle,
        pageEyebrow: pageEyebrow,
        pageStatusText: pageStatusText,
        pageIcon: pageIcon,
        bottomMenuType: isInventario ? _OperationalBottomMenuType.inventory : _OperationalBottomMenuType.mesa,
      );
    }

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    _PageTopBar(
                      title: pageTitle,
                      subtitle: pageSubtitle,
                      eyebrow: pageEyebrow,
                      statusText: pageStatusText,
                      leadingContentIcon: pageIcon,
                      palette: palette,
                      menuOpen: !_mainMenuCollapsed,
                      onMenuPressed: () => setState(() => _mainMenuCollapsed = !_mainMenuCollapsed),
                    ),
                    Expanded(child: _PaletteAwareBody(child: widget.child, palette: palette)),
                  ],
                ),
              ),
              if (!_mainMenuCollapsed) ...[
                Positioned(
                  top: _PageTopBar.height,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _mainMenuCollapsed = true),
                    child: ColoredBox(color: Colors.black.withOpacity(0.30)),
                  ),
                ),
                Positioned(
                  top: _PageTopBar.height,
                  left: 0,
                  bottom: 0,
                  child: _SideNavigation(
                    onLogout: () => _logout(context),
                    collapsed: false,
                    onToggleCollapsed: () => setState(() => _mainMenuCollapsed = true),
                    palette: palette,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(child: _DrawerContent(onLogout: () => _logout(context), palette: palette)),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (scaffoldContext) => _PageTopBar(
                title: pageTitle,
                subtitle: pageSubtitle,
                eyebrow: pageEyebrow,
                statusText: pageStatusText,
                leadingContentIcon: pageIcon,
                palette: palette,
                menuOpen: false,
                onMenuPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              ),
            ),
            Expanded(child: _PaletteAwareBody(child: widget.child, palette: palette)),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(userMenuProvider);
    if (context.mounted) context.go('/login');
  }
}

String _resolveCurrentPageTitle(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
}) {
  final path = GoRouterState.of(context).uri.path;

  if (isOperativo && !isInventario && path.startsWith('/mesero')) {
    final mode = ref.watch(meseroSelectedModeProvider);
    return switch (mode) {
      MeseroPageMode.mesas => 'Mesas y caja',
      MeseroPageMode.productos => 'Productos',
      MeseroPageMode.resumen => 'Resumen del salón',
      MeseroPageMode.historial => 'Historial de ventas',
      MeseroPageMode.cierreCaja => 'Cierre de caja',
    };
  }

  const routeTitles = <String, String>{
    '/home': 'Inicio',
    '/profile': 'Mi perfil',
    '/reportes': 'Reportes',
    '/productos': 'Productos',
    '/inventario': 'Inventario',
    '/precios': 'Precios',
    '/tipos_producto': 'Tipos de producto',
    '/marcas': 'Marcas',
    '/movimientos': 'Movimientos',
    '/medios_pago': 'Medios de pago',
    '/usuarios': 'Usuarios',
    '/roles': 'Roles',
    '/empresas': 'Empresas',
    '/sucursales': 'Sucursales',
    '/ventas': 'Ventas',
    '/regiones': 'Regiones',
    '/zonas_horarias': 'Zonas horarias',
  };

  String? bestStaticTitle;
  var bestStaticLength = -1;
  for (final entry in routeTitles.entries) {
    if ((path == entry.key || path.startsWith('${entry.key}/')) && entry.key.length > bestStaticLength) {
      bestStaticTitle = entry.value;
      bestStaticLength = entry.key.length;
    }
  }
  if (bestStaticTitle != null) return bestStaticTitle;

  final authorizedItems = ref.watch(userMenuProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <UserMenuItem>[],
      );
  UserMenuItem? bestItem;
  for (final item in authorizedItems) {
    if (path == item.path || path.startsWith('${item.path}/')) {
      if (bestItem == null || item.path.length > bestItem.path.length) bestItem = item;
    }
  }
  if (bestItem != null && bestItem.title.trim().isNotEmpty) return bestItem.title.trim();

  final segments = path.split('/').where((part) => part.isNotEmpty).toList(growable: false);
  if (segments.isEmpty) return 'Inicio';
  final firstSegment = segments.first;
  return firstSegment
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String? _resolveCurrentPageSubtitle(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
}) {
  final path = GoRouterState.of(context).uri.path;
  if (isOperativo && !isInventario && path.startsWith('/mesero')) {
    final mode = ref.watch(meseroSelectedModeProvider);
    return switch (mode) {
      MeseroPageMode.mesas => 'Consulta el salón, continúa ventas y registra pagos rápidamente.',
      MeseroPageMode.productos => 'Consulta bebidas y productos disponibles para la venta.',
      MeseroPageMode.resumen => 'Revisa ventas abiertas, mesas disponibles y saldos pendientes.',
      MeseroPageMode.historial => 'Consulta ventas cerradas, productos y pagos registrados.',
      MeseroPageMode.cierreCaja => 'Cuadra las ventas y medios de pago del turno actual.',
    };
  }
  if (isInventario) return 'Gestiona inventario, movimientos y trazabilidad del stock.';
  return null;
}

String? _resolveCurrentPageEyebrow(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
}) {
  final path = GoRouterState.of(context).uri.path;
  if (isOperativo && !isInventario && path.startsWith('/mesero')) {
    final mode = ref.watch(meseroSelectedModeProvider);
    return switch (mode) {
      MeseroPageMode.mesas => 'Operación principal',
      MeseroPageMode.productos => 'Catálogo activo',
      MeseroPageMode.resumen => 'Vista general',
      MeseroPageMode.historial => 'Trazabilidad',
      MeseroPageMode.cierreCaja => 'Control del turno',
    };
  }
  if (isInventario) return 'Operación de inventario';
  return null;
}

String? _resolveCurrentPageStatusText(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
}) {
  final path = GoRouterState.of(context).uri.path;
  if (isOperativo && path.startsWith('/mesero')) {
    return isInventario ? 'Stock activo' : 'Caja activa';
  }
  return null;
}

IconData? _resolveCurrentPageIcon(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
}) {
  final path = GoRouterState.of(context).uri.path;
  if (isOperativo && !isInventario && path.startsWith('/mesero')) {
    final mode = ref.watch(meseroSelectedModeProvider);
    return switch (mode) {
      MeseroPageMode.mesas => Icons.table_bar_rounded,
      MeseroPageMode.productos => Icons.inventory_2_rounded,
      MeseroPageMode.resumen => Icons.dashboard_customize_rounded,
      MeseroPageMode.historial => Icons.receipt_long_rounded,
      MeseroPageMode.cierreCaja => Icons.point_of_sale_rounded,
    };
  }
  if (isInventario) return Icons.inventory_rounded;
  return null;
}

class _PageTopBar extends StatelessWidget {
  const _PageTopBar({
    required this.title,
    required this.palette,
    required this.menuOpen,
    required this.onMenuPressed,
    this.subtitle,
    this.eyebrow,
    this.statusText,
    this.leadingContentIcon,
  });

  static const double height = 102;

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? statusText;
  final IconData? leadingContentIcon;
  final AppPalette palette;
  final bool menuOpen;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 780;
    final showRichHeader = subtitle != null || eyebrow != null || statusText != null || leadingContentIcon != null;

    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 10),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.985 : 0.99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.16 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TopBarIconButton(
            semanticLabel: menuOpen ? 'Ocultar menú' : 'Mostrar menú',
            icon: menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTap: onMenuPressed,
            palette: palette,
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Container(
              height: compact ? 68 : 76,
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 10 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: [
                    palette.surface.withOpacity(palette.darkBackground ? 0.86 : 0.92),
                    Color.lerp(palette.surface, palette.primary, 0.08)?.withOpacity(palette.darkBackground ? 0.84 : 0.90) ?? palette.surface,
                    Color.lerp(palette.surface, palette.secondary, 0.08)?.withOpacity(palette.darkBackground ? 0.84 : 0.90) ?? palette.surface,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(color: palette.secondary.withOpacity(0.18), width: 1.15),
                boxShadow: [
                  BoxShadow(
                    color: palette.secondary.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (leadingContentIcon != null) ...[
                    Container(
                      width: compact ? 40 : 46,
                      height: compact ? 40 : 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: palette.secondary.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Icon(leadingContentIcon, color: palette.onPrimary, size: compact ? 21 : 23),
                    ),
                    SizedBox(width: compact ? 10 : 14),
                  ],
                  Expanded(
                    child: showRichHeader
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!compact && (eyebrow ?? '').trim().isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: palette.secondary.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: palette.secondary.withOpacity(0.16)),
                                      ),
                                      child: Text(
                                        eyebrow!.toUpperCase(),
                                        style: TextStyle(
                                          color: palette.secondary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10.2,
                                          letterSpacing: 0.55,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: compact ? 20.5 : 23,
                                            letterSpacing: -0.35,
                                            height: 1,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((subtitle ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 11.8 : 12.6,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 20.5 : 23,
                                  letterSpacing: -0.35,
                                  height: 1,
                                ),
                          ),
                  ),
                  if ((statusText ?? '').trim().isNotEmpty && !compact) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: palette.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.primary.withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(statusText!, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.2)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          _TopBarIconButton(
            semanticLabel: 'Abrir mi perfil',
            icon: Icons.account_circle_rounded,
            onTap: () => context.go('/profile'),
            palette: palette,
            accent: true,
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    required this.palette,
    this.accent = false,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;
  final AppPalette palette;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: accent
            ? palette.secondary.withOpacity(palette.darkBackground ? 0.16 : 0.11)
            : palette.background.withOpacity(palette.darkBackground ? 0.46 : 0.78),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color: accent ? palette.secondary : palette.textPrimary,
              size: accent ? 30 : 24,
            ),
          ),
        ),
      ),
    );
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

class _DesktopMenuLauncher extends StatelessWidget {
  const _DesktopMenuLauncher({required this.palette, required this.onPressed});

  final AppPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mostrar menú',
      child: Material(
        color: palette.surface.withOpacity(0.96),
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.34),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Icon(Icons.menu_rounded, color: palette.secondary, size: 27),
          ),
        ),
      ),
    );
  }
}

class AppMenuToggleButton extends ConsumerWidget {
  const AppMenuToggleButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final menuOpen = ref.watch(operationalMenuOpenProvider);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Semantics(
      button: true,
      label: menuOpen ? 'Ocultar menú' : 'Mostrar menú',
      child: Material(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.78),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (isDesktop) {
              ref.read(operationalMenuOpenProvider.notifier).state = !menuOpen;
              return;
            }
            Scaffold.maybeOf(context)?.openDrawer();
          },
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: menuOpen
                    ? palette.secondary.withOpacity(0.42)
                    : palette.cardBorder,
              ),
            ),
            child: Icon(
              menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              color: menuOpen ? palette.secondary : palette.textPrimary,
              size: size * 0.56,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeseroScaffold extends StatelessWidget {
  const _MeseroScaffold({
    required this.child,
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.palette,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.pageEyebrow,
    required this.pageStatusText,
    required this.pageIcon,
    required this.bottomMenuType,
  });

  final Widget child;
  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final AppPalette palette;
  final String pageTitle;
  final String? pageSubtitle;
  final String? pageEyebrow;
  final String? pageStatusText;
  final IconData? pageIcon;
  final _OperationalBottomMenuType bottomMenuType;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    _PageTopBar(
                      title: pageTitle,
                      subtitle: pageSubtitle,
                      eyebrow: pageEyebrow,
                      statusText: pageStatusText,
                      leadingContentIcon: pageIcon,
                      palette: palette,
                      menuOpen: !collapsed,
                      onMenuPressed: onToggleCollapsed,
                    ),
                    Expanded(child: _PaletteAwareBody(child: child, palette: palette)),
                    _OperationalBottomNavigation(type: bottomMenuType),
                  ],
                ),
              ),
              if (!collapsed) ...[
                Positioned(
                  top: _PageTopBar.height,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleCollapsed,
                    child: ColoredBox(color: Colors.black.withOpacity(0.30)),
                  ),
                ),
                Positioned(
                  top: _PageTopBar.height,
                  left: 0,
                  bottom: 0,
                  child: _MeseroSideNavigation(
                    onLogout: onLogout,
                    collapsed: false,
                    onToggleCollapsed: onToggleCollapsed,
                    palette: palette,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(child: _MeseroDrawerContent(onLogout: onLogout, palette: palette)),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (scaffoldContext) => _PageTopBar(
                title: pageTitle,
                subtitle: pageSubtitle,
                eyebrow: pageEyebrow,
                statusText: pageStatusText,
                leadingContentIcon: pageIcon,
                palette: palette,
                menuOpen: false,
                onMenuPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              ),
            ),
            Expanded(child: _PaletteAwareBody(child: child, palette: palette)),
          ],
        ),
      ),
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
        width: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.surface,
              Color.lerp(palette.surface, palette.primary, 0.18) ?? palette.surface,
              palette.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(right: BorderSide(color: palette.cardBorder)),
        ),
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
      width: 312,
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
            message: collapsed ? 'Abrir menú' : 'Ocultar menú',
            child: IconButton.filledTonal(
              onPressed: onPressed,
              icon: Icon(collapsed ? Icons.menu_open_rounded : Icons.close_rounded),
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
