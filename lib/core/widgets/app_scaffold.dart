import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../branch/branch_scope_provider.dart';
import '../help/module_help_catalog.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/module_visuals.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/mesero/presentation/providers/mesero_tab_provider.dart';
import '../../features/navigation/data/models/user_menu_item.dart';
import '../../features/navigation/presentation/providers/user_menu_provider.dart';
import '../../features/navigation/presentation/providers/active_role_provider.dart';
import '../../features/profile/presentation/providers/profile_header_provider.dart';
import '../utils/responsive_utils.dart';
import 'barlytics_brand.dart';
import 'ready_order_notification_host.dart';
import 'tech_background.dart';

final ScrollController _desktopNavigationScrollController = ScrollController();
final ScrollController _mobileNavigationScrollController = ScrollController();

const double _appMenuWidth = 288;

BoxDecoration _appMenuDecoration(AppPalette palette) => BoxDecoration(
      gradient: palette.softGradient,
      boxShadow: [
        BoxShadow(
          color: palette.cardShadow.withOpacity(0.34),
          blurRadius: 28,
          offset: const Offset(10, 0),
        ),
      ],
    );

Color _selectedMenuForeground(AppPalette palette) {
  final representative = Color.lerp(palette.primary, palette.secondary, 0.5) ?? palette.primary;
  return ThemeData.estimateBrightnessForColor(representative) == Brightness.dark
      ? Colors.white
      : const Color(0xFF0F172A);
}

/// Controla la visibilidad del menú lateral operativo en escritorio.
final operationalMenuOpenProvider = StateProvider<bool>((ref) => false);

String _normalizedRoleToken(String role) {
  return role
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'^ROLE_'), '')
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

bool _isPersonalizedRole(String role) => _normalizedRoleToken(role) == 'PERSONALIZADO';

bool _isInventoryRole(String role) {
  final normalized = _normalizedRoleToken(role);
  return const {'INVENTARIO', 'INVENTORY', 'BODEGA', 'ALMACEN'}.contains(normalized);
}

bool _isMovementRole(String role) {
  final normalized = _normalizedRoleToken(role);
  return const {'MOVIMIENTOS', 'MOVIMIENTO'}.contains(normalized);
}

bool _isPriceRole(String role) => _normalizedRoleToken(role) == 'PRECIOS';

bool _isMesaCashierSellerRole(String role) {
  final normalized = _normalizedRoleToken(role);
  return const {'MESERO', 'MESERA', 'CAJERO', 'CAJERA', 'VENDEDOR', 'VENDEDORA', 'VENTAS', 'SELLER'}
      .contains(normalized);
}

bool _isManagerRole(String role) {
  final normalized = _normalizedRoleToken(role);
  return const {'GERENTE', 'MANAGER', 'SUPERVISOR'}.contains(normalized);
}

bool _isOperationalRole(String role) =>
    _isMesaCashierSellerRole(role) || _isInventoryRole(role) || _isMovementRole(role) || _isPriceRole(role);

bool _isGlobalAdminRole(String role) {
  final normalized = _normalizedRoleToken(role);
  return const {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN'}.contains(normalized);
}


/// Scaffold principal con navegación adaptable y diseño tecnológico unificado.
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _mainMenuCollapsed = true;
  bool _guideScheduled = false;

  void _scheduleHeaderGuide({required bool hasRoles, required bool hasBranches}) {
    if (_guideScheduled || (!hasRoles && !hasBranches)) return;
    _guideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || prefs.getBool('barlytics.header_selection_guide_v1') == true) return;
      final guide = hasRoles && hasBranches
          ? 'Puedes cambiar la vista por rol y elegir qué sucursal consultar desde el encabezado.'
          : hasRoles
              ? 'Puedes seleccionar uno, varios o todos tus roles desde Vista por rol.'
              : 'Puedes elegir qué sucursal consultar tocando el icono de tienda.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(guide),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Entendido', onPressed: () {}),
      ));
      await prefs.setBool('barlytics.header_selection_guide_v1', true);
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final palette = ref.watch(selectedAppPaletteProvider);
    final roles = ref.watch(activeRolesProvider);
    // Only an exclusively selected personalized role uses its custom flat order.
    // 'Todos los roles' must retain the grouped navigation from the backend.
    final hasPersonalizedRole = roles.length == 1 && _isPersonalizedRole(roles.first);
    // Un rol personalizado debe navegar exclusivamente con el catálogo que
    // devuelve /me/menus. No debe heredar shells ni menús predefinidos por el
    // nombre de otro rol que el usuario también tenga asignado.
    final isOperativo = !hasPersonalizedRole && roles.any(_isOperationalRole);
    final isInventario = !hasPersonalizedRole && roles.any(_isInventoryRole);
    final isManager = !hasPersonalizedRole && roles.any(_isManagerRole);
    final isGlobalAdmin = roles.any(_isGlobalAdminRole);
    // Las notificaciones pertenecen al usuario autenticado, no al rol
    // actualmente seleccionado. El backend ya filtra por destinatario, por lo
    // que todos los shells autenticados pueden consultar sus propios avisos.
    final branchScope = ref.watch(branchScopeProvider);
    _scheduleHeaderGuide(
      hasRoles: ref.watch(authControllerProvider).roles.length > 1,
      hasBranches: branchScope.branches.length > 1,
    );
    Widget withReadyOrderNotifications(Widget scaffold) {
      final branches = branchScope.branches;
      if (branches.length <= 1) {
        return ReadyOrderNotificationHost(child: scaffold);
      }
      return ReadyOrderNotificationHost(
        child: KeyedSubtree(
          key: ValueKey('sucursal-${branchScope.activeBranchId}'),
          child: scaffold,
        ),
      );
    }

    final operationalMenuOpen = ref.watch(operationalMenuOpenProvider);
    final pageTitle = _resolveCurrentPageTitle(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
      isManager: isManager,
    );
    final pageSubtitle = _resolveCurrentPageSubtitle(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
      isManager: isManager,
    );
    final pageEyebrow = _resolveCurrentPageEyebrow(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
      isManager: isManager,
    );
    final pageStatusText = _resolveCurrentPageStatusText(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
      isManager: isManager,
    );
    final pageIcon = _resolveCurrentPageIcon(
      context,
      ref,
      isOperativo: isOperativo,
      isInventario: isInventario,
      isManager: isManager,
    );

    if (isManager) {
      return withReadyOrderNotifications(
        _ManagerScaffold(
          child: widget.child,
          onLogout: () => _logout(context),
          collapsed: _mainMenuCollapsed,
          onToggleCollapsed: () =>
              setState(() => _mainMenuCollapsed = !_mainMenuCollapsed),
          palette: palette,
          pageTitle: pageTitle,
          pageSubtitle: pageSubtitle,
          pageEyebrow: pageEyebrow,
          pageStatusText: pageStatusText,
          pageIcon: pageIcon,
        ),
      );
    }

    if (isOperativo) {
      final operationalScaffold = _MeseroScaffold(
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

      return withReadyOrderNotifications(operationalScaffold);
    }

    if (isDesktop) {
      return withReadyOrderNotifications(
        Scaffold(
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
                    if (isGlobalAdmin)
                      const _AdminBottomNavigation()
                    else if (hasPersonalizedRole)
                      const _CustomRoleBottomNavigation()
                    else
                      const _ManagerBottomNavigation(),
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
        ),
      );
    }

    return withReadyOrderNotifications(
      Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        child: _DrawerContent(
          onLogout: () => _logout(context),
          palette: palette,
        ),
      ),
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
      bottomNavigationBar: isGlobalAdmin
          ? const _AdminBottomNavigation()
          : hasPersonalizedRole
              ? const _CustomRoleBottomNavigation()
              : const _ManagerBottomNavigation(),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de BarLytics en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(userMenuProvider);
    ref.invalidate(profileHeaderProvider);
    if (context.mounted) context.go('/login');
  }
}

