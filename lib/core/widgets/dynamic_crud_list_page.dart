import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_control_metrics.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_palette.dart';
import '../../app/theme/module_visuals.dart';
import '../crud/crud_field.dart';
import '../crud/crud_field_ordering.dart';
import '../crud/crud_lookup_resolver.dart';
import '../crud/crud_module_config.dart';
import '../crud/crud_notifier.dart';
import '../crud/crud_remote_datasource.dart';
import '../crud/crud_repository.dart';
import '../crud/crud_state.dart';
import '../providers/core_providers.dart';
import '../utils/responsive_utils.dart';
import 'app_empty_view.dart';
import 'app_error_view.dart';
import 'app_loader.dart';
import 'confirmation_dialog.dart';
import 'tech_background.dart';

/// Página genérica para listar registros CRUD con experiencia responsive.
class DynamicCrudListPage<T> extends ConsumerStatefulWidget {
  const DynamicCrudListPage({super.key, required this.config});

  final CrudModuleConfig<T> config;

  @override
  ConsumerState<DynamicCrudListPage<T>> createState() => _DynamicCrudListPageState<T>();
}

class _DynamicCrudListPageState<T> extends ConsumerState<DynamicCrudListPage<T>> {
  late final AutoDisposeStateNotifierProvider<CrudNotifier<T>, CrudState<T>> _provider;
  final _searchController = TextEditingController();
  Map<String, Map<String, String>> _lookupLabels = const <String, Map<String, String>>{};
  bool _loadingLookups = false;

  @override
  void initState() {
    super.initState();
    _provider = StateNotifierProvider.autoDispose<CrudNotifier<T>, CrudState<T>>((ref) {
      final repository = CrudRepository<T>(
        CrudRemoteDataSource<T>(ref.watch(apiClientProvider), widget.config),
      );
      return CrudNotifier<T>(repository)..load();
    });
    _loadLookupLabels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLookupLabels() async {
    if (_loadingLookups) return;
    setState(() => _loadingLookups = true);
    final resolver = CrudLookupResolver(ref.read(apiClientProvider));
    final labels = await resolver.resolveLabels(widget.config.fields);
    if (!mounted) return;
    setState(() {
      _lookupLabels = labels;
      _loadingLookups = false;
    });
  }

  Future<void> _refresh(CrudNotifier<T> notifier) async {
    await Future.wait<void>([
      notifier.load(),
      _loadLookupLabels(),
    ]);
  }

  List<T> _filterItems(List<T> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      final json = widget.config.toJson(item);
      final values = <String>[
        ...json.values.map((value) => value?.toString() ?? ''),
        for (final field in widget.config.fields) _displayValueOf(widget.config, item, field, _lookupLabels),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);
    final visual = ModuleVisuals.byKey(widget.config.key);
    final palette = ref.watch(selectedAppPaletteProvider);
    final visibleItems = _filterItems(state.items);

    Widget content;
    if (state.loading && state.items.isEmpty) {
      content = const AppLoader();
    } else if (state.failure != null) {
      content = AppErrorView(message: state.failure!.message, onRetry: () => _refresh(notifier));
    } else if (state.items.isEmpty) {
      content = const AppEmptyView();
    } else if (visibleItems.isEmpty) {
      content = const AppEmptyView(message: 'No encontramos registros con ese filtro.');
    } else {
      final showTable = ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isTablet(context);
      content = showTable
          ? _DesktopTable(
              config: widget.config,
              items: visibleItems,
              lookupLabels: _lookupLabels,
              visual: visual,
              palette: palette,
              onDelete: (id) async => _delete(context, notifier, id),
            )
          : _MobileCards(
              config: widget.config,
              items: visibleItems,
              lookupLabels: _lookupLabels,
              visual: visual,
              palette: palette,
              onDelete: (id) async => _delete(context, notifier, id),
            );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.config.allowCreate
          ? FloatingActionButton.extended(
              backgroundColor: palette.actionColor,
              foregroundColor: palette.onAction,
              onPressed: () => context.go('/${widget.config.key}/nuevo'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear'),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: () => _refresh(notifier),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ModuleHeader(
                      title: widget.config.title,
                      subtitle: visual.description,
                      visual: visual,
                      total: state.items.length,
                      visible: visibleItems.length,
                      searchController: _searchController,
                      onSearchChanged: (_) => setState(() {}),
                      onRefresh: () => _refresh(notifier),
                      loading: _loadingLookups || state.loading,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: content)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, CrudNotifier<T> notifier, Object id) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirmar eliminación',
      message: '¿Deseas eliminar o inactivar este registro?',
    );
    if (!confirmed) return;
    final ok = await notifier.remove(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Registro procesado correctamente' : 'No fue posible procesar el registro')),
      );
    }
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({
    required this.title,
    required this.subtitle,
    required this.visual,
    required this.total,
    required this.visible,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.loading,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final ModuleVisual visual;
  final int total;
  final int visible;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final bool loading;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.secondary.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final info = Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(visual.icon, color: palette.onPrimary, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administración de ${title.toLowerCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 3),
                        Text(subtitle, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CountPill(label: '$visible/$total', color: palette.secondary),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: loading ? null : onRefresh,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                    tooltip: 'Actualizar',
                  ),
                ],
              );

              final search = TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, código, estado o referencia...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                ).compactFilter(),
              );

              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 14), search]);
              }
              return Row(children: [Expanded(flex: 5, child: info), const SizedBox(width: 16), Expanded(flex: 4, child: search)]);
            },
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.22))),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      );
}

