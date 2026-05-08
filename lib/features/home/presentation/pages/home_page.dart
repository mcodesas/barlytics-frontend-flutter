import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(userMenuProvider);
    final authState = ref.watch(authControllerProvider);

    return AppScaffold(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 238,
              title: const Text('Inicio'),
              foregroundColor: Colors.white,
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
                                border: Border.all(color: Colors.white.withOpacity(0.14)),
                              ),
                              child: const Text('Dashboard operativo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Hola, bienvenido a BarLytics',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Opera tu bar, inventario, ventas y pagos desde cualquier dispositivo.',
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
                            gradient: AppColors.bluePurpleGradient,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.28), blurRadius: 32, offset: const Offset(0, 16))],
                          ),
                          child: const Icon(Icons.insights_rounded, color: Colors.white, size: 58),
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
                  menuAsync.when(
                    loading: () => _QuickStats(modulesCount: 0, rolesCount: authState.roles.length),
                    error: (_, __) => _QuickStats(modulesCount: 0, rolesCount: authState.roles.length),
                    data: (items) => _QuickStats(modulesCount: items.length, rolesCount: authState.roles.length),
                  ),
                  const SizedBox(height: 22),
                  Text('Módulos disponibles para tu rol', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Estas opciones vienen desde la base de datos según los roles asignados a tu usuario.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
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
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: AppColors.secondaryDark),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tu usuario no tiene opciones de menú asignadas. Valida la relación ROLES → OPCIONMENU → MENUS.',
                                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
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

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.modulesCount, required this.rolesCount});
  final int modulesCount;
  final int rolesCount;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _StatCard(title: 'Módulos autorizados', value: modulesCount.toString(), icon: Icons.dashboard_customize_rounded, color: AppColors.secondary),
          _StatCard(title: 'Roles activos', value: rolesCount.toString(), icon: Icons.admin_panel_settings_rounded, color: AppColors.tertiary),
          const _StatCard(title: 'Operación', value: 'POS', icon: Icons.point_of_sale_rounded, color: AppColors.accent),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : 230,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 22, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, AppColors.tertiary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
        ),
      );
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

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item});
  final UserMenuItem item;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => context.go(item.path),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(colors: [Colors.white, AppColors.surfaceAlt, visual.color.withOpacity(0.07)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: visual.color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [visual.color, AppColors.tertiary]), borderRadius: BorderRadius.circular(22)),
                child: Icon(visual.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item.description ?? visual.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
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
}