String _resolveCurrentPageTitle(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
  required bool isManager,
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

  if (isManager && path == '/home') return 'Panel gerencial';

  const routeTitles = <String, String>{
    '/home': 'Inicio',
    '/profile': 'Mi perfil',
    '/dashboard': 'Dashboard',
    '/reportes': 'Reportes',
    '/reporte_resumen_ejecutivo': 'Resumen ejecutivo',
    '/reporte_ventas_fecha': 'Ventas por fecha',
    '/reporte_ventas_medio_pago': 'Ventas por medio de pago',
    '/reporte_stock_actual': 'Stock actual',
    '/ganancias': 'Ganancias',
    '/proximo_pedido': 'Próximo pedido',
    '/reporte_cruce_conteo': 'Cruce de conteo físico',
    '/reporte_productos_mas_vendidos': 'Productos más vendidos',
    '/reporte_movimientos_inventario': 'Movimientos de inventario',
    '/reporte_rotacion_inventario': 'Rotación de inventario',
    '/reporte_alertas_inventario': 'Alertas de inventario',
    '/reporte_salidas_responsable': 'Salidas por responsable',
    '/productos': 'Productos',
    '/inventario': 'Inventario',
    '/inventario_admin': 'Control administrativo de inventario',
    '/precios': 'Precios',
    '/tablas_parametricas': 'Tablas paramétricas',
    '/tipos_producto': 'Tipos de producto',
    '/marcas': 'Marcas',
    '/movimientos': 'Movimientos',
    '/medios_pago': 'Medios de pago por sucursal',
    '/usuarios': 'Usuarios',
    '/roles': 'Roles',
    '/roles_personalizados': 'Roles personalizados',
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
  required bool isManager,
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
  if (isInventario && path.startsWith('/inventario_admin')) {
    return 'Audita conteos, faltantes y sobrantes valorizados, responsables, ventas del día y conciliaciones.';
  }
  if (isInventario && path.startsWith('/ganancias')) {
    return 'Consulta ingresos, costos, margen y rentabilidad real del periodo.';
  }
  if (isInventario && path.startsWith('/proximo_pedido')) {
    return 'Planea la reposición según stock actual, mínimo, máximo y presentación de compra.';
  }
  if (isInventario && path.startsWith('/tablas_parametricas')) {
    return 'Organiza tipos de producto, marcas y medios de pago en un solo lugar.';
  }
  if (isManager && path == '/home') {
    return 'Supervisa ventas, inventario, rentabilidad y operación desde un panel rápido.';
  }
  if (isManager && path.startsWith('/dashboard')) {
    return 'Panorama completo del negocio con ventas, rentabilidad, gastos, inventario y operación.';
  }
  if (isManager && path.startsWith('/reporte_')) {
    return 'Consulta este reporte operativo con filtros, gráficos, datos y exportación.';
  }
  if (isManager && path.startsWith('/reportes')) {
    return 'Analiza la operación y toma decisiones con información consolidada.';
  }
  if (isManager && path.startsWith('/ganancias')) {
    return 'Consulta ingresos, costos, margen y rentabilidad del negocio.';
  }
  if (isManager && path.startsWith('/proximo_pedido')) {
    return 'Planea compras y reposición con base en el stock disponible.';
  }
  if (isManager) return 'Gestiona la operación del negocio con acceso rápido a tus módulos autorizados.';
  if (isInventario) return 'Gestiona inventario, movimientos y trazabilidad del stock.';
  return null;
}

String? _resolveCurrentPageEyebrow(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
  required bool isManager,
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
  if (isInventario && path.startsWith('/inventario_admin')) {
    return 'Control y trazabilidad';
  }
  if (isInventario && path.startsWith('/ganancias')) {
    return 'Analítica de rentabilidad';
  }
  if (isInventario && path.startsWith('/proximo_pedido')) {
    return 'Planificación de compras';
  }
  if (isInventario && path.startsWith('/tablas_parametricas')) {
    return 'Configuración operativa';
  }
  if (isManager && path == '/home') return 'Centro de control POS';
  if (isManager && path.startsWith('/dashboard')) return 'Resumen ejecutivo';
  if (isManager && path.startsWith('/reporte_')) return 'Reporte operativo';
  if (isManager) return 'Gestión gerencial';
  if (isInventario) return 'Operación de inventario';
  return null;
}

String? _resolveCurrentPageStatusText(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
  required bool isManager,
}) {
  final path = GoRouterState.of(context).uri.path;
  if (isOperativo && path.startsWith('/mesero')) {
    return isInventario ? 'Stock activo' : 'Caja activa';
  }
  if (isManager && path.startsWith('/dashboard')) return 'Panorama del periodo';
  if (isManager && path.startsWith('/reporte_')) return 'Datos actualizados';
  if (isInventario && path.startsWith('/inventario_admin')) {
    return 'Historial de conteos';
  }
  if (isInventario && path.startsWith('/ganancias')) return 'Periodo actual';
  if (isInventario && path.startsWith('/proximo_pedido')) return 'Stock actualizado';
  if (isManager) return 'Operación en línea';
  return null;
}

IconData? _resolveCurrentPageIcon(
  BuildContext context,
  WidgetRef ref, {
  required bool isOperativo,
  required bool isInventario,
  required bool isManager,
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
  if (isInventario && path.startsWith('/inventario_admin')) {
    return Icons.inventory_rounded;
  }
  if (isInventario && path.startsWith('/ganancias')) {
    return Icons.trending_up;
  }
  if (isInventario && path.startsWith('/proximo_pedido')) {
    return Icons.local_shipping_rounded;
  }
  if (isInventario && path.startsWith('/tablas_parametricas')) {
    return Icons.tune_rounded;
  }
  if (isManager && path == '/home') return Icons.space_dashboard_rounded;
  if (isManager && path.startsWith('/dashboard')) {
    return Icons.space_dashboard_rounded;
  }
  if (isManager && path.startsWith('/reporte_')) {
    return ModuleVisuals.byKey(path.substring(1)).icon;
  }
  if (isManager && path.startsWith('/reportes')) return Icons.analytics_rounded;
  if (isManager && path.startsWith('/ganancias')) return Icons.trending_up_rounded;
  if (isManager && path.startsWith('/proximo_pedido')) return Icons.local_shipping_rounded;
  if (isManager) return Icons.manage_accounts_rounded;
  if (isInventario) return Icons.inventory_rounded;
  return null;
}

class _PageTopBar extends ConsumerWidget {
  const _PageTopBar({
    required this.title,
    required this.palette,
    required this.menuOpen,
    required this.onMenuPressed,
    this.subtitle,
    this.eyebrow,
    this.statusText,
    this.leadingContentIcon,
    this.dense = false,
  });

  static const double height = 102;
  static const double denseHeight = 92;

  static double heightFor(bool dense) => dense ? denseHeight : height;

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? statusText;
  final IconData? leadingContentIcon;
  final AppPalette palette;
  final bool menuOpen;
  final VoidCallback onMenuPressed;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 780;
    final showRichHeader = subtitle != null || eyebrow != null || statusText != null || leadingContentIcon != null;
    final barHeight = heightFor(dense);

    return Container(
      height: barHeight,
      padding: dense
          ? EdgeInsets.fromLTRB(compact ? 10 : 14, 9, compact ? 10 : 14, 8)
          : EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 10),
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
          SizedBox(width: dense ? (compact ? 10 : 12) : (compact ? 12 : 14)),
          Expanded(
            child: Container(
              height: dense ? (compact ? 64 : 68) : (compact ? 68 : 76),
              padding: dense
                  ? EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 8 : 9)
                  : EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 10 : 12),
              decoration: palette.panelDecoration(
                baseRadius: 26,
                tint: palette.secondary,
                elevated: palette.surfaceStyle != AppSurfacePreset.flat,
              ).copyWith(
                border: Border.all(color: palette.secondary.withOpacity(0.18), width: 1.15),
              ),
              child: Row(
                children: [
                  if (leadingContentIcon != null) ...[
                    Container(
                      width: dense ? (compact ? 38 : 42) : (compact ? 40 : 46),
                      height: dense ? (compact ? 38 : 42) : (compact ? 40 : 46),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(palette.radius(15)),
                        boxShadow: [
                          BoxShadow(color: palette.secondary.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Icon(leadingContentIcon, color: palette.onPrimary, size: dense ? (compact ? 20 : 22) : (compact ? 21 : 23)),
                    ),
                    SizedBox(width: dense ? (compact ? 9 : 12) : (compact ? 10 : 14)),
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
                                        borderRadius: BorderRadius.circular(palette.radius(999)),
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
                                            fontSize: dense ? (compact ? 19.5 : 21.5) : (compact ? 20.5 : 23),
                                            letterSpacing: -0.35,
                                            height: 1,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((subtitle ?? '').trim().isNotEmpty) ...[
                                SizedBox(height: dense ? 4 : 6),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: dense ? (compact ? 11.2 : 12) : (compact ? 11.8 : 12.6),
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
                                  fontSize: dense ? (compact ? 19.5 : 21.5) : (compact ? 20.5 : 23),
                                  letterSpacing: -0.35,
                                  height: 1,
                                ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  _RoleScopeSelector(palette: palette, compact: compact),
                  const SizedBox(width: 8),
                  _CompactBranchSelector(palette: palette, compact: compact),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Ayuda de esta pantalla',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.help_outline_rounded, size: 19, color: palette.textSecondary),
                    onPressed: () => _showContextHelp(context, ref),
                  ),
                  if ((statusText ?? '').trim().isNotEmpty && !compact) ...[
                    SizedBox(width: dense ? 10 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 14, vertical: dense ? 8 : 10),
                      decoration: BoxDecoration(
                        color: palette.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(palette.radius(999)),
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
        ],
      ),
    );
  }
}

/// Ayuda contextual reutilizable del encabezado de todos los módulos.
void _showContextHelp(BuildContext context, WidgetRef ref) {
  final path = GoRouterState.of(context).uri.path.toLowerCase();
  final roles = ref.read(authControllerProvider).roles;
  final branches = ref.read(branchScopeProvider).branches;
  final guide = helpForRoute(path);
  final operation = helpForOperation(path);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(guide.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tips_and_updates_outlined),
                title: const Text('¿Qué puedo hacer aquí?'),
                subtitle: Text(guide.description),
              ),
              for (final entry in [...operation, ...guide.entries])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(entry.title),
                  subtitle: Text(entry.description),
              ),
              if (roles.length > 1)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Cambiar vista por rol'),
                  subtitle: Text('Desde el encabezado puedes elegir uno, varios o todos tus roles y ver sus opciones.'),
                ),
              if (branches.length > 1)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storefront_outlined),
                  title: Text('Cambiar sucursal'),
                  subtitle: Text('Selecciona el icono de tienda para consultar la información de otra sucursal autorizada.'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Selector en el encabezado, sin añadir otra franja vertical.
class _CompactBranchSelector extends ConsumerWidget {
  const _CompactBranchSelector({required this.palette, required this.compact});
  final AppPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(branchScopeProvider);
    if (scope.branches.length <= 1) return const SizedBox.shrink();
    final selected = scope.activeBranch;
    final name = (selected?.sucuNombre ?? 'Seleccionar sucursal').trim();
    return PopupMenuButton<int>(
      tooltip: 'Elegir sucursal: cambia los datos que estás viendo',
      enabled: !scope.loading,
      onSelected: (id) async {
        if (id == scope.activeBranchId) return;
        await ref.read(branchScopeProvider.notifier).select(id);
      },
      itemBuilder: (_) => scope.branches.map((branch) {
        final active = branch.sucuId == scope.activeBranchId;
        return PopupMenuItem<int>(
          value: branch.sucuId,
          child: Row(children: [
            Icon(active ? Icons.check_circle_rounded : Icons.storefront_outlined,
              size: 19, color: active ? palette.secondary : palette.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(branch.sucuNombre ?? 'Sucursal ${branch.sucuId}',
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        );
      }).toList(),
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 44 : 190),
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(palette.radius(12)),
          border: Border.all(color: palette.secondary.withOpacity(0.24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 18, color: palette.secondary),
          if (!compact) ...[
            const SizedBox(width: 7),
            Flexible(child: Text(name.isEmpty ? 'Sucursal' : name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontSize: 12,
                fontWeight: FontWeight.w700))),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: palette.textSecondary),
          ],
        ]),
      ),
    );
  }
}