Object? _valueOf<T>(CrudModuleConfig<T> config, T item, String field) {
  final json = config.toJson(item);
  return json[field];
}

String _displayValueOf<T>(
  CrudModuleConfig<T> config,
  T item,
  CrudField field,
  Map<String, Map<String, String>> lookupLabels,
) {
  return crudDisplayValue(field, _valueOf(config, item, field.name), lookupLabels);
}


class _MobileCards<T> extends StatelessWidget {
  const _MobileCards({
    required this.config,
    required this.items,
    required this.lookupLabels,
    required this.visual,
    required this.palette,
    required this.onDelete,
  });

  final CrudModuleConfig<T> config;
  final List<T> items;
  final Map<String, Map<String, String>> lookupLabels;
  final ModuleVisual visual;
  final AppPalette palette;
  final Future<void> Function(Object id) onDelete;

  @override
  Widget build(BuildContext context) => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = _valueOf(config, item, config.idField) ?? index;
          final fields = crudSummaryFields(config);
          final summaryFields = fields.isEmpty ? <CrudField>[] : fields;
          final title = summaryFields
              .take(1)
              .map((field) => _displayValueOf(config, item, field, lookupLabels))
              .where((value) => value != '-')
              .join('');
          final imageField = _firstImageField(config);
          final imageValue = imageField == null ? '' : _displayValueOf(config, item, imageField, lookupLabels);

          return Card(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: palette.cardBorder)),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('/${config.key}/$id'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageValue.trim().isNotEmpty && imageValue != '-'
                        ? _CrudImageThumb(value: imageValue, size: 58, radius: 20, palette: palette)
                        : Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                            child: Icon(visual.icon, color: palette.secondary, size: 28),
                          ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title.isEmpty ? config.title : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final field in summaryFields.skip(1).take(4)) _MiniChip(label: _displayValueOf(config, item, field, lookupLabels), color: palette.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'detail') context.go('/${config.key}/$id');
                        if (value == 'edit') context.go('/${config.key}/$id/editar');
                        if (value == 'delete') onDelete(id);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'detail', child: Text('Ver detalle')),
                        const PopupMenuItem(value: 'edit', child: Text('Editar configuración')),
                        if (config.allowDelete)
                          const PopupMenuItem(value: 'delete', child: Text('Eliminar/Inactivar')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}


CrudField? _firstImageField<T>(CrudModuleConfig<T> config) {
  for (final field in config.fields) {
    if (field.type == CrudFieldType.image) return field;
  }
  return null;
}

class _CrudImageThumb extends StatelessWidget {
  const _CrudImageThumb({required this.value, required this.size, required this.radius, required this.palette});

