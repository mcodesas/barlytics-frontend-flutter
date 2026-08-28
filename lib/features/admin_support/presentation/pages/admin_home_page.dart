import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../data/admin_support_repository.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({
    super.key,
    required this.items,
    required this.rolesCount,
  });

  final List<UserMenuItem> items;
  final int rolesCount;

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminSupportRepositoryProvider).overview();
  }

  Future<void> _reload() async {
    setState(() => _future = ref.read(adminSupportRepositoryProvider).overview());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          final metrics = _maps(data['metrics']);
          final alerts = _maps(data['alerts']);
          final areas = _maps(data['areas']);
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _AdminHero(
                    palette: palette,
                    loading: loading,
                    rolesCount: widget.rolesCount,
                    onRefresh: _reload,
                  ),
                ),
                if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: _ErrorCard(
                        message: snapshot.error.toString(),
                        onRetry: _reload,
                        palette: palette,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: _MetricGrid(metrics: metrics, palette: palette),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;
                        final alertsPanel = _AlertPanel(
                          alerts: alerts,
                          palette: palette,
                        );
                        final toolsPanel = _SupportTools(palette: palette);
                        if (!wide) {
                          return Column(
                            children: [alertsPanel, const SizedBox(height: 14), toolsPanel],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: alertsPanel),
                            const SizedBox(width: 14),
                            Expanded(flex: 5, child: toolsPanel),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: _SectionHeader(
                      title: 'Administración por áreas',
                      subtitle: 'Funciones organizadas por cliente, seguridad, operación, caja, configuración y soporte.',
                      icon: Icons.account_tree_outlined,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: _AreaGrid(areas: areas, palette: palette),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: _SectionHeader(
                      title: 'Todos los módulos autorizados',
                      subtitle: '${widget.items.length} accesos disponibles para soporte global.',
                      icon: Icons.grid_view_rounded,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                    child: _AuthorizedModules(
                      items: widget.items,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({
    required this.palette,
    required this.loading,
    required this.rolesCount,
    required this.onRefresh,
  });

  final AppPalette palette;
  final bool loading;
  final int rolesCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat("EEEE, d 'de' MMMM", 'es').format(now);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.all(22),
      decoration: palette.panelDecoration(
        baseRadius: 28,
        tint: palette.primary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    icon: Icons.verified_user_rounded,
                    label: 'ADMINISTRADOR GLOBAL',
                    palette: palette,
                  ),
                  _Badge(
                    icon: Icons.calendar_today_rounded,
                    label: _capitalize(date),
                    palette: palette,
                  ),
                  _Badge(
                    icon: Icons.admin_panel_settings_rounded,
                    label: '$rolesCount ${rolesCount == 1 ? 'rol activo' : 'roles activos'}',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Centro de control de BarLytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                    ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Administra todos los clientes, usuarios, permisos, ventas, inventarios, configuraciones y registros técnicos desde una sola interfaz auditada.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _HeroAction(
                    icon: Icons.help_outline_rounded,
                    label: 'Centro de soporte',
                    onPressed: () => context.go('/soporte_global'),
                    palette: palette,
                    primary: true,
                  ),
                  _HeroAction(
                    icon: Icons.storage_rounded,
                    label: 'Explorador de datos',
                    onPressed: () => context.go('/explorador_datos'),
                    palette: palette,
                  ),
                  _HeroAction(
                    icon: Icons.monitor_heart_rounded,
                    label: 'Diagnóstico',
                    onPressed: () => context.go('/diagnostico_sistema'),
                    palette: palette,
                  ),
                  _HeroAction(
                    icon: loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                    label: loading ? 'Actualizando' : 'Actualizar',
                    onPressed: loading ? null : onRefresh,
                    palette: palette,
                  ),
                ],
              ),
            ],
          );
          final icon = Container(
            width: compact ? 82 : 116,
            height: compact ? 82 : 116,
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(palette.darkBackground ? .18 : .10),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.primary.withOpacity(.22)),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: compact ? 44 : 64,
              color: palette.primary,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 16), title],
            );
          }
          return Row(
            children: [Expanded(child: title), const SizedBox(width: 24), icon],
          );
        },
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.palette});

  final List<Map<String, dynamic>> metrics;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 6
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.palette});

  final Map<String, dynamic> metric;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final type = metric['type']?.toString() ?? '';
    final color = _typeColor(type, palette);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 21, tint: color),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_typeIcon(type), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric['value'] ?? 0}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  metric['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  metric['subtitle']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPanel extends StatelessWidget {
  const _AlertPanel({required this.alerts, required this.palette});

  final List<Map<String, dynamic>> alerts;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      palette: palette,
      title: 'Atención requerida',
      subtitle: alerts.isEmpty
          ? 'No se detectan novedades críticas en este momento.'
          : '${alerts.length} situaciones requieren revisión.',
      icon: Icons.warning_amber_rounded,
      child: alerts.isEmpty
          ? _EmptyMessage(
              icon: Icons.check_circle_rounded,
              text: 'La operación general se encuentra estable.',
              palette: palette,
            )
          : Column(
              children: [
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        final route = alert['route']?.toString();
                        if (route != null && route.isNotEmpty) context.go(route);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.warning.withOpacity(.08),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: palette.warning.withOpacity(.18)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: palette.warning, size: 21),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                alert['title']?.toString() ?? '',
                                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${alert['count'] ?? 0}',
                              style: TextStyle(color: palette.warning, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SupportTools extends StatelessWidget {
  const _SupportTools({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      const _Tool('Clientes', 'Empresas y sucursales', Icons.business_rounded, '/empresas'),
      const _Tool('Accesos', 'Usuarios, roles y credenciales', Icons.security_rounded, '/usuarios'),
      const _Tool('Sincronizar catálogo', 'Productos y costos entre empresas', Icons.sync_alt_rounded, '/sincronizar_catalogo'),
      const _Tool('Datos', 'Todas las tablas y registros', Icons.storage_rounded, '/explorador_datos'),
      const _Tool('Auditoría', 'Cambios realizados desde soporte', Icons.history_rounded, '/auditoria_soporte'),
      const _Tool('Diagnóstico', 'Integridad y reparaciones', Icons.monitor_heart_rounded, '/diagnostico_sistema'),
      const _Tool('Configuración', 'Parámetros globales y locales', Icons.tune_rounded, '/parametros'),
    ];
    return _Panel(
      palette: palette,
      title: 'Herramientas de soporte',
      subtitle: 'Acciones frecuentes para atender cualquier cliente.',
      icon: Icons.sync_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final tool in tools)
                SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: () => context.go(tool.route),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.primary.withOpacity(.055),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(tool.icon, color: palette.primary, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tool.title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                                Text(tool.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AreaGrid extends StatelessWidget {
  const _AreaGrid({required this.areas, required this.palette});

  final List<Map<String, dynamic>> areas;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in areas) {
      final category = item['category']?.toString() ?? 'Otros';
      grouped.putIfAbsent(category, () => <Map<String, dynamic>>[]).add(item);
    }
    return Column(
      children: [
        for (final entry in grouped.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: const {'Clientes', 'Seguridad', 'Soporte'}.contains(entry.key),
              tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: palette.cardBorder),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: palette.cardBorder),
              ),
              backgroundColor: palette.surface.withOpacity(.78),
              collapsedBackgroundColor: palette.surface.withOpacity(.68),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: palette.primary.withOpacity(.10),
                child: Icon(_categoryIcon(entry.key), color: palette.primary, size: 19),
              ),
              title: Text(entry.key, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              subtitle: Text('${entry.value.length} funciones', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 4
                        : constraints.maxWidth >= 680
                            ? 3
                            : constraints.maxWidth >= 430
                                ? 2
                                : 1;
                    final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in entry.value)
                          SizedBox(
                            width: width,
                            child: _AreaCard(item: item, palette: palette),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.item, required this.palette});

  final Map<String, dynamic> item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final route = item['route']?.toString();
    final key = item['key']?.toString() ?? '';
    final visual = ModuleVisuals.byKey(key);
    return InkWell(
      onTap: route == null || route.isEmpty ? null : () => context.go(route),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: visual.color.withOpacity(.055),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: visual.color.withOpacity(.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: visual.color.withOpacity(.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(visual.icon, color: visual.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(item['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, height: 1.28)),
                  const SizedBox(height: 7),
                  Text('${item['recordCount'] ?? 0} registros', style: TextStyle(color: visual.color, fontWeight: FontWeight.w800, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorizedModules extends StatelessWidget {
  const _AuthorizedModules({required this.items, required this.palette});

  final List<UserMenuItem> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 860
                ? 4
                : constraints.maxWidth >= 600
                    ? 3
                    : constraints.maxWidth >= 390
                        ? 2
                        : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ModuleCard(item: item, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item, required this.palette});

  final UserMenuItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    return InkWell(
      onTap: () => context.go(item.path),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(.72),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(visual.icon, color: visual.color, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 19),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.palette, required this.title, required this.subtitle, required this.icon, required this.child});

  final AppPalette palette;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: palette.panelDecoration(baseRadius: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, subtitle: subtitle, icon: icon, palette: palette),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.icon, required this.palette});

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: palette.primary, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.palette});

  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: palette.primary.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.primary.withOpacity(.14))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: palette.primary, size: 15), const SizedBox(width: 6), Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w800))]),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.icon, required this.label, required this.onPressed, required this.palette, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final AppPalette palette;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
    );
    if (primary) {
      return FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: style);
    }
    return OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: style);
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.text, required this.palette});

  final IconData icon;
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: palette.success.withOpacity(.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.success.withOpacity(.16))),
      child: Row(children: [Icon(icon, color: palette.success), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)))]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry, required this.palette});
  final String message;
  final VoidCallback onRetry;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.withOpacity(.07), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.red.withOpacity(.18))),
      child: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary))), TextButton(onPressed: onRetry, child: const Text('Reintentar'))]),
    );
  }
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const <Object?>[]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
Color _typeColor(String type, AppPalette palette) => switch (type) {
  'blocked' => Colors.red,
  'inventory' => Colors.orange,
  'sales' => Colors.blue,
  'users' => Colors.purple,
  'store' => Colors.teal,
  _ => palette.primary,
};
IconData _typeIcon(String type) => switch (type) {
  'blocked' => Icons.lock_rounded,
  'inventory' => Icons.inventory_2_rounded,
  'sales' => Icons.point_of_sale_rounded,
  'users' => Icons.people_alt_rounded,
  'store' => Icons.storefront_rounded,
  _ => Icons.business_rounded,
};
IconData _categoryIcon(String category) => switch (category) {
  'Clientes' => Icons.business_rounded,
  'Seguridad' => Icons.security_rounded,
  'Auditoría' => Icons.history_rounded,
  'Catálogo' => Icons.inventory_2_rounded,
  'Inventario' => Icons.inventory_2_rounded,
  'Ventas' => Icons.point_of_sale_rounded,
  'Caja' => Icons.account_balance_wallet_rounded,
  'Configuración' => Icons.tune_rounded,
  'Soporte' => Icons.help_outline_rounded,
  _ => Icons.apps_rounded,
};

class _Tool {
  const _Tool(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