class _RoleScopeSelector extends ConsumerWidget {
  const _RoleScopeSelector({required this.palette, required this.compact});
  final AppPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(authControllerProvider).roles;
    if (assigned.length <= 1) return const SizedBox.shrink();
    final selected = ref.watch(selectedRolesProvider);
    final active = ref.watch(activeRolesProvider);
    final all = selected == null;
    final activeLabel = all
        ? (compact ? 'Todos' : 'Todos los roles')
        : active.length == 1
            ? _displayRole(active.first)
            : compact
                ? '${active.length} roles'
                : active.length == 2
                    ? active.map(_displayRole).join(' + ')
                    : '${active.length} roles seleccionados';

    final selector = Material(
      color: palette.secondary.withOpacity(palette.darkBackground ? 0.22 : 0.12),
      borderRadius: BorderRadius.circular(palette.radius(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(palette.radius(16)),
        onTap: () => _showRoleSelector(context, ref, assigned, selected),
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 86 : 150,
            maxWidth: compact ? 96 : 210,
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 6 : 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(palette.radius(16)),
            border: Border.all(color: palette.secondary.withOpacity(0.30), width: 1.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_accounts_rounded, color: palette.secondary, size: compact ? 17 : 19),
              SizedBox(width: compact ? 5 : 7),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact ? 'VISTA' : 'VISTA POR ROL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 8.4 : 9.2,
                        letterSpacing: 0.45,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 10.4 : 11.5,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 1 : 3),
              Icon(Icons.keyboard_arrow_down_rounded, color: palette.secondary, size: compact ? 16 : 18),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Vista por rol: $activeLabel. Selecciona uno, varios o todos tus roles.',
      child: Tooltip(
        message: 'Cambia la interfaz según uno, varios o todos tus roles',
        child: selector,
      ),
    );
  }

  static String _displayRole(String role) {
    final value = role.replaceFirst(RegExp(r'^ROLE_', caseSensitive: false), '').replaceAll('_', ' ').trim();
    if (value.isEmpty) return 'Rol';
    return value.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  Future<void> _showRoleSelector(BuildContext context, WidgetRef ref, List<String> assigned, Set<String>? current) async {
    Set<String>? draft = current == null ? null : {...current};
    final applied = await showModalBottomSheet<Set<String>?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final all = draft == null;
          final media = MediaQuery.of(sheetContext);
          final viewportHeight = media.size.height;
          final compactHeight = viewportHeight < 620;
          final outerMargin = compactHeight ? 4.0 : 12.0;
          return SafeArea(
            minimum: EdgeInsets.all(compactHeight ? 2 : 0),
            child: SizedBox(
              height: (viewportHeight - media.padding.vertical - (outerMargin * 2)).clamp(220.0, viewportHeight),
              child: Container(
              margin: EdgeInsets.all(outerMargin),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(palette.radius(24)), border: Border.all(color: palette.cardBorder)),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(14, compactHeight ? 8 : 12, 14, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vista por roles', style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Elige cómo quieres ver BarLytics: un rol, varios roles o todos. La pantalla y los menús cambian según tu selección y nunca se repiten opciones.', style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: all,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Todos los roles', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('Combina todas las opciones autorizadas sin duplicados.'),
                  onChanged: (_) => setSheetState(() => draft = null),
                ),
                const Divider(),
                for (final role in assigned)
                  CheckboxListTile(
                    value: all || (draft?.any((r) => normalizeRoleName(r) == normalizeRoleName(role)) ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_displayRole(role), style: const TextStyle(fontWeight: FontWeight.w800)),
                    onChanged: (checked) {
                      setSheetState(() {
                        if (draft == null) draft = {role};
                        else if (checked == true) draft = {...draft!, role};
                        else {
                          final next = {...draft!}..removeWhere((r) => normalizeRoleName(r) == normalizeRoleName(role));
                          draft = next.isEmpty ? {role} : next;
                        }
                      });
                    },
                  ),
                    ]),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(top: BorderSide(color: palette.cardBorder)),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(palette.radius(24))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(draft ?? <String>{}),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Aplicar vista'),
                    ),
                  ),
                ),
              ]),
            ),
            ),
          );
        },
      ),
    );
    if (!context.mounted || applied == null) return;
    ref.read(selectedRolesProvider.notifier).state = applied.isEmpty ? null : applied;
    ref.invalidate(userMenuProvider);
    if (context.mounted) context.go('/home');
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

class _MenuProfileCard extends StatelessWidget {
  const _MenuProfileCard({
    required this.profile,
    required this.palette,
    this.dark = false,
    this.compact = false,
  });

  final ProfileHeaderInfo profile;
  final AppPalette palette;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayName = (profile.displayName ?? '').trim();
    final title = displayName.isEmpty ? 'Mi perfil' : displayName;
    final subtitle = displayName.isEmpty ? 'Ver datos de mi cuenta' : 'Mi perfil y cuenta';
    final avatar = ClipOval(
      child: SizedBox(
        width: compact ? 40 : 46,
        height: compact ? 40 : 46,
        child: _TopBarProfileImage(
          value: profile.photo,
          initials: profile.initials,
          palette: palette,
        ),
      ),
    );

    if (compact) {
      return Tooltip(
        message: 'Mi perfil',
        child: Material(
          color: dark ? Colors.white.withOpacity(0.10) : palette.secondary.withOpacity(0.10),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/profile'),
            child: Padding(padding: const EdgeInsets.all(6), child: avatar),
          ),
        ),
      );
    }

    return Material(
      color: dark ? Colors.white.withOpacity(0.10) : palette.secondary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go('/profile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? Colors.white : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? Colors.white70 : palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: dark ? Colors.white70 : palette.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarProfileImage extends StatelessWidget {
  const _TopBarProfileImage({
    required this.value,
    required this.initials,
    required this.palette,
  });

  final String? value;
  final String initials;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final normalized = (value ?? '').trim();
    final fallback = _fallback();
    if (normalized.isEmpty) return fallback;

    if (normalized.startsWith('data:image')) {
      final comma = normalized.indexOf(',');
      if (comma >= 0) {
        try {
          return Image.memory(
            base64Decode(normalized.substring(comma + 1)),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback,
          );
        } catch (_) {
          return fallback;
        }
      }
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    try {
      return Image.memory(
        base64Decode(normalized),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: palette.onPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            )
          : Icon(Icons.person_rounded, color: palette.onPrimary, size: 24),
    );
  }
}

class _PaletteAwareBody extends StatelessWidget {
  const _PaletteAwareBody({required this.child, required this.palette});

  final Widget child;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AppPageBackground()),
        Positioned.fill(child: child),
      ],
    );
  }
}

enum _OperationalBottomMenuType { mesa, inventory }

String _normalizeMenuSearch(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
}

bool _matchesMenuSearch(String query, Iterable<String?> values) {
  final normalizedQuery = _normalizeMenuSearch(query);
  if (normalizedQuery.isEmpty) return true;
  return values.whereType<String>().any(
        (value) => _normalizeMenuSearch(value).contains(normalizedQuery),
      );
}

Widget _menuSearchField({
  required AppPalette palette,
  required ValueChanged<String> onChanged,
}) {
  return TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: TextStyle(
      color: palette.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      hintText: 'Buscar menú...',
      hintStyle: TextStyle(
        color: palette.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(Icons.search_rounded, color: palette.secondary),
      filled: true,
      fillColor: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(palette.radius(16)),
        borderSide: BorderSide(color: palette.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(palette.radius(16)),
        borderSide: BorderSide(color: palette.secondary, width: 1.5),
      ),
    ),
  );
}

