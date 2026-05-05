import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/responsive_layout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 210,
              title: const Text('Inicio'),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFFFF7ED), Color(0xFFF5F3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Hola, bienvenido a BarLytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 8),
                                const Text('Opera tu bar, inventario, ventas y pagos desde cualquier dispositivo.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (MediaQuery.sizeOf(context).width >= 700)
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.tertiary]),
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.20), blurRadius: 28, offset: const Offset(0, 14))],
                              ),
                              child: const Icon(Icons.local_bar_rounded, color: Colors.white, size: 56),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _QuickStats(),
                  const SizedBox(height: 18),
                  Text('Módulos principales', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Elige una opción para consultar, crear o actualizar información.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ResponsiveLayout(
                    mobile: const _Grid(columns: 1),
                    tablet: const _Grid(columns: 2),
                    desktop: const _Grid(columns: 3),
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
  const _QuickStats();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: const [
          _StatCard(title: 'Módulos', value: '29', icon: Icons.dashboard_customize_rounded, color: AppColors.secondary),
          _StatCard(title: 'Operación', value: 'POS', icon: Icons.point_of_sale_rounded, color: AppColors.accent),
          _StatCard(title: 'Inventario', value: 'Stock', icon: Icons.inventory_2_rounded, color: AppColors.success),
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
        width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : 220,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: color)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        childAspectRatio: columns == 1 ? 3.7 : 2.2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final module in moduleRegistry) _ModuleCard(title: module.title, keyName: module.key, path: '/${module.key}'),
        ],
      );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.title, required this.keyName, required this.path});
  final String title;
  final String keyName;
  final String path;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(keyName);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.go(path),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(colors: [Colors.white, visual.color.withOpacity(0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: visual.color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)), child: Icon(visual.icon, color: visual.color, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(visual.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
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
