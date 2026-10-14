import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/sucursales_response_model.dart';
import '../sucursales_view_data.dart';
import '../widgets/confirm_permanent_branch_delete.dart';

class SucursalesDetailPage extends ConsumerStatefulWidget {
  const SucursalesDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SucursalesDetailPage> createState() => _SucursalesDetailPageState();
}

class _SucursalesDetailPageState extends ConsumerState<SucursalesDetailPage> {
  SucursalesResponseModel? _item;
  SucursalCatalogs _catalogs = const SucursalCatalogs();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final catalogsFuture = SucursalCatalogs.load(apiClient);
      final branchFuture = apiClient.get<SucursalesResponseModel>(
        '${ApiPaths.sucursales}/${widget.id}',
        (json) => SucursalesResponseModel.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );
      final catalogs = await catalogsFuture;
      final response = await branchFuture;
      if (!mounted) return;
      setState(() {
        _catalogs = catalogs;
        _item = response.data;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _inactivate() async {
    final item = _item;
    if (item?.sucuId == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Inactivar sucursal',
      message: 'La sede “${item!.sucuNombre ?? item.sucuCodigoInterno ?? item.sucuId}” dejará de estar disponible para nuevas operaciones. ¿Deseas continuar?',
    );
    if (!confirmed) return;
    try {
      await ref.read(apiClientProvider).delete<Object?>(
        '${ApiPaths.sucursales}/${item.sucuId}',
        (json) => json,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sucursal inactivada correctamente')),
      );
      context.go('/sucursales');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible inactivar la sucursal: $error')),
      );
    }
  }

  Future<void> _permanentlyDelete() async {
    final branch = _item;
    final id = branch?.sucuId;
    final branchName = branch?.sucuNombre;
    if (id == null || branchName == null) return;
    final confirmation = await confirmPermanentBranchDeletion(
      context,
      branchName: branchName,
    );
    if (confirmation == null || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete<Object?>(
        '${ApiPaths.sucursales}/$id/permanent?confirmation=${Uri.encodeQueryComponent(confirmation)}',
        (json) => json,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sucursal y datos asociados eliminados definitivamente')),
      );
      await ref.read(branchScopeProvider.notifier).load();
      context.go('/sucursales');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la sucursal: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppPageBackground()),
            AppLoader(message: 'Cargando ficha de la sucursal...'),
          ],
        ),
      );
    }

    if (_error != null || _item == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: AppPageBackground()),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_mall_directory_outlined, size: 62, color: palette.warning),
                    const SizedBox(height: 14),
                    Text(
                      'No fue posible consultar la sucursal',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'La sucursal solicitada no está disponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go('/sucursales'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Volver'),
                        ),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final item = _item!;
    final active = item.sucuEstado == 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: _DetailHeader(
                          item: item,
                          catalogs: _catalogs,
                          palette: palette,
                          onBack: () => context.go('/sucursales'),
                          onEdit: () => context.go('/sucursales/${item.sucuId}/editar'),
                          onRefresh: _load,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final desktop = constraints.maxWidth >= 860;
                            final summary = _SummaryPanel(
                              item: item,
                              catalogs: _catalogs,
                              palette: palette,
                            );
                            final content = Column(
                              children: [
                                _InformationSections(
                                  item: item,
                                  catalogs: _catalogs,
                                  palette: palette,
                                ),
                                const SizedBox(height: 14),
                                _QuickAccess(palette: palette),
                                const SizedBox(height: 14),
                                _DangerZone(
                                  palette: palette,
                                  onInactivate: active ? _inactivate : null,
                                  onDelete: _permanentlyDelete,
                                ),
                              ],
                            );

                            if (desktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 310, child: summary),
                                  const SizedBox(width: 16),
                                  Expanded(child: content),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                summary,
                                const SizedBox(height: 14),
                                content,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.item,
    required this.catalogs,
    required this.palette,
    required this.onBack,
    required this.onEdit,
    required this.onRefresh,
  });

  final SucursalesResponseModel item;
  final SucursalCatalogs catalogs;
  final AppPalette palette;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 28, tint: palette.secondary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 660;
          final title = Row(
            children: [
              IconButton.filledTonal(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Volver'),
              const SizedBox(width: 10),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.sucuNombre ?? 'Sucursal sin nombre',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.sucuCodigoInterno ?? 'Sin código'} · ${catalogs.empresa(item.emprId)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar'),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Modificar')),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: actions)],
            );
          }
          return Row(children: [Expanded(child: title), const SizedBox(width: 12), actions]);
        },
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.item, required this.catalogs, required this.palette});

  final SucursalesResponseModel item;
  final SucursalCatalogs catalogs;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final active = item.sucuEstado == 1;
    final statusColor = active ? palette.success : palette.warning;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 28, tint: active ? palette.secondary : palette.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [palette.primary, active ? palette.secondary : palette.warning]),
                borderRadius: BorderRadius.circular(29),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 47),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.sucuNombre ?? 'Sucursal sin nombre',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19),
          ),
          const SizedBox(height: 4),
          Text(
            item.sucuCodigoInterno ?? 'Sin código interno',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(active ? 'Sucursal activa' : 'Sucursal inactiva', style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SummaryLine(icon: Icons.business_rounded, value: catalogs.empresa(item.emprId), palette: palette),
          const SizedBox(height: 10),
          _SummaryLine(icon: Icons.location_city_rounded, value: catalogs.ciudad(item.ciudId), palette: palette),
          const SizedBox(height: 10),
          _SummaryLine(icon: Icons.payments_rounded, value: catalogs.moneda(item.moneId), palette: palette),
          const SizedBox(height: 10),
          _SummaryLine(icon: Icons.schedule_rounded, value: catalogs.zona(item.zohoId), palette: palette),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.value, required this.palette});

  final IconData icon;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: palette.secondary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.2)),
        ),
      ],
    );
  }
}