Widget _emptyMenuSearchState(AppPalette palette) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: palette.textSecondary, size: 34),
          const SizedBox(height: 8),
          Text(
            'No se encontraron menús',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Prueba con otro nombre o palabra.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

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
        borderRadius: BorderRadius.circular(palette.radius(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(palette.radius(16)),
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
        borderRadius: BorderRadius.circular(palette.radius(14)),
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
              borderRadius: BorderRadius.circular(palette.radius(14)),
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
    final denseMesasHeader = bottomMenuType == _OperationalBottomMenuType.mesa && pageTitle == 'Mesas y caja';
    final topBarHeight = _PageTopBar.heightFor(denseMesasHeader);

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
                      dense: denseMesasHeader,
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
                  top: topBarHeight,
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
                  top: topBarHeight,
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
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        child: _MeseroDrawerContent(
          onLogout: onLogout,
          palette: palette,
        ),
      ),
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
                dense: denseMesasHeader,
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

class _ManagerScaffold extends StatelessWidget {
  const _ManagerScaffold({
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
                    const _ManagerBottomNavigation(),
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
                  child: _SideNavigation(
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
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        child: _DrawerContent(onLogout: onLogout, palette: palette),
      ),
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
      bottomNavigationBar: const _ManagerBottomNavigation(),
    );
  }
}

class _MeseroSideNavigation extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileHeaderProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const ProfileHeaderInfo(),
        );
    final menuAsync = ref.watch(userMenuProvider);
    return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _appMenuWidth,
        decoration: _appMenuDecoration(palette),
        child: Stack(
          children: [
            Positioned(top: -70, right: -100, child: GlowCircle(size: 240, opacity: 0.18, color: palette.accent)),
            Positioned(bottom: -90, left: -120, child: GlowCircle(size: 280, opacity: 0.12, color: palette.secondary)),
            SafeArea(
              child: Column(
                children: [
                  _NavigationCollapseButton(collapsed: collapsed, onPressed: onToggleCollapsed, palette: palette),
                  if (collapsed) const _CollapsedBrand() else const _BrandHeader(dark: false),
                  Expanded(
                    child: ListView(
                      primary: false,
                      padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
                      children: [
                        _MenuProfileCard(profile: profile, palette: palette, compact: collapsed),
                        const SizedBox(height: 6),
                        _NavTile(title: 'Inicio', keyName: 'home', path: '/home', compact: collapsed, palette: palette),
                        if (!collapsed) const SizedBox(height: 8),
                        ..._authorizedMenuWidgets(
                          ref: ref,
                          menuAsync: menuAsync,
                          dark: false,
                          compact: collapsed,
                          palette: palette,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(collapsed ? 10 : 14),
                    child: _LogoutTile(onLogout: onLogout, compact: collapsed, palette: palette),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _MeseroDrawerContent extends ConsumerWidget {
  const _MeseroDrawerContent({required this.onLogout, required this.palette});
  final VoidCallback onLogout;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileHeaderProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const ProfileHeaderInfo(),
        );
    final menuAsync = ref.watch(userMenuProvider);
    return Container(
        decoration: BoxDecoration(gradient: palette.softGradient),
        child: Column(
          children: [
            const _BrandHeader(dark: false),
            Expanded(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _MenuProfileCard(profile: profile, palette: palette),
                  const SizedBox(height: 6),
                  _NavTile(title: 'Inicio', keyName: 'home', path: '/home', palette: palette),
                  const Divider(),
                  ..._authorizedMenuWidgets(
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
              child: _LogoutTile(onLogout: onLogout, palette: palette),
            ),
          ],
        ),
      );
  }
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
    final authorizedMenus = ref.watch(userMenuProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <UserMenuItem>[],
        );
    final roles = ref.watch(activeRolesProvider);
    final assignedRoles = ref.watch(authControllerProvider).roles;
    final isCajero = assignedRoles.any(
      (role) => _normalizedRoleToken(role) == 'CAJERO' ||
          _normalizedRoleToken(role) == 'CAJERA',
    );
    final selectedMode = !isCajero &&
            (rawSelectedMode == MeseroPageMode.historial ||
                rawSelectedMode == MeseroPageMode.cierreCaja)
        ? MeseroPageMode.resumen
        : rawSelectedMode;

    if (selectedMode != rawSelectedMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(meseroSelectedModeProvider.notifier).state = selectedMode;
      });
    }

    final entries = <({
      String path,
      MeseroPageMode? mode,
      BottomNavigationBarItem item,
    })>[
      (
        path: '/home',
        mode: null,
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
      ),
      (
        path: '/mesero',
        mode: MeseroPageMode.mesas,
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.table_bar_rounded),
          label: 'Mesas',
        ),
      ),
      (
        path: '/mesero/productos',
        mode: MeseroPageMode.productos,
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.liquor_rounded),
          label: 'Productos',
        ),
      ),
      if (!isCajero)
        (
          path: '/mesero/resumen',
          mode: MeseroPageMode.resumen,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Resumen',
          ),
        ),
      if (isCajero) ...[
        (
          path: '/mesero/historial',
          mode: MeseroPageMode.historial,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Historial',
          ),
        ),
        (
          path: '/pedidos-compra',
          mode: null,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_rounded),
            label: 'Pedidos',
          ),
        ),
        (
          path: '/mesero/cierre-caja',
          mode: MeseroPageMode.cierreCaja,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Cierre caja',
          ),
        ),
      ],
    ];

    final representedPaths = entries.map((entry) => entry.path).toSet();
    final extraMenus = authorizedMenus.where((item) {
      if (item.path.trim().isEmpty || item.keyName == 'mesero') return false;
      return !representedPaths.contains(item.path);
    }).toList(growable: false);
    final hasExtraMenus = extraMenus.isNotEmpty;
    final navigationEntries = <({
      String path,
      MeseroPageMode? mode,
      BottomNavigationBarItem item,
    })>[
      ...entries,
      if (hasExtraMenus)
        (
          path: '__more__',
          mode: null,
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
        ),
    ];

    final currentPath = GoRouterState.of(context).uri.path;
    var selectedIndex = navigationEntries.indexWhere(
      (entry) =>
          entry.path != '__more__' &&
          (currentPath == entry.path ||
              (entry.path != '/home' &&
                  currentPath.startsWith('${entry.path}/'))),
    );
    if (selectedIndex < 0 && currentPath.startsWith('/mesero')) {
      selectedIndex =
          navigationEntries.indexWhere((entry) => entry.mode == selectedMode);
    }
    if (extraMenus.any(
      (item) =>
          currentPath == item.path ||
          currentPath.startsWith('${item.path}/'),
    )) {
      selectedIndex =
          navigationEntries.indexWhere((entry) => entry.path == '__more__');
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
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
          selectedFontSize: 10.5,
          unselectedFontSize: 9.5,
          iconSize: 22,
          onTap: (index) {
            final entry = navigationEntries[index];
            if (entry.path == '__more__') {
              _showOperationalMoreMenu(
                context: context,
                palette: palette,
                items: extraMenus,
                currentPath: currentPath,
              );
              return;
            }
            if (entry.path == '/home') {
              context.go('/home');
              return;
            }
            if (entry.mode != null) {
              ref.read(meseroSelectedModeProvider.notifier).state = entry.mode!;
            }
            context.go(entry.path);
          },
          items: [for (final entry in navigationEntries) entry.item],
        ),
      ),
    );
  }

  Future<void> _showOperationalMoreMenu({
    required BuildContext context,
    required AppPalette palette,
    required List<UserMenuItem> items,
    required String currentPath,
  }) async {
    var query = '';
    var expandedCode = '';
    for (final item in items) {
      if (currentPath == item.path || currentPath.startsWith('${item.path}/')) {
        expandedCode = item.groupCode.trim().isEmpty
            ? 'OTROS'
            : item.groupCode.trim().toUpperCase();
        break;
      }
    }
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final searchActive = _normalizeMenuSearch(query).isNotEmpty;
          final filteredItems = items.where((item) {
            return _matchesMenuSearch(query, [
              item.title,
              item.description,
              item.keyName,
              item.groupName,
              item.path,
            ]);
          }).toList(growable: false);
          final groups = _groupOperationalMoreItems(filteredItems);

          final openCode = expandedCode;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(palette.radius(26)),
                  border: Border.all(color: palette.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: palette.textSecondary.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Más opciones',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organizadas por áreas según los permisos de tus roles.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _menuSearchField(
                      palette: palette,
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: groups.isEmpty
                          ? _emptyMenuSearchState(palette)
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: groups.length,
                              itemBuilder: (itemContext, index) {
                                final group = groups[index];
                                final expanded = searchActive || group.code == openCode;
                                final selected = group.items.any(
                                  (item) => currentPath == item.path || currentPath.startsWith('${item.path}/'),
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 9),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? palette.secondary.withOpacity(palette.darkBackground ? 0.11 : 0.06)
                                        : palette.background.withOpacity(palette.darkBackground ? 0.32 : 0.66),
                                    borderRadius: BorderRadius.circular(palette.radius(20)),
                                    border: Border.all(
                                      color: selected
                                          ? palette.secondary.withOpacity(0.34)
                                          : palette.cardBorder,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(palette.radius(20)),
                                          onTap: searchActive
                                              ? null
                                              : () => setSheetState(() {
                                                    expandedCode = expanded ? '' : group.code;
                                                  }),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: palette.secondary.withOpacity(0.13),
                                                    borderRadius: BorderRadius.circular(13),
                                                  ),
                                                  child: Icon(
                                                    _menuGroupIcon(group.iconToken),
                                                    color: palette.secondary,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 11),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        group.name,
                                                        style: TextStyle(
                                                          color: palette.textPrimary,
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${group.items.length} ${group.items.length == 1 ? 'opción' : 'opciones'}',
                                                        style: TextStyle(
                                                          color: palette.textSecondary,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                AnimatedRotation(
                                                  duration: const Duration(milliseconds: 180),
                                                  turns: expanded ? 0.5 : 0,
                                                  child: Icon(
                                                    Icons.keyboard_arrow_down_rounded,
                                                    color: palette.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 180),
                                        crossFadeState: expanded
                                            ? CrossFadeState.showSecond
                                            : CrossFadeState.showFirst,
                                        firstChild: const SizedBox(width: double.infinity),
                                        secondChild: Padding(
                                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                          child: Column(
                                            children: [
                                              for (final item in group.items)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Material(
                                                    color: currentPath == item.path ||
                                                            currentPath.startsWith('${item.path}/')
                                                        ? palette.secondary.withOpacity(
                                                            palette.darkBackground ? 0.18 : 0.09,
                                                          )
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(palette.radius(15)),
                                                    child: ListTile(
                                                      dense: true,
                                                      visualDensity: const VisualDensity(vertical: -2),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(palette.radius(15)),
                                                      ),
                                                      leading: Container(
                                                        width: 34,
                                                        height: 34,
                                                        decoration: BoxDecoration(
                                                          color: palette.secondary.withOpacity(0.11),
                                                          borderRadius: BorderRadius.circular(11),
                                                        ),
                                                        child: Icon(
                                                          _customRoleMenuIcon(item),
                                                          color: palette.secondary,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      title: Text(
                                                        item.title.trim().isEmpty ? item.keyName : item.title.trim(),
                                                        style: TextStyle(
                                                          color: palette.textPrimary,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                      subtitle: item.description == null
                                                          ? null
                                                          : Text(
                                                              item.description!,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                color: palette.textSecondary,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                      trailing: Icon(
                                                        Icons.chevron_right_rounded,
                                                        color: palette.textSecondary,
                                                      ),
                                                      onTap: () => Navigator.of(sheetContext).pop(item.path),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (destination != null && context.mounted) {
      context.go(destination);
    }
  }

  List<_MenuGroupData> _groupOperationalMoreItems(List<UserMenuItem> items) {
    final byCode = <String, List<UserMenuItem>>{};
    final metadata = <String, UserMenuItem>{};

    for (final item in items) {
      final code = item.groupCode.trim().isEmpty ? 'OTROS' : item.groupCode.trim().toUpperCase();
      byCode.putIfAbsent(code, () => <UserMenuItem>[]).add(item);
      metadata.putIfAbsent(code, () => item);
    }

    final groups = <_MenuGroupData>[];
    for (final entry in byCode.entries) {
      final meta = metadata[entry.key]!;
      final groupItems = List<UserMenuItem>.of(entry.value)
        ..sort((a, b) {
          final order = a.menuOrder.compareTo(b.menuOrder);
          return order != 0 ? order : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      groups.add(
        _MenuGroupData(
          code: entry.key,
          name: meta.groupName.trim().isEmpty ? 'Otros' : meta.groupName.trim(),
          iconToken: meta.groupIcon,
          order: meta.groupOrder,
          items: groupItems,
        ),
      );
    }

    groups.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

}

class _InventoryBottomNavigation extends ConsumerWidget {
  const _InventoryBottomNavigation();

  static const _standardItems = <({String label, IconData icon, String path})>[
    (label: 'Inicio', icon: Icons.home_rounded, path: '/home'),
    (label: 'Productos', icon: Icons.inventory_2_rounded, path: '/productos'),
    (label: 'Inventario', icon: Icons.fact_check_rounded, path: '/inventario'),
    (label: 'Precios', icon: Icons.price_change_rounded, path: '/precios'),
    (label: 'Movimientos', icon: Icons.sync_alt_rounded, path: '/movimientos'),
    (label: 'Parámetros', icon: Icons.tune_rounded, path: '/tablas_parametricas'),
    (label: 'Reportes', icon: Icons.analytics_rounded, path: '/reportes'),
    (label: 'Ganancias', icon: Icons.trending_up_rounded, path: '/ganancias'),
    (label: 'Pedido', icon: Icons.local_shipping_rounded, path: '/proximo_pedido'),
    (label: 'Sincronizar', icon: Icons.sync_alt_rounded, path: '/sincronizar_catalogo'),
  ];

  static const _moreItem = (label: 'Más', icon: Icons.more_horiz_rounded, path: '__more__');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final authorizedMenus = ref.watch(userMenuProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <UserMenuItem>[],
        );
    final standardByPath = <String, ({String label, IconData icon, String path})>{
      for (final item in _standardItems) item.path: item,
    };
    final byPath = <String, ({String label, IconData icon, String path})>{
      '/home': standardByPath['/home']!,
    };
    for (final item in authorizedMenus) {
      final path = item.path.trim();
      if (path.isEmpty || path == '/home') continue;
      final standard = standardByPath[path];
      byPath.putIfAbsent(
        path,
        () => standard ?? (
          label: item.title.trim().isEmpty ? item.keyName : item.title.trim(),
          icon: _customRoleMenuIcon(item),
          path: path,
        ),
      );
    }

    // El orden puede ser conocido, pero la existencia de cada opción depende
    // exclusivamente de los menús autorizados por el backend.
    final allItems = byPath.values.toList()
      ..sort((a, b) {
        final ai = _standardItems.indexWhere((item) => item.path == a.path);
        final bi = _standardItems.indexWhere((item) => item.path == b.path);
        final ap = ai < 0 ? 999 : ai;
        final bp = bi < 0 ? 999 : bi;
        final byPriority = ap.compareTo(bp);
        return byPriority != 0 ? byPriority : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    final maxVisible = width >= 1280
        ? 7
        : width >= 720
            ? 5
            : 4;
    final hasOverflow = allItems.length > maxVisible;
    final visibleCount = hasOverflow ? maxVisible - 1 : allItems.length;
    final visibleItems = allItems.take(visibleCount).toList(growable: false);
    final overflowItems = hasOverflow
        ? allItems.skip(visibleCount).toList(growable: false)
        : const <({String label, IconData icon, String path})>[];
    final navigationItems = <({String label, IconData icon, String path})>[
      ...visibleItems,
      if (overflowItems.isNotEmpty) _moreItem,
    ];

    final selectedPath = _inventorySelectedPath(currentPath, allItems);
    var selectedIndex = navigationItems.indexWhere((item) => item.path == selectedPath);
    if (selectedIndex < 0 && overflowItems.any((item) => item.path == selectedPath)) {
      selectedIndex = navigationItems.indexWhere((item) => item.path == _moreItem.path);
    }
    if (selectedIndex < 0) selectedIndex = 0;

    final isCompact = width < 720;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
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
          selectedFontSize: isCompact ? 10 : 11.5,
          unselectedFontSize: isCompact ? 9.5 : 11,
          iconSize: isCompact ? 21 : 23,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            final item = navigationItems[index];
            if (item.path == _moreItem.path) {
              _showInventoryMoreMenu(
                context: context,
                palette: palette,
                items: overflowItems,
                selectedPath: selectedPath,
              );
              return;
            }
            context.go(item.path);
          },
          items: [
            for (final item in navigationItems)
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Icon(item.icon),
                ),
                activeIcon: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 13, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(palette.darkBackground ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(18),
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

  String _inventorySelectedPath(
    String currentPath,
    List<({String label, IconData icon, String path})> allItems,
  ) {
    if (currentPath == '/home') return '/home';

    if (currentPath == '/tablas_parametricas' ||
        currentPath.startsWith('/tipos_producto') ||
        currentPath.startsWith('/marcas') ||
        currentPath.startsWith('/medios_pago')) {
      return '/tablas_parametricas';
    }

    for (final item in allItems) {
      if (currentPath == item.path || currentPath.startsWith('${item.path}/')) {
        return item.path;
      }
    }
    return '/home';
  }

  Future<void> _showInventoryMoreMenu({
    required BuildContext context,
    required AppPalette palette,
    required List<({String label, IconData icon, String path})> items,
    required String selectedPath,
  }) async {
    var query = '';
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final filteredItems = items.where((item) {
            return _matchesMenuSearch(query, [item.label, item.path]);
          }).toList(growable: false);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.76),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(palette.radius(26)),
                  border: Border.all(color: palette.cardBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 28, offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: palette.textSecondary.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Más opciones de inventario',
                      style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accede a precios, parámetros y reportes sin saturar la navegación principal.',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _menuSearchField(
                      palette: palette,
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredItems.isEmpty
                          ? _emptyMenuSearchState(palette)
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                for (final item in filteredItems)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Material(
                                      color: item.path == selectedPath
                                          ? palette.secondary.withOpacity(palette.darkBackground ? 0.20 : 0.10)
                                          : palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.70),
                                      borderRadius: BorderRadius.circular(palette.radius(18)),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(palette.radius(18))),
                                        leading: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: palette.secondary.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(item.icon, color: palette.secondary),
                                        ),
                                        title: Text(
                                          item.label,
                                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                                        ),
                                        trailing: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                                        onTap: () => Navigator.of(sheetContext).pop(item.path),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (destination != null && context.mounted) {
      context.go(destination);
    }
  }
}

IconData _customRoleMenuIcon(UserMenuItem item) {
  // Para roles personalizados usamos el ícono propio de cada función.
  // Así "Mesas", "Cierre de caja", "Historial", etc. no heredan el ícono
  // genérico del grupo inferior (Ventas/Inventario/Reportes).
  return ModuleVisuals.byKey(item.keyName).icon;
}

class _CustomRoleBottomNavigation extends ConsumerWidget {
  const _CustomRoleBottomNavigation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final authorizedMenus = ref.watch(userMenuProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <UserMenuItem>[],
        );

    final uniqueByPath = <String, UserMenuItem>{};
    for (final item in authorizedMenus) {
      final path = item.path.trim();
      if (path.isEmpty) continue;
      uniqueByPath.putIfAbsent(path, () => item);
    }
    final allItems = uniqueByPath.values.toList(growable: false);
    if (allItems.isEmpty) return const SizedBox.shrink();

    if (allItems.length == 1) {
      final item = allItems.first;
      final selected = _matchesPath(currentPath, item.path);
      return Container(
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(
            palette.darkBackground ? 0.96 : 0.99,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                palette.darkBackground ? 0.24 : 0.11,
              ),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: InkWell(
            onTap: () => context.go(item.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _customRoleMenuIcon(item),
                    color:
                        selected ? palette.secondary : palette.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selected ? palette.secondary : palette.textSecondary,
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final maxSlots = width >= 1280
        ? 7
        : width >= 720
            ? 5
            : 4;
    final hasOverflow = allItems.length > maxSlots;
    final visibleCount =
        hasOverflow ? maxSlots - 1 : allItems.length;
    final visibleItems =
        allItems.take(visibleCount).toList(growable: false);
    final overflowItems = hasOverflow
        ? allItems.skip(visibleCount).toList(growable: false)
        : const <UserMenuItem>[];

    var selectedIndex = visibleItems.indexWhere(
      (item) => _matchesPath(currentPath, item.path),
    );
    final selectedInOverflow = overflowItems.any(
      (item) => _matchesPath(currentPath, item.path),
    );
    if (selectedIndex < 0 && selectedInOverflow) {
      selectedIndex = visibleItems.length;
    }
    if (selectedIndex < 0) selectedIndex = 0;

    final compact = width < 720;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(
          palette.darkBackground ? 0.96 : 0.99,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              palette.darkBackground ? 0.24 : 0.11,
            ),
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
          selectedFontSize: compact ? 9.5 : 11,
          unselectedFontSize: compact ? 9 : 10.5,
          iconSize: compact ? 21 : 23,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            if (hasOverflow && index == visibleItems.length) {
              _showMore(
                context: context,
                palette: palette,
                items: overflowItems,
                currentPath: currentPath,
              );
              return;
            }
            context.go(visibleItems[index].path);
          },
          items: [
            for (final item in visibleItems)
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Icon(_customRoleMenuIcon(item)),
                ),
                activeIcon: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 13,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(
                      palette.darkBackground ? 0.22 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_customRoleMenuIcon(item)),
                ),
                label: item.title,
              ),
            if (hasOverflow)
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.more_horiz_rounded),
                ),
                label: 'Más',
              ),
          ],
        ),
      ),
    );
  }

  bool _matchesPath(String currentPath, String itemPath) {
    return currentPath == itemPath ||
        (itemPath != '/home' && currentPath.startsWith('$itemPath/'));
  }

  Future<void> _showMore({
    required BuildContext context,
    required AppPalette palette,
    required List<UserMenuItem> items,
    required String currentPath,
  }) async {
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final filtered = items
              .where(
                (item) => _matchesMenuSearch(
                  query,
                  [item.title, item.keyName, item.description],
                ),
              )
              .toList(growable: false);

          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(palette.radius(26)),
                border: Border.all(color: palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    'Más funciones',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Funciones adicionales autorizadas para este rol.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _menuSearchField(
                    palette: palette,
                    onChanged: (value) =>
                        setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filtered.isEmpty
                        ? _emptyMenuSearchState(palette)
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 7),
                            itemBuilder: (itemContext, index) {
                              final item = filtered[index];
                              final selected =
                                  _matchesPath(currentPath, item.path);
                              return ListTile(
                                selected: selected,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (context.mounted) {
                                      context.go(item.path);
                                    }
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(
                                    color: selected
                                        ? palette.secondary
                                        : palette.cardBorder,
                                  ),
                                ),
                                tileColor:
                                    palette.background.withOpacity(0.56),
                                selectedTileColor:
                                    palette.secondary.withOpacity(0.10),
                                leading: Icon(
                                  _customRoleMenuIcon(item),
                                  color: selected
                                      ? palette.secondary
                                      : palette.textSecondary,
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle:
                                    item.description?.trim().isNotEmpty == true
                                        ? Text(
                                            item.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 11,
                                            ),
                                          )
                                        : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminBottomNavigation extends ConsumerWidget {
  const _AdminBottomNavigation();

  static const _coreItems = <_AdminNavigationItem>[
    _AdminNavigationItem(label: 'Inicio', icon: Icons.home_rounded, path: '/home'),
    _AdminNavigationItem(label: 'Clientes', icon: Icons.business_rounded, path: '/empresas'),
    _AdminNavigationItem(label: 'Usuarios', icon: Icons.manage_accounts_rounded, path: '/usuarios'),
    _AdminNavigationItem(label: 'Soporte', icon: Icons.help_outline_rounded, path: '/soporte_global'),
    _AdminNavigationItem(label: 'Más', icon: Icons.more_horiz_rounded, path: '__more__'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(currentPath);
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? .96 : .99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? .24 : .11),
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
          unselectedItemColor: palette.textSecondary.withOpacity(.86),
          selectedFontSize: compact ? 10 : 11.5,
          unselectedFontSize: compact ? 9.5 : 11,
          iconSize: compact ? 21 : 23,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            final item = _coreItems[index];
            if (item.path == '__more__') {
              _showMore(context, ref, palette);
              return;
            }
            context.go(item.path);
          },
          items: [
            for (final item in _coreItems)
              BottomNavigationBarItem(
                icon: Padding(padding: const EdgeInsets.only(bottom: 3), child: Icon(item.icon)),
                activeIcon: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(palette.darkBackground ? .22 : .14),
                    borderRadius: BorderRadius.circular(18),
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

  int _selectedIndex(String path) {
    if (path == '/home') return 0;
    if (path.startsWith('/empresas') || path.startsWith('/sucursales')) return 1;
    if (path.startsWith('/usuarios') ||
        path.startsWith('/roles') ||
        path.startsWith('/tipos_usuario') ||
        path.startsWith('/menus') ||
        path.startsWith('/opciones_menu')) return 2;
    if (path.startsWith('/soporte_global') ||
        path.startsWith('/soporte_clientes') ||
        path.startsWith('/soporte_accesos') ||
        path.startsWith('/soporte_operacion') ||
        path.startsWith('/soporte_configuracion') ||
        path.startsWith('/soporte_mantenimiento') ||
        path.startsWith('/explorador_datos') ||
        path.startsWith('/diagnostico_sistema') ||
        path.startsWith('/auditoria_soporte') ||
        path.startsWith('/sincronizar_catalogo')) return 3;
    return 4;
  }

  void _showMore(BuildContext context, WidgetRef ref, AppPalette palette) {
    final authorized = ref.read(userMenuProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <UserMenuItem>[],
        );
    final entries = <_AdminNavigationItem>[
      const _AdminNavigationItem(label: 'Sincronizar catálogo', icon: Icons.sync_alt_rounded, path: '/sincronizar_catalogo'),
      const _AdminNavigationItem(label: 'Explorador de datos', icon: Icons.storage_rounded, path: '/explorador_datos'),
      const _AdminNavigationItem(label: 'Diagnóstico', icon: Icons.monitor_heart_rounded, path: '/diagnostico_sistema'),
      const _AdminNavigationItem(label: 'Auditoría', icon: Icons.history_rounded, path: '/auditoria_soporte'),
      for (final item in authorized)
        if (item.path.trim().isNotEmpty &&
            !const {'/home', '/empresas', '/usuarios', '/soporte_global', '/explorador_datos', '/diagnostico_sistema', '/auditoria_soporte', '/sincronizar_catalogo'}.contains(item.path))
          _AdminNavigationItem(
            label: item.title.trim().isEmpty ? item.keyName : item.title.trim(),
            icon: _customRoleMenuIcon(item),
            path: item.path,
            searchTerms: '${item.keyName} ${item.description ?? ''}',
          ),
      const _AdminNavigationItem(label: 'Perfil', icon: Icons.person_rounded, path: '/profile'),
    ];
    final unique = <String, _AdminNavigationItem>{};
    for (final item in entries) {
      unique.putIfAbsent(item.path, () => item);
    }
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final filteredItems = unique.values.where((item) {
            return _matchesMenuSearch(query, [item.label, item.path, item.searchTerms]);
          }).toList(growable: false);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .80),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(palette.radius(26)),
                  border: Border.all(color: palette.cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.20), blurRadius: 28, offset: const Offset(0, 12))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: palette.textSecondary.withOpacity(.30), borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                    Text('Todas las herramientas', style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Accede a cualquier módulo autorizado sin perder el menú inferior.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _menuSearchField(
                      palette: palette,
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredItems.isEmpty
                          ? _emptyMenuSearchState(palette)
                          : GridView.builder(
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.sizeOf(sheetContext).width >= 760 ? 3 : 2,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                                childAspectRatio: 2.35,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (itemContext, index) {
                                final item = filteredItems[index];
                                return InkWell(
                                  onTap: () {
                                    final destination = item.path;
                                    Navigator.pop(sheetContext);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (context.mounted) context.go(destination);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: palette.background.withOpacity(.56),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: palette.cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(item.icon, color: palette.primary, size: 21),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminNavigationItem {
  const _AdminNavigationItem({
    required this.label,
    required this.icon,
    required this.path,
    this.searchTerms = '',
  });

  final String label;
  final IconData icon;
  final String path;
  final String searchTerms;
}

class _ManagerBottomGroup {
  const _ManagerBottomGroup({
    required this.code,
    required this.label,
    required this.iconToken,
    required this.order,
    required this.items,
  });

  final String code;
  final String label;
  final String iconToken;
  final int order;
  final List<UserMenuItem> items;

  String get primaryPath {
    for (final item in items) {
      if (item.bottomPrimary) return item.path;
    }
    return items.first.path;
  }

  bool containsPath(String currentPath) {
    return items.any(
      (item) => currentPath == item.path ||
          (item.path != '/home' && currentPath.startsWith('${item.path}/')),
    );
  }
}

class _ManagerBottomNavigation extends ConsumerWidget {
  const _ManagerBottomNavigation();

  static const _managerBlockedKeys = <String>{
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final menuItems = ref.watch(userMenuProvider).maybeWhen(
          data: (items) => items
              .where((item) => !_managerBlockedKeys.contains(item.keyName.trim().toLowerCase()))
              .where((item) => item.path.trim().isNotEmpty)
              .toList(growable: false),
          orElse: () => const <UserMenuItem>[],
        );

    // La BD decide qué grupos merecen acceso principal. El shell conserva
    // Inicio y Más como elementos estructurales; entre ambos se muestran como
    // máximo tres grupos para mantener siempre una barra inferior de 5 items.
    final allBottomGroups = _buildBottomGroups(menuItems);
    final visibleGroups = allBottomGroups.take(3).toList(growable: false);

    var selectedIndex = 0;
    if (currentPath != '/home') {
      final groupIndex = visibleGroups.indexWhere((group) => group.containsPath(currentPath));
      selectedIndex = groupIndex >= 0 ? groupIndex + 1 : visibleGroups.length + 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
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
          selectedFontSize: compact ? 10 : 11.5,
          unselectedFontSize: compact ? 9.5 : 11,
          iconSize: compact ? 21 : 23,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              context.go('/home');
              return;
            }

            final moreIndex = visibleGroups.length + 1;
            if (index == moreIndex) {
              _showManagerMoreMenu(
                context: context,
                palette: palette,
                items: menuItems,
                selectedPath: currentPath,
              );
              return;
            }

            context.go(visibleGroups[index - 1].primaryPath);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Icon(Icons.home_rounded),
              ),
              activeIcon: _activeBottomIcon(
                icon: Icons.home_rounded,
                palette: palette,
                compact: compact,
              ),
              label: 'Inicio',
            ),
            for (final group in visibleGroups)
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Icon(_menuGroupIcon(group.iconToken)),
                ),
                activeIcon: _activeBottomIcon(
                  icon: _menuGroupIcon(group.iconToken),
                  palette: palette,
                  compact: compact,
                ),
                label: group.label,
              ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Icon(Icons.more_horiz_rounded),
              ),
              activeIcon: _activeBottomIcon(
                icon: Icons.more_horiz_rounded,
                palette: palette,
                compact: compact,
              ),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBottomIcon({
    required IconData icon,
    required AppPalette palette,
    required bool compact,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: 5),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon),
    );
  }

  List<_ManagerBottomGroup> _buildBottomGroups(List<UserMenuItem> items) {
    final byCode = <String, List<UserMenuItem>>{};
    final metadata = <String, UserMenuItem>{};

    for (final item in items) {
      if (!item.bottomVisible) continue;
      final code = item.bottomCode.trim().isEmpty ? 'OTROS' : item.bottomCode.trim().toUpperCase();
      byCode.putIfAbsent(code, () => <UserMenuItem>[]).add(item);
      final current = metadata[code];
      if (current == null || item.bottomOrder < current.bottomOrder) {
        metadata[code] = item;
      }
    }

    final groups = <_ManagerBottomGroup>[];
    for (final entry in byCode.entries) {
      final meta = metadata[entry.key]!;
      final groupItems = List<UserMenuItem>.of(entry.value)
        ..sort((a, b) {
          if (a.bottomPrimary != b.bottomPrimary) return a.bottomPrimary ? -1 : 1;
          final menuOrder = a.menuOrder.compareTo(b.menuOrder);
          if (menuOrder != 0) return menuOrder;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      groups.add(
        _ManagerBottomGroup(
          code: entry.key,
          label: meta.bottomName.trim().isEmpty ? meta.groupName : meta.bottomName.trim(),
          iconToken: meta.bottomIcon.trim().isEmpty ? meta.groupIcon : meta.bottomIcon.trim(),
          order: meta.bottomOrder,
          items: groupItems,
        ),
      );
    }

    groups.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return groups;
  }

  Future<void> _showManagerMoreMenu({
    required BuildContext context,
    required AppPalette palette,
    required List<UserMenuItem> items,
    required String selectedPath,
  }) async {
    const appearanceItem = UserMenuItem(
      keyName: 'apariencia',
      title: 'Apariencia',
      path: '__appearance__',
      description: 'Colores y apariencia de la aplicación',
      groupCode: 'CONFIGURACION',
      groupName: 'Configuración',
      groupIcon: 'settings',
      groupOrder: 50,
      menuOrder: 15,
      system: true,
    );
    const profileItem = UserMenuItem(
      keyName: 'profile',
      title: 'Perfil',
      path: '/profile',
      description: 'Datos y seguridad de la cuenta',
      groupCode: 'CONFIGURACION',
      groupName: 'Configuración',
      groupIcon: 'settings',
      groupOrder: 50,
      menuOrder: 999,
      system: true,
    );

    final allItems = <UserMenuItem>[...items, appearanceItem, profileItem];
    var query = '';
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final normalizedQuery = _normalizeMenuSearch(query);
          final filtered = allItems.where((item) {
            if (normalizedQuery.isEmpty) return true;
            return _matchesMenuSearch(query, [
              item.title,
              item.description,
              item.keyName,
              item.groupName,
              item.path,
            ]);
          }).toList(growable: false);
          final groups = _groupMoreItems(filtered);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(palette.radius(26)),
                  border: Border.all(color: palette.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: palette.textSecondary.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Más opciones',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Los módulos están organizados por las mismas categorías configuradas en la base de datos.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _menuSearchField(
                      palette: palette,
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: groups.isEmpty
                          ? _emptyMenuSearchState(palette)
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: groups.length,
                              itemBuilder: (itemContext, index) {
                                final group = groups[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                                  decoration: BoxDecoration(
                                    color: palette.background.withOpacity(
                                      palette.darkBackground ? 0.32 : 0.66,
                                    ),
                                    borderRadius: BorderRadius.circular(palette.radius(20)),
                                    border: Border.all(color: palette.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: palette.secondary.withOpacity(0.13),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                _menuGroupIcon(group.iconToken),
                                                color: palette.secondary,
                                                size: 19,
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                group.name,
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      for (final item in group.items)
                                        Material(
                                          color: item.path == selectedPath
                                              ? palette.secondary.withOpacity(
                                                  palette.darkBackground ? 0.18 : 0.09,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(palette.radius(15)),
                                          child: ListTile(
                                            dense: true,
                                            visualDensity: const VisualDensity(vertical: -2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(palette.radius(15)),
                                            ),
                                            leading: Icon(
                                              item.keyName == 'profile'
                                                  ? Icons.person_rounded
                                                  : item.path == '__appearance__'
                                                      ? Icons.palette_outlined
                                                      : _customRoleMenuIcon(item),
                                              color: item.path == selectedPath
                                                  ? palette.secondary
                                                  : palette.textSecondary,
                                              size: 20,
                                            ),
                                            title: Text(
                                              _managerLabel(item),
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            subtitle: item.description == null
                                                ? null
                                                : Text(
                                                    item.description!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: palette.textSecondary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                            trailing: Icon(
                                              Icons.chevron_right_rounded,
                                              color: palette.textSecondary,
                                            ),
                                            onTap: () => Navigator.of(sheetContext).pop(item.path),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (destination == '__appearance__' && context.mounted) {
      showPaletteSettingsDialog(context);
      return;
    }
    if (destination != null && context.mounted) {
      context.go(destination);
    }
  }

  List<_MenuGroupData> _groupMoreItems(List<UserMenuItem> items) {
    final byCode = <String, List<UserMenuItem>>{};
    final metadata = <String, UserMenuItem>{};

    for (final item in items) {
      final code = item.groupCode.trim().isEmpty ? 'OTROS' : item.groupCode.trim().toUpperCase();
      byCode.putIfAbsent(code, () => <UserMenuItem>[]).add(item);
      metadata.putIfAbsent(code, () => item);
    }

    final groups = <_MenuGroupData>[];
    for (final entry in byCode.entries) {
      final meta = metadata[entry.key]!;
      final groupItems = List<UserMenuItem>.of(entry.value)
        ..sort((a, b) {
          final order = a.menuOrder.compareTo(b.menuOrder);
          return order != 0 ? order : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      groups.add(
        _MenuGroupData(
          code: entry.key,
          name: meta.groupName.trim().isEmpty ? 'Otros' : meta.groupName.trim(),
          iconToken: meta.groupIcon,
          order: meta.groupOrder,
          items: groupItems,
        ),
      );
    }

    groups.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

  String _managerLabel(UserMenuItem item) {
    return switch (item.keyName) {
      'proximo_pedido' => 'Pedido',
      'tablas_parametricas' => 'Parámetros',
      'tipos_producto' => 'Tipos',
      'medios_pago' => 'Pagos',
      'zonas_horarias' => 'Zonas',
      _ => item.title.trim().isEmpty ? item.keyName : item.title.trim(),
    };
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
    final activeRoles = ref.watch(activeRolesProvider);
    final personalizedRole =
        activeRoles.length == 1 && _isPersonalizedRole(activeRoles.first);
    final profile = ref.watch(profileHeaderProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const ProfileHeaderInfo(),
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _appMenuWidth,
      decoration: _appMenuDecoration(palette),
      child: Stack(
        children: [
          Positioned(top: -80, right: -90, child: GlowCircle(size: 240, opacity: 0.20, color: palette.accent)),
          Positioned(bottom: -90, left: -120, child: GlowCircle(size: 300, opacity: 0.14, color: palette.secondary)),
          SafeArea(
            child: Column(
              children: [
                _NavigationCollapseButton(collapsed: collapsed, onPressed: onToggleCollapsed, palette: palette),
                if (collapsed) const _CollapsedBrand() else const _BrandHeader(dark: false),
                Expanded(
                  child: ListView(
                    key: const PageStorageKey<String>('desktop-main-navigation-scroll'),
                    controller: _desktopNavigationScrollController,
                    primary: false,
                    padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
                    children: [
                      _MenuProfileCard(profile: profile, palette: palette, compact: collapsed),
                      const SizedBox(height: 6),
                      if (!personalizedRole)
                        _NavTile(title: 'Inicio', keyName: 'home', path: '/home', compact: collapsed, palette: palette),
                      if (!collapsed && !personalizedRole) const SizedBox(height: 8),
                      ..._authorizedMenuWidgets(
                        ref: ref,
                        menuAsync: menuAsync,
                        dark: false,
                        compact: collapsed,
                        palette: palette,
                        preserveExactOrder: personalizedRole,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(collapsed ? 10 : 14),
                  child: _LogoutTile(onLogout: onLogout, compact: collapsed, palette: palette),
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
    final activeRoles = ref.watch(activeRolesProvider);
    final personalizedRole =
        activeRoles.length == 1 && _isPersonalizedRole(activeRoles.first);
    final profile = ref.watch(profileHeaderProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const ProfileHeaderInfo(),
        );

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
                _MenuProfileCard(profile: profile, palette: palette),
                const SizedBox(height: 6),
                if (!personalizedRole)
                  _NavTile(title: 'Inicio', keyName: 'home', path: '/home', palette: palette),
                if (!personalizedRole) const Divider(),
                ..._authorizedMenuWidgets(
                  ref: ref,
                  menuAsync: menuAsync,
                  dark: false,
                  compact: false,
                  palette: palette,
                  preserveExactOrder: personalizedRole,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _LogoutTile(onLogout: onLogout, palette: palette),
          ),
        ],
      ),
    );
  }
}

List<Widget> _authorizedMenuWidgets({
  required WidgetRef ref,
  required AsyncValue<List<UserMenuItem>> menuAsync,
  required bool dark,
  required bool compact,
  required AppPalette palette,
  bool preserveExactOrder = false,
}) {
  return menuAsync.when(
    loading: () => compact
        ? [const SizedBox.shrink()]
        : [
            _MenuMessage(
              dark: dark,
              palette: palette,
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
              palette: palette,
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
                  palette: palette,
                  icon: Icons.lock_outline_rounded,
                  title: 'Sin opciones asignadas',
                  message: 'Tu rol aún no tiene opciones de menú configuradas.',
                ),
              ];
      }

      return [
        _AuthorizedMenuGroups(
          items: items,
          dark: dark,
          compact: compact,
          palette: palette,
          preserveExactOrder: preserveExactOrder,
        ),
      ];
    },
  );
}

class _MenuGroupData {
  const _MenuGroupData({
    required this.code,
    required this.name,
    required this.iconToken,
    required this.order,
    required this.items,
  });

  final String code;
  final String name;
  final String iconToken;
  final int order;
  final List<UserMenuItem> items;
}

class _AuthorizedMenuGroups extends StatefulWidget {
  const _AuthorizedMenuGroups({
    required this.items,
    required this.dark,
    required this.compact,
    required this.palette,
    this.preserveExactOrder = false,
  });

  final List<UserMenuItem> items;
  final bool dark;
  final bool compact;
  final AppPalette palette;
  final bool preserveExactOrder;

  @override
  State<_AuthorizedMenuGroups> createState() => _AuthorizedMenuGroupsState();
}

class _AuthorizedMenuGroupsState extends State<_AuthorizedMenuGroups> {
  String? _expandedCode;
  String _lastPath = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = _currentPath();
    if (path != _lastPath) {
      _lastPath = path;
      _expandedCode = _selectedGroupCode(_buildGroups(), path);
    }
  }

  @override
  void didUpdateWidget(covariant _AuthorizedMenuGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _expandedCode = _selectedGroupCode(_buildGroups(), _currentPath());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preserveExactOrder) {
      final orderedItems = widget.items
          .where((item) => item.path.trim().isNotEmpty)
          .toList(growable: false);
      if (orderedItems.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final item in orderedItems) _menuItem(item),
        ],
      );
    }

    final groups = _buildGroups();
    if (groups.isEmpty) return const SizedBox.shrink();

    if (widget.compact) {
      return Column(
        children: [
          for (final group in groups) _buildCompactGroup(group),
        ],
      );
    }

    return Column(
      children: [
        for (final group in groups) _buildExpandedGroup(group),
      ],
    );
  }

  List<_MenuGroupData> _buildGroups() {
    final byCode = <String, List<UserMenuItem>>{};
    final metadata = <String, UserMenuItem>{};

    for (final item in widget.items) {
      final code = item.groupCode.trim().isEmpty ? 'OTROS' : item.groupCode.trim().toUpperCase();
      byCode.putIfAbsent(code, () => <UserMenuItem>[]).add(item);
      metadata.putIfAbsent(code, () => item);
    }

    // Apariencia es una utilidad local del cliente, no un permiso de negocio.
    // Se integra visualmente en Configuración sin alterar OPCIONMENU.
    const appearance = UserMenuItem(
      keyName: 'parametros',
      title: 'Apariencia',
      path: '__appearance__',
      groupCode: 'CONFIGURACION',
      groupName: 'Configuración',
      groupIcon: 'settings',
      groupOrder: 50,
      menuOrder: 15,
      system: true,
    );
    byCode.putIfAbsent('CONFIGURACION', () => <UserMenuItem>[]).add(appearance);
    metadata.putIfAbsent('CONFIGURACION', () => appearance);

    final groups = <_MenuGroupData>[];
    for (final entry in byCode.entries) {
      final meta = metadata[entry.key]!;
      final items = List<UserMenuItem>.of(entry.value)
        ..sort((a, b) {
          final order = a.menuOrder.compareTo(b.menuOrder);
          return order != 0 ? order : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      groups.add(_MenuGroupData(
        code: entry.key,
        name: meta.groupName.trim().isEmpty ? 'Otros' : meta.groupName.trim(),
        iconToken: meta.groupIcon,
        order: meta.groupOrder,
        items: items,
      ));
    }

    groups.sort((a, b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

  Widget _buildExpandedGroup(_MenuGroupData group) {
    final expanded = _expandedCode == group.code;
    final selected = _groupContainsPath(group, _currentPath());
    final foreground = widget.dark ? Colors.white : widget.palette.textPrimary;
    final secondary = widget.dark ? Colors.white70 : widget.palette.textSecondary;
    final accent = widget.dark ? widget.palette.accent : widget.palette.secondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? accent.withOpacity(widget.palette.darkBackground ? 0.16 : 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expanded || selected ? accent.withOpacity(0.18) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expandedCode = expanded ? '' : group.code),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_menuGroupIcon(group.iconToken), size: 20, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${group.items.length}',
                      style: TextStyle(color: secondary, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 6, 8),
                    child: Column(children: [for (final item in group.items) _menuItem(item)]),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGroup(_MenuGroupData group) {
    final selected = _groupContainsPath(group, _currentPath());
    final accent = widget.dark ? widget.palette.accent : widget.palette.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: group.name,
        child: PopupMenuButton<UserMenuItem>(
          tooltip: group.name,
          onSelected: _openItem,
          itemBuilder: (context) => [
            for (final item in group.items)
              PopupMenuItem<UserMenuItem>(
                value: item,
                child: Row(
                  children: [
                    Icon(
                      item.system && item.path == '__appearance__'
                          ? Icons.palette_outlined
                          : _customRoleMenuIcon(item),
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.title)),
                  ],
                ),
              ),
          ],
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: selected ? widget.palette.mainGradient : null,
              color: selected ? null : accent.withOpacity(0.11),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _menuGroupIcon(group.iconToken),
              color: selected ? _selectedMenuForeground(widget.palette) : accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(UserMenuItem item) {
    return _NavTile(
      title: item.title,
      keyName: item.keyName,
      path: item.path,
      dark: widget.dark,
      compact: widget.compact,
      palette: widget.palette,
      onTap: item.system && item.path == '__appearance__'
          ? () => showPaletteSettingsDialog(context)
          : null,
    );
  }

  void _openItem(UserMenuItem item) {
    if (item.system && item.path == '__appearance__') {
      showPaletteSettingsDialog(context);
      return;
    }
    GoRouter.of(context).go(item.path);
  }

  String _currentPath() {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '';
    }
  }

  String? _selectedGroupCode(List<_MenuGroupData> groups, String path) {
    for (final group in groups) {
      if (_groupContainsPath(group, path)) return group.code;
    }
    return null;
  }

  bool _groupContainsPath(_MenuGroupData group, String path) {
    return group.items.any((item) =>
        item.path.startsWith('/') &&
        (path == item.path || (item.path != '/home' && path.startsWith('${item.path}/'))));
  }
}

IconData _menuGroupIcon(String token) {
  switch (token.trim().toLowerCase()) {
    case 'point_of_sale':
    case 'operacion':
      return Icons.point_of_sale_rounded;
    case 'inventory_2':
    case 'inventario':
      return Icons.inventory_2_outlined;
    case 'analytics':
    case 'reportes':
      return Icons.analytics_outlined;
    case 'store':
    case 'negocio':
      return Icons.storefront_outlined;
    case 'settings':
    case 'configuracion':
      return Icons.tune_rounded;
    case 'admin_panel_settings':
    case 'administracion':
      return Icons.admin_panel_settings_outlined;
    case 'support_agent':
    case 'soporte':
      return Icons.support_agent_rounded;
    case 'room_service':
    case 'comandas':
      return Icons.receipt_long_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'table_restaurant':
    case 'table_bar':
      return Icons.table_restaurant_rounded;
    case 'receipt_long':
    case 'history':
      return Icons.receipt_long_rounded;
    case 'local_shipping':
      return Icons.local_shipping_rounded;
    case 'contact_phone':
      return Icons.contact_phone_rounded;
    case 'fact_check':
      return Icons.fact_check_rounded;
    case 'payments':
      return Icons.payments_rounded;
    case 'sell':
      return Icons.sell_rounded;
    case 'people':
    case 'people_alt':
      return Icons.people_alt_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
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
                boxShadow: [
                  BoxShadow(color: palette.cardShadow, blurRadius: 26, offset: const Offset(0, 14)),
                ],
              ),
              child: BarLyticsBrandLockup(
                width: 220,
                height: 64,
                darkBackground: dark || palette.darkBackground,
                showTagline: false,
                alignment: Alignment.centerLeft,
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
        child: BarLyticsBrandMark(size: 48),
      );
}

class _NavigationCollapseButton extends StatelessWidget {
  const _NavigationCollapseButton({
    required this.collapsed,
    required this.onPressed,
    required this.palette,
  });

  final bool collapsed;
  final VoidCallback onPressed;
  final AppPalette palette;

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
              color: palette.textPrimary,
              style: IconButton.styleFrom(
                backgroundColor: palette.secondary.withOpacity(
                  palette.darkBackground ? 0.18 : 0.10,
                ),
              ),
            ),
          ),
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
    final selectedForeground = _selectedMenuForeground(appPalette);

    Widget iconBox({required bool small}) => Container(
          width: small ? 36 : 38,
          height: small ? 36 : 38,
          decoration: BoxDecoration(
            gradient: selected ? appPalette.mainGradient : null,
            color: selected ? null : (dark ? Colors.white.withOpacity(0.12) : appPalette.secondary.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            visual.icon,
            size: small ? 19 : 20,
            color: selected ? selectedForeground : (dark ? Colors.white : appPalette.secondary),
          ),
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
    required this.palette,
    required this.icon,
    required this.title,
    required this.message,
  });

  final bool dark;
  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(0.10)
              : palette.secondary.withOpacity(palette.darkBackground ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: dark ? palette.accent : palette.secondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: dark ? Colors.white : palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: dark ? Colors.white70 : palette.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({
    required this.onLogout,
    required this.palette,
    this.dark = false,
    this.compact = false,
  });
  final VoidCallback onLogout;
  final AppPalette palette;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveCompact = compact || (constraints.maxWidth.isFinite && constraints.maxWidth < 118);
        final content = Material(
          color: dark
              ? Colors.white.withOpacity(0.10)
              : AppColors.danger.withOpacity(palette.darkBackground ? 0.16 : 0.10),
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