  final String value;
  final double size;
  final double radius;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final imageValue = value.trim();
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.45 : 0.72), borderRadius: BorderRadius.circular(radius)),
      child: Icon(Icons.image_not_supported_outlined, color: palette.textSecondary),
    );

    if (imageValue.isEmpty) return placeholder;

    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(base64Decode(imageValue.substring(commaIndex + 1)), width: size, height: size, fit: BoxFit.cover),
          );
        } catch (_) {
          return placeholder;
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(imageValue, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(999)),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _DesktopTable<T> extends StatefulWidget {
  const _DesktopTable({
    required this.config,
    required this.items,
    required this.lookupLabels,
    required this.visual,
    required this.palette,
    required this.onDelete,
  });

  final CrudModuleConfig<T> config;
  final List<T> items;
  final Map<String, Map<String, String>> lookupLabels;
  final ModuleVisual visual;
  final AppPalette palette;
  final Future<void> Function(Object id) onDelete;

  @override
  State<_DesktopTable<T>> createState() => _DesktopTableState<T>();
}

class _DesktopTableState<T> extends State<_DesktopTable<T>> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = crudVisibleFields(widget.config);
    final columnWidths = <String, double>{
      for (final field in columns) field.name: _columnWidthFor(field),
    };
    final tableWidth = math.max(
      MediaQuery.sizeOf(context).width - 48,
      columnWidths.values.fold<double>(0, (total, value) => total + value) + 210 + (columns.length * 22),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.palette.surface.withOpacity(widget.palette.darkBackground ? 0.94 : 0.985),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: widget.palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: widget.palette.cardShadow,
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      headingRowHeight: 58,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 86,
                      horizontalMargin: 18,
                      columnSpacing: 18,
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(widget.palette.secondary.withOpacity(widget.palette.darkBackground ? 0.12 : 0.07)),
                      headingTextStyle: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: widget.palette.textPrimary,
                      ),
                      dataTextStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.palette.textPrimary,
                      ),
                      columns: [
                        for (final field in columns)
                          DataColumn(
                            label: SizedBox(
                              width: columnWidths[field.name],
                              child: Text(
                                field.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        const DataColumn(
                          label: SizedBox(width: 180, child: Text('Acciones')),
                        ),
                      ],
                      rows: [
                        for (final item in widget.items)
                          DataRow(
                            onSelectChanged: (_) => context.go('/${widget.config.key}/${_valueOf(widget.config, item, widget.config.idField)}'),
                            cells: [
                              for (final field in columns)
                                DataCell(
                                  SizedBox(
                                    width: columnWidths[field.name],
                                    child: _ResponsiveCell(
                                      value: _displayValueOf(widget.config, item, field, widget.lookupLabels),
                                      field: field,
                                      color: widget.palette.secondary,
                                      palette: widget.palette,
                                    ),
                                  ),
                                ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ActionIcon(
                                        color: widget.palette.secondary,
                                        icon: Icons.visibility_rounded,
                                        onPressed: () => context.go('/${widget.config.key}/${_valueOf(widget.config, item, widget.config.idField)}'),
                                      ),
                                      _ActionIcon(
                                        color: widget.palette.primary,
                                        icon: Icons.edit_rounded,
                                        onPressed: () => context.go('/${widget.config.key}/${_valueOf(widget.config, item, widget.config.idField)}/editar'),
                                      ),
                                      if (widget.config.allowDelete)
                                        _ActionIcon(
                                          color: AppColors.danger,
                                          icon: Icons.delete_outline_rounded,
                                          onPressed: () => widget.onDelete(_valueOf(widget.config, item, widget.config.idField) ?? ''),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _columnWidthFor(CrudField field) {
    if (field.type == CrudFieldType.image) return 96;
    if (field.lookup != null) return 260;
    if (field.type == CrudFieldType.date || field.type == CrudFieldType.dateTime) return 190;
    if (field.type == CrudFieldType.number || field.type == CrudFieldType.decimal) return 150;
    if (field.type == CrudFieldType.boolean) return 130;
    final labelBasedWidth = (field.label.length * 9.0) + 72;
    return math.max(170, math.min(300, labelBasedWidth));
  }
}

class _ResponsiveCell extends StatelessWidget {
  const _ResponsiveCell({required this.value, required this.field, required this.color, required this.palette});

  final String value;
  final CrudField field;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (field.type == CrudFieldType.image) {
      return value.trim().isEmpty || value == '-'
          ? Text('Sin foto', style: TextStyle(color: palette.textSecondary))
          : _CrudImageThumb(value: value, size: 54, radius: 16, palette: palette);
    }

    if (field.lookup != null && value != '-') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    return Text(
      value,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.color, required this.icon, required this.onPressed});
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: color.withOpacity(0.12), foregroundColor: color),
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        ),
      );
}
