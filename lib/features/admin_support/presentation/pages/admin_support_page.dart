import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../data/admin_support_repository.dart';

class AdminSupportPage extends ConsumerStatefulWidget {
  const AdminSupportPage({super.key});

  @override
  ConsumerState<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends ConsumerState<AdminSupportPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';
  String _category = 'Todas';

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminSupportRepositoryProvider).catalog();
  }

  Future<void> _reload() async {
    setState(() => _future = ref.read(adminSupportRepositoryProvider).catalog());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final isSuperAdmin = ref.watch(activeRolesProvider).any((role) {
      final value = role.toUpperCase().trim().replaceFirst(RegExp(r'^ROLE_'), '');
      return const {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN', 'ADMIN Y SOPORTE', 'ADMIN_Y_SOPORTE'}.contains(value);
    });
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? const <Map<String, dynamic>>[];
          final categories = <String>{'Todas', ...allItems.map((item) => item['category']?.toString() ?? 'Otros')}.toList();
          final normalizedSearch = _search.trim().toLowerCase();
          final items = allItems.where((item) {
            final category = item['category']?.toString() ?? 'Otros';
            if (_category != 'Todas' && category != _category) return false;
            if (normalizedSearch.isEmpty) return true;
            final haystack = '${item['title']} ${item['description']} $category ${item['table']}'.toLowerCase();
            return haystack.contains(normalizedSearch);
          }).toList(growable: false);
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final category = item['category']?.toString() ?? 'Otros';
            grouped.putIfAbsent(category, () => <Map<String, dynamic>>[]).add(item);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _SupportHero(palette: palette, onRefresh: _reload, isSuperAdmin: isSuperAdmin)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SectionTitle(
                      title: '¿Qué necesitas resolver?',
                      subtitle: 'Entra por un flujo guiado y usa las herramientas en el orden correcto.',
                      icon: Icons.help_outline_rounded,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
                    child: _GuidedSupportGrid(palette: palette),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _SectionTitle(
                      title: 'Acciones frecuentes de soporte',
                      subtitle: 'Inicia los procesos más comunes sin buscar tablas ni identificadores técnicos.',
                      icon: Icons.bolt_rounded,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
                    child: _QuickActionGrid(palette: palette),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _SupportFilters(
                      palette: palette,
                      categories: categories,
                      selectedCategory: _category,
                      onCategoryChanged: (value) => setState(() => _category = value),
                      onSearchChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2))),
                if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                if (!snapshot.hasError && snapshot.connectionState != ConnectionState.waiting && items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, color: palette.textSecondary, size: 48),
                            const SizedBox(height: 9),
                            Text('No se encontraron funcionalidades', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                            Text('Cambia la búsqueda o la categoría.', style: TextStyle(color: palette.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                for (final entry in grouped.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        children: [
                          Icon(_categoryIcon(entry.key), color: palette.primary, size: 21),
                          const SizedBox(width: 8),
                          Text(entry.key, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text('${entry.value.length} funciones', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 1280
                            ? 4
                            : width >= 860
                                ? 3
                                : width >= 560
                                    ? 2
                                    : 1;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 11,
                            mainAxisSpacing: 11,
                            childAspectRatio: columns == 1 ? 2.7 : 1.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _SupportCard(item: entry.value[index], palette: palette),
                            childCount: entry.value.length,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({required this.palette, required this.onRefresh, required this.isSuperAdmin});
  final AppPalette palette;
  final Future<void> Function() onRefresh;
  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(19),
      decoration: palette.panelDecoration(baseRadius: 25, tint: palette.primary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: Icons.verified_user_rounded, label: 'ADMINISTRADOR GLOBAL', palette: palette),
                  _InfoPill(icon: Icons.fact_check_rounded, label: 'Acciones auditadas', palette: palette),
                  _InfoPill(icon: Icons.add_circle_outline_rounded, label: 'Crear, modificar y eliminar', palette: palette),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                'Centro de soporte global',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  'Administra clientes, accesos, catálogo, inventario, ventas, caja y configuración desde vistas funcionales. El explorador queda disponible para registros técnicos y contingencias.',
                  style: TextStyle(color: palette.textSecondary, height: 1.42),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/explorador_datos'),
                    icon: const Icon(Icons.storage_rounded, size: 18),
                    label: const Text('Explorador de datos'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/diagnostico_sistema'),
                    icon: const Icon(Icons.monitor_heart_rounded, size: 18),
                    label: const Text('Diagnóstico'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                  if (isSuperAdmin) OutlinedButton.icon(
                    onPressed: () => context.go('/centro_errores'),
                    icon: const Icon(Icons.bug_report_rounded, size: 18),
                    label: const Text('Centro de errores'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/auditoria_soporte'),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Auditoría'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                  IconButton(onPressed: onRefresh, tooltip: 'Actualizar catálogo', icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
            ],
          );
          final icon = Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(25)),
            child: Icon(Icons.help_outline_rounded, color: palette.primary, size: 48),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [icon, const SizedBox(height: 14), content]);
          return Row(children: [Expanded(child: content), const SizedBox(width: 20), icon]);
        },
      ),
    );
  }
}

class _GuidedSupportGrid extends StatelessWidget {
  const _GuidedSupportGrid({required this.palette});

  final AppPalette palette;

  static const _flows = <_GuidedSupportFlow>[
    _GuidedSupportFlow(
      'Clientes y sedes',
      'Crear o corregir empresa, sucursales y configuración inicial.',
      Icons.business_center_rounded,
      Color(0xFF2563EB),
      '/soporte_clientes',
    ),
    _GuidedSupportFlow(
      'Accesos y permisos',
      'Usuarios bloqueados, roles, menús y sucursales autorizadas.',
      Icons.security_rounded,
      Color(0xFF7C3AED),
      '/soporte_accesos',
    ),
    _GuidedSupportFlow(
      'Operación y caja',
      'Ventas, cuentas, pagos, mesas, inventario y cierres.',
      Icons.analytics_rounded,
      Color(0xFF0F766E),
      '/soporte_operacion',
    ),
    _GuidedSupportFlow(
      'Configuración',
      'Parámetros, catálogos, monedas, geografía y medios de pago.',
      Icons.tune_rounded,
      Color(0xFFB45309),
      '/soporte_configuracion',
    ),
    _GuidedSupportFlow(
      'Integridad y mantenimiento',
      'Diagnóstico, auditoría, secuencias y reparación segura.',
      Icons.sync_rounded,
      Color(0xFFBE123C),
      '/soporte_mantenimiento',
    ),
    _GuidedSupportFlow(
      'Catálogo maestro',
      'Crear y actualizar la plantilla global de productos, fotos y precios del asistente.',
      Icons.category_outlined,
      Color(0xFF0891B2),
      '/catalogo_maestro',
    ),
    _GuidedSupportFlow(
      'Catálogo entre clientes',
      'Copiar o sincronizar productos y costos sin inventario ni precio de venta.',
      Icons.compare_arrows_rounded,
      Color(0xFF0369A1),
      '/sincronizar_catalogo',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1260
            ? 6
            : constraints.maxWidth >= 1120
                ? 5
                : constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 460
                        ? 2
                        : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final flow in _flows)
              SizedBox(
                width: width,
                child: InkWell(
                  onTap: () => context.go(flow.route),
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: palette.panelDecoration(
                      baseRadius: 19,
                      tint: flow.color,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 39,
                              height: 39,
                              decoration: BoxDecoration(
                                color: flow.color.withOpacity(.10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(flow.icon, color: flow.color, size: 21),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_rounded, color: flow.color, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          flow.title,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          flow.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10.5,
                            height: 1.3,
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
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.palette});
  final AppPalette palette;

  static const _actions = <_QuickAction>[
    _QuickAction('Crear empresa', 'Alta de un nuevo cliente', Icons.add_business_rounded, '/empresas/nuevo'),
    _QuickAction('Crear sucursal', 'Configurar una nueva sede', Icons.store_mall_directory_rounded, '/sucursales/nuevo'),
    _QuickAction('Crear usuario', 'Acceso, rol y sucursales', Icons.person_add_alt_1_rounded, '/usuarios/nuevo'),
    _QuickAction('Crear producto', 'Catálogo comercial completo', Icons.add_box_rounded, '/productos/nuevo'),
    _QuickAction('Catálogo maestro', 'Productos base de nuevas empresas', Icons.category_outlined, '/catalogo_maestro'),
    _QuickAction('Inicializar inventario', 'Existencia inicial por sede', Icons.inventory_rounded, '/inventario/nuevo'),
    _QuickAction('Registrar movimiento', 'Entrada, salida o ajuste', Icons.swap_horiz_rounded, '/movimientos'),
    _QuickAction('Registrar o consultar pagos', 'Recaudo y cuentas pendientes', Icons.payments_rounded, '/pagos'),
    _QuickAction('Crear rol personalizado', 'Permisos por empresa o sede', Icons.admin_panel_settings_rounded, '/roles_personalizados'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 460
                    ? 2
                    : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in _actions)
              SizedBox(
                width: width,
                child: InkWell(
                  onTap: () => context.go(action.route),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: palette.panelDecoration(baseRadius: 18, tint: palette.primary),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
                          child: Icon(action.icon, color: palette.primary, size: 21),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                              const SizedBox(height: 2),
                              Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, height: 1.25)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 19),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SupportFilters extends StatelessWidget {
  const _SupportFilters({
    required this.palette,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });
  final AppPalette palette;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(labelText: 'Buscar funcionalidad', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          );
          final category = DropdownButtonFormField<String>(
            value: selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Área de soporte', prefixIcon: Icon(Icons.category_rounded), isDense: true),
            items: [for (final value in categories) DropdownMenuItem(value: value, child: Text(value))],
            onChanged: (value) {
              if (value != null) onCategoryChanged(value);
            },
          );
          if (constraints.maxWidth < 680) return Column(children: [search, const SizedBox(height: 10), category]);
          return Row(children: [Expanded(flex: 5, child: search), const SizedBox(width: 10), Expanded(flex: 3, child: category)]);
        },
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.item, required this.palette});
  final Map<String, dynamic> item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final key = item['key']?.toString() ?? '';
    final route = item['route']?.toString();
    final table = item['table']?.toString();
    final visual = ModuleVisuals.byKey(key);
    final hasRoute = route != null && route.trim().isNotEmpty;
    final technicalRoute = hasRoute && route.startsWith('/explorador_datos');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 20, tint: visual.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: visual.color.withOpacity(.11), borderRadius: BorderRadius.circular(14)),
                child: Icon(visual.icon, color: visual.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('${item['recordCount'] ?? 0} registros', style: TextStyle(color: visual.color, fontWeight: FontWeight.w800, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(
            child: Text(
              item['description']?.toString() ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasRoute ? () => context.go(route) : null,
                  icon: Icon(technicalRoute ? Icons.table_chart_rounded : Icons.open_in_new_rounded, size: 16),
                  label: Text(technicalRoute ? 'Administrar' : 'Abrir módulo'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 37), padding: const EdgeInsets.symmetric(horizontal: 10)),
                ),
              ),
              if (table != null && table.isNotEmpty && !technicalRoute) ...[
                const SizedBox(width: 7),
                IconButton(
                  tooltip: 'Ver datos técnicos',
                  onPressed: () => context.go('/explorador_datos?table=$table'),
                  style: IconButton.styleFrom(
                    backgroundColor: visual.color.withOpacity(.10),
                    foregroundColor: visual.color,
                    minimumSize: const Size(38, 38),
                  ),
                  icon: const Icon(Icons.storage_rounded, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle, required this.icon, required this.palette});
  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: palette.primary, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12))])),
        ],
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, required this.palette});
  final IconData icon;
  final String label;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: palette.primary.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.primary.withOpacity(.14))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: palette.primary, size: 15), const SizedBox(width: 6), Text(label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 10.5))]),
      );
}

class _GuidedSupportFlow {
  const _GuidedSupportFlow(
    this.title,
    this.description,
    this.icon,
    this.color,
    this.route,
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
}

class _QuickAction {
  const _QuickAction(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

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
