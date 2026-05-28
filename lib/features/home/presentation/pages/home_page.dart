import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mesero/presentation/providers/mesero_tab_provider.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);
    final authState = ref.watch(authControllerProvider);
    final palette = ref.watch(selectedAppPaletteProvider);
    final isOperational = authState.roles.any(_isOperationalRole);
    final isCajero = authState.roles.any(_isCajeroRole);

    final operativeItems = _operativeItems(isCajero: isCajero);

    return AppScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 238,
              title: const Text('Inicio'),
              foregroundColor: palette.onTitle,
              backgroundColor: palette.titleBackground,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: TechBackground(
                  padding: const EdgeInsets.fromLTRB(22, 58, 22, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withOpacity(0.16)),
                              ),
                              child: Text(
                                isOperational ? 'Dashboard ${isCajero ? 'de caja' : 'de vendedor'}' : 'Dashboard administrativo',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Hola, bienvenido a BarLytics',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOperational
                                  ? 'Aquí tienes solamente las funciones habilitadas para tu rol operativo.'
                                  : 'Opera tu bar, inventario, ventas y pagos desde cualquier dispositivo.',
                              style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 700)
                        Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            gradient: palette.mainGradient,
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(color: Colors.white.withOpacity(0.16)),
                            boxShadow: [BoxShadow(color: palette.accent.withOpacity(0.28), blurRadius: 32, offset: const Offset(0, 16))],
                          ),
                          child: Icon(isOperational ? Icons.point_of_sale_rounded : Icons.insights_rounded, color: Colors.white, size: 58),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(18),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isOperational)
                    _QuickStats(modulesCount: operativeItems.length, rolesCount: authState.roles.length, operationLabel: isCajero ? 'Caja' : 'Ventas')
                  else
                    menuAsync.when(
                      loading: () => _QuickStats(modulesCount: 0, rolesCount: authState.roles.length, operationLabel: 'General'),
                      error: (_, __) => _QuickStats(modulesCount: 0, rolesCount: authState.roles.length, operationLabel: 'General'),
                      data: (items) => _QuickStats(modulesCount: items.length, rolesCount: authState.roles.length, operationLabel: 'General'),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    isOperational ? 'Funciones habilitadas para tu rol' : 'Módulos disponibles para tu rol',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOperational
                        ? 'Estas opciones se muestran según tu rol. El vendedor no ve historial de caja; el cajero sí puede revisarlo.'
                        : 'Estas opciones vienen desde la base de datos según los roles asignados a tu usuario.',
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (isOperational)
                    ResponsiveLayout(
                      mobile: _Grid(columns: 1, items: operativeItems),
                      tablet: _Grid(columns: 2, items: operativeItems),
                      desktop: _Grid(columns: 3, items: operativeItems),
                    )
                  else
                    menuAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: AppLoader(message: 'Cargando módulos autorizados...'),
                      ),
                      error: (error, _) => AppErrorView(
                        message: 'No fue posible cargar los módulos autorizados. Revisa la configuración de MENUS, OPCIONMENU y ROLES.',
                        onRetry: () => ref.invalidate(userMenuProvider),
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return _EmptyRoleModulesCard(palette: palette);
                        }

                        return ResponsiveLayout(
                          mobile: _Grid(columns: 1, items: items),
                          tablet: _Grid(columns: 2, items: items),
                          desktop: _Grid(columns: 3, items: items),
                        );
                      },
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isOperationalRole(String role) {
  final normalized = _normalizeRole(role);
  return normalized.contains('MESER') ||
      normalized.contains('CAJER') ||
      normalized.contains('CAJA') ||
      normalized.contains('VENDEDOR') ||
      normalized.contains('VENTA') ||
      normalized.contains('SELLER');
}

bool _isCajeroRole(String role) {
  final normalized = _normalizeRole(role);
  return normalized.contains('CAJER') || normalized.contains('CAJA') || normalized.contains('CASHIER');
}

String _normalizeRole(String value) => value
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

List<UserMenuItem> _operativeItems({required bool isCajero}) => [
      const UserMenuItem(
        keyName: 'mesas',
        title: 'Mesas',
        path: '/mesero',
        description: 'Abrir ventas, seleccionar mesas y operar cuentas.',
        system: true,
      ),
      const UserMenuItem(
        keyName: 'productos',
        title: 'Productos',
        path: '/mesero',
        description: 'Buscar productos por nombre, tipo, marca, código o precio.',
        system: true,
      ),
      const UserMenuItem(
        keyName: 'reportes',
        title: 'Resumen',
        path: '/mesero',
        description: 'Ver mesas abiertas, libres y valores pendientes.',
        system: true,
      ),
      if (isCajero)
        const UserMenuItem(
          keyName: 'ventas',
          title: 'Historial',
          path: '/mesero',
          description: 'Consultar ventas registradas y sus pagos.',
          system: true,
        ),
    ];

class _QuickStats extends ConsumerWidget {
  const _QuickStats({required this.modulesCount, required this.rolesCount, required this.operationLabel});
  final int modulesCount;
  final int rolesCount;
  final String operationLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _StatCard(title: 'Opciones visibles', value: modulesCount.toString(), icon: Icons.dashboard_customize_rounded, color: palette.secondary),
        _StatCard(title: 'Roles activos', value: rolesCount.toString(), icon: Icons.admin_panel_settings_rounded, color: palette.accent),
        _StatCard(title: 'Operación', value: operationLabel, icon: Icons.point_of_sale_rounded, color: palette.titleBackground),
      ],
    );
  }
}

class _StatCard extends ConsumerWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : 230,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, 12))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, palette.secondary]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                Text(title, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.items});
  final int columns;
  final List<UserMenuItem> items;

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        childAspectRatio: columns == 1 ? 3.7 : 2.2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        children: [
          for (final item in items) _ModuleCard(item: item),
        ],
      );
}

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.item});
  final UserMenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = ModuleVisuals.byKey(item.keyName);
    final palette = ref.watch(selectedAppPaletteProvider);

    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _goToModule(context, ref, item),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: palette.cardBorder),
            gradient: LinearGradient(
              colors: [
                palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.98),
                palette.background.withOpacity(palette.darkBackground ? 0.62 : 0.72),
                visual.color.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: visual.color.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [visual.color, palette.secondary]), borderRadius: BorderRadius.circular(22)),
                child: Icon(visual.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item.description ?? visual.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: visual.color),
            ],
          ),
        ),
      ),
    );
  }

  void _goToModule(BuildContext context, WidgetRef ref, UserMenuItem item) {
    if (item.system) {
      switch (item.title.toLowerCase()) {
        case 'mesas':
          ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas;
          context.go('/mesero');
          return;
        case 'productos':
          ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.productos;
          context.go('/mesero');
          return;
        case 'resumen':
          ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.resumen;
          context.go('/mesero');
          return;
        case 'historial':
          ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.historial;
          context.go('/mesero');
          return;
      }
    }
    context.go(item.path);
  }
}

class _EmptyRoleModulesCard extends StatelessWidget {
  const _EmptyRoleModulesCard({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: palette.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tu usuario no tiene opciones de menú asignadas. Valida la relación ROLES → OPCIONMENU → MENUS.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