class _InformationSections extends StatelessWidget {
  const _InformationSections({required this.item, required this.catalogs, required this.palette});

  final SucursalesResponseModel item;
  final SucursalCatalogs catalogs;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoSection(
          palette: palette,
          icon: Icons.badge_rounded,
          title: 'Identidad',
          entries: [
            ('Nombre comercial', item.sucuNombre ?? 'Sin nombre', Icons.storefront_rounded),
            ('Código interno', item.sucuCodigoInterno ?? 'Sin código', Icons.qr_code_rounded),
            ('Empresa', catalogs.empresa(item.emprId), Icons.business_rounded),
            ('Identificador', item.sucuId?.toString() ?? 'Sin ID', Icons.tag_rounded),
          ],
        ),
        const SizedBox(height: 14),
        _InfoSection(
          palette: palette,
          icon: Icons.map_rounded,
          title: 'Ubicación y contacto',
          entries: [
            ('Ciudad', catalogs.ciudad(item.ciudId), Icons.location_city_rounded),
            ('Dirección', item.sucuDireccion ?? 'Sin dirección', Icons.location_on_rounded),
            ('Teléfono', item.sucuTelefono ?? 'Sin teléfono', Icons.phone_rounded),
            ('País del teléfono', catalogs.pais(item.paisIdtelefono), Icons.flag_rounded),
          ],
        ),
        const SizedBox(height: 14),
        _InfoSection(
          palette: palette,
          icon: Icons.settings_suggest_rounded,
          title: 'Configuración operativa',
          entries: [
            ('Moneda', catalogs.moneda(item.moneId), Icons.payments_rounded),
            ('Zona horaria', catalogs.zona(item.zohoId), Icons.schedule_rounded),
            ('Registrado por', item.sucuRegistradoPor ?? 'Sin información', Icons.person_outline_rounded),
            ('Última actualización', _formatDate(item.sucuFechaCambio), Icons.update_rounded),
          ],
        ),
      ],
    );
  }

  static String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Sin información';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.palette,
    required this.icon,
    required this.title,
    required this.entries,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final List<(String, String, IconData)> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 27, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: palette.secondary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 650 ? 2 : 1;
              final spacing = 10.0;
              final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(entry.$3, color: palette.secondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.$1, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11.5)),
                                  const SizedBox(height: 2),
                                  Text(entry.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, height: 1.2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final options = <({String label, String description, IconData icon, String route})>[
      (label: 'Usuarios', description: 'Personal asignado a sedes', icon: Icons.manage_accounts_rounded, route: '/usuarios'),
      (label: 'Mesas', description: 'Distribución operativa', icon: Icons.table_restaurant_rounded, route: '/mesas'),
      (label: 'Medios de pago', description: 'Cobros y códigos QR', icon: Icons.account_balance_wallet_rounded, route: '/medios_pago'),
      (label: 'Parámetros', description: 'Configuración de la sede', icon: Icons.tune_rounded, route: '/parametros'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 27, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Accesos relacionados', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Continúa configurando la operación de esta sede.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 650 ? 2 : 1;
              final spacing = 10.0;
              final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => context.go(option.route),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: palette.secondary.withOpacity(0.055),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(13)),
                                  child: Icon(option.icon, color: palette.secondary, size: 21),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(option.label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                                      Text(option.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: palette.secondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.palette, required this.onInactivate, required this.onDelete});

  final AppPalette palette;
  final VoidCallback? onInactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.warning.withOpacity(0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Administración de sucursal', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 3),
              Text('Inactivar conserva el historial. Eliminar definitivamente borra los datos propios de esta sucursal y no se puede deshacer.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.2, height: 1.3)),
            ],
          );
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onInactivate != null)
                OutlinedButton.icon(
                  onPressed: onInactivate,
                  icon: const Icon(Icons.pause_circle_rounded),
                  label: const Text('Inactivar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.warning,
                    side: BorderSide(color: palette.warning.withOpacity(0.45)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Eliminar definitivamente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 12), buttons]);
          }
          return Row(children: [Expanded(child: copy), const SizedBox(width: 14), Flexible(child: buttons)]);
        },
      ),
    );
  }
}
