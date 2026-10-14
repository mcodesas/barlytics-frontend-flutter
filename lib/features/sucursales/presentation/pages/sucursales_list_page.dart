import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/sucursales_response_model.dart';
import 'sucursales_form_page.dart';
import '../sucursales_view_data.dart';

enum _SucursalStatusFilter { todas, activas, inactivas }

class SucursalesListPage extends ConsumerStatefulWidget {
  const SucursalesListPage({super.key});

  @override
  ConsumerState<SucursalesListPage> createState() => _SucursalesListPageState();
}

class _SucursalesListPageState extends ConsumerState<SucursalesListPage> {
  static const int _pageSize = 9;

  final TextEditingController _searchController = TextEditingController();
  List<SucursalesResponseModel> _items = const <SucursalesResponseModel>[];
  SucursalCatalogs _catalogs = const SucursalCatalogs();
  _SucursalStatusFilter _statusFilter = _SucursalStatusFilter.todas;
  int? _empresaFilter;
  int _page = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditSheet(SucursalesResponseModel item) async {
    final id = item.sucuId;
    if (id == null) return;
    final palette = ref.read(selectedAppPaletteProvider);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final height = math.max(420.0, media.size.height * 0.94 - media.viewInsets.bottom).toDouble();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              constraints: const BoxConstraints(maxWidth: 1220),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, -10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(child: SucursalesFormPage(id: id.toString(), embedded: true)),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _openCreateSheet() async {
    final palette = ref.read(selectedAppPaletteProvider);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final height = math.max(420.0, media.size.height * 0.94 - media.viewInsets.bottom).toDouble();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              constraints: const BoxConstraints(maxWidth: 1220),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, -10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(child: SucursalesFormPage(embedded: true)),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final listFuture = apiClient.get<List<SucursalesResponseModel>>(
        ApiPaths.sucursales,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => SucursalesResponseModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      final catalogsFuture = SucursalCatalogs.load(apiClient);
      final response = await listFuture;
      final catalogs = await catalogsFuture;

      if (!mounted) return;
      setState(() {
        _items = response.data ?? const <SucursalesResponseModel>[];
        _catalogs = catalogs;
        _page = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SucursalesResponseModel> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      final active = item.sucuEstado == 1;
      if (_statusFilter == _SucursalStatusFilter.activas && !active) return false;
      if (_statusFilter == _SucursalStatusFilter.inactivas && active) return false;
      if (_empresaFilter != null && item.emprId != _empresaFilter) return false;

      if (query.isEmpty) return true;
      final searchable = <String>[
        item.sucuNombre ?? '',
        item.sucuCodigoInterno ?? '',
        item.sucuDireccion ?? '',
        item.sucuTelefono ?? '',
        _catalogs.empresa(item.emprId),
        _catalogs.ciudad(item.ciudId),
        _catalogs.moneda(item.moneId),
        _catalogs.zona(item.zohoId),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final activeComparison = (b.sucuEstado == 1 ? 1 : 0).compareTo(a.sucuEstado == 1 ? 1 : 0);
      if (activeComparison != 0) return activeComparison;
      return (a.sucuNombre ?? '').toLowerCase().compareTo((b.sucuNombre ?? '').toLowerCase());
    });
    return filtered;
  }

  List<SucursalesResponseModel> get _currentPageItems {
    final items = _filteredItems;
    if (items.isEmpty) return const <SucursalesResponseModel>[];
    final maxPage = math.max(0, ((items.length - 1) / _pageSize).floor()).toInt();
    final page = _page.clamp(0, maxPage).toInt();
    final start = page * _pageSize;
    final end = math.min(start + _pageSize, items.length);
    return items.sublist(start, end);
  }

  void _resetPage() {
    if (_page != 0) _page = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final filtered = _filteredItems;
    final pageItems = _currentPageItems;
    final active = _items.where((item) => item.sucuEstado == 1).length;
    final inactive = _items.length - active;
    final companies = _items.map((item) => item.emprId).whereType<int>().toSet().length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sucursales-nueva-fab',
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        onPressed: _loading ? null : _openCreateSheet,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Nueva sucursal'),
      ),
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
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Header(
                          palette: palette,
                          active: active,
                          inactive: inactive,
                          loading: _loading,
                          onRefresh: _load,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Metrics(
                          palette: palette,
                          total: _items.length,
                          active: active,
                          inactive: inactive,
                          companies: companies,
                          selected: _statusFilter,
                          onSelected: (filter) {
                            _statusFilter = filter;
                            _resetPage();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Filters(
                          palette: palette,
                          controller: _searchController,
                          empresaId: _empresaFilter,
                          empresas: _catalogs.empresas,
                          hasActiveFilters: _statusFilter != _SucursalStatusFilter.todas || _empresaFilter != null || _searchController.text.trim().isNotEmpty,
                          onSearch: (_) => _resetPage(),
                          onEmpresaChanged: (value) {
                            _empresaFilter = value;
                            _resetPage();
                          },
                          onClear: () {
                            _searchController.clear();
                            _empresaFilter = null;
                            _statusFilter = _SucursalStatusFilter.todas;
                            _resetPage();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppLoader(message: 'Cargando sucursales...'),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      palette: palette,
                      message: _error!,
                      onRetry: _load,
                    ),
                  )
                else if (pageItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      palette: palette,
                      filtered: _items.isNotEmpty,
                      onCreate: _openCreateSheet,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 1050
                                      ? 3
                                      : constraints.maxWidth >= 680
                                          ? 2
                                          : 1;
                                  final spacing = 14.0;
                                  final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: [
                                      for (final item in pageItems)
                                        SizedBox(
                                          width: width,
                                          child: _SucursalCard(
                                            item: item,
                                            catalogs: _catalogs,
                                            palette: palette,
                                            onOpen: () => _showQuickDetail(item),
                                            onEdit: () => _openEditSheet(item),
                                            onDeactivate: () => _deactivate(item),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _Pagination(
                                palette: palette,
                                currentPage: _page,
                                totalItems: filtered.length,
                                pageSize: _pageSize,
                                onPrevious: _page > 0 ? () => setState(() => _page--) : null,
                                onNext: ((_page + 1) * _pageSize < filtered.length) ? () => setState(() => _page++) : null,
                              ),
                            ],
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

  Future<void> _deactivate(SucursalesResponseModel item) async {
    final id = item.sucuId;
    if (id == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Inactivar sucursal',
      message: 'La sucursal “${item.sucuNombre ?? item.sucuCodigoInterno ?? id}” dejará de estar disponible para nuevas operaciones. ¿Deseas continuar?',
    );
    if (!confirmed) return;

    try {
      await ref.read(apiClientProvider).delete<Object?>(
        '${ApiPaths.sucursales}/$id',
        (json) => json,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sucursal inactivada correctamente')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible inactivar la sucursal: $error')),
      );
    }
  }

  Future<void> _showQuickDetail(SucursalesResponseModel item) async {
    final palette = ref.read(selectedAppPaletteProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: palette.cardBorder)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _BranchIcon(palette: palette, active: item.sucuEstado == 1, size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.sucuNombre ?? 'Sucursal sin nombre',
                              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 21),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.sucuCodigoInterno ?? 'Sin código'} · ${_catalogs.empresa(item.emprId)}',
                              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(active: item.sucuEstado == 1, palette: palette),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailGrid(item: item, catalogs: _catalogs, palette: palette),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final edit = FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openEditSheet(item);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Modificar'),
                      );
                      final details = OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.go('/sucursales/${item.sucuId}');
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Ver ficha completa'),
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [details, const SizedBox(height: 10), edit],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 12),
                          Expanded(child: edit),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.active,
    required this.inactive,
    required this.loading,
    required this.onRefresh,
  });

  final AppPalette palette;
  final int active;
  final int inactive;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 28, tint: palette.secondary),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.storefront_rounded, color: palette.onPrimary, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administración de sucursales',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19),
                ),
                const SizedBox(height: 4),
                Text(
                  inactive == 0
                      ? 'Gestiona sedes, ubicación, moneda y disponibilidad. Solo las sucursales activas consumen cupo del plan.'
                      : '$inactive sucursal${inactive == 1 ? '' : 'es'} inactiva${inactive == 1 ? '' : 's'} conservada${inactive == 1 ? '' : 's'} como histórico; no consume${inactive == 1 ? '' : 'n'} cupo del plan.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$active activa${active == 1 ? '' : 's'}',
              style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: loading ? null : onRefresh,
            tooltip: 'Actualizar',
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.palette,
    required this.total,
    required this.active,
    required this.inactive,
    required this.companies,
    required this.selected,
    required this.onSelected,
  });

  final AppPalette palette;
  final int total;
  final int active;
  final int inactive;
  final int companies;
  final _SucursalStatusFilter selected;
  final ValueChanged<_SucursalStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
        final gap = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Todas',
                value: total,
                icon: Icons.domain_rounded,
                color: palette.secondary,
                selected: selected == _SucursalStatusFilter.todas,
                onTap: () => onSelected(_SucursalStatusFilter.todas),
                palette: palette,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Activas',
                value: active,
                icon: Icons.check_circle_rounded,
                color: palette.success,
                selected: selected == _SucursalStatusFilter.activas,
                onTap: () => onSelected(_SucursalStatusFilter.activas),
                palette: palette,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Inactivas',
                value: inactive,
                icon: Icons.pause_circle_rounded,
                color: palette.warning,
                selected: selected == _SucursalStatusFilter.inactivas,
                onTap: () => onSelected(_SucursalStatusFilter.inactivas),
                palette: palette,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Empresas',
                value: companies,
                icon: Icons.business_rounded,
                color: palette.primary,
                selected: false,
                onTap: null,
                palette: palette,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.13) : palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? color.withOpacity(0.62) : palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
                    Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.palette,
    required this.controller,
    required this.empresaId,
    required this.empresas,
    required this.hasActiveFilters,
    required this.onSearch,
    required this.onEmpresaChanged,
    required this.onClear,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final int? empresaId;
  final Map<int, String> empresas;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearch;
  final ValueChanged<int?> onEmpresaChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final sortedCompanies = empresas.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: palette.panelDecoration(baseRadius: 24, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: controller,
            onChanged: onSearch,
            decoration: InputDecoration(
              labelText: 'Buscar sucursal',
              hintText: 'Nombre, código, empresa, ciudad o teléfono',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          final company = DropdownButtonFormField<int?>(
            value: empresaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Empresa',
              prefixIcon: Icon(Icons.business_rounded),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas las empresas')),
              for (final entry in sortedCompanies)
                DropdownMenuItem<int?>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onEmpresaChanged,
          );
          final clear = IconButton.filledTonal(
            onPressed: hasActiveFilters ? onClear : null,
            tooltip: 'Limpiar filtros',
            icon: const Icon(Icons.filter_alt_off_rounded),
          );

          if (compact) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: company),
                    const SizedBox(width: 8),
                    clear,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: company),
              const SizedBox(width: 8),
              clear,
            ],
          );
        },
      ),
    );
  }
}

class _SucursalCard extends StatelessWidget {
  const _SucursalCard({
    required this.item,
    required this.catalogs,
    required this.palette,
    required this.onOpen,
    required this.onEdit,
    required this.onDeactivate,
  });

  final SucursalesResponseModel item;
  final SucursalCatalogs catalogs;
  final AppPalette palette;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final active = item.sucuEstado == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: palette.panelDecoration(baseRadius: 25, tint: active ? palette.secondary : palette.warning),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BranchIcon(palette: palette, active: active, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.sucuNombre ?? 'Sucursal sin nombre',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16.5, height: 1.15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.sucuCodigoInterno ?? 'Sin código interno',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (value) {
                      if (value == 'open') onOpen();
                      if (value == 'edit') onEdit();
                      if (value == 'deactivate') onDeactivate();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.visibility_rounded), title: Text('Consultar'), contentPadding: EdgeInsets.zero)),
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Modificar'), contentPadding: EdgeInsets.zero)),
                      if (active)
                        const PopupMenuItem(value: 'deactivate', child: ListTile(leading: Icon(Icons.pause_circle_rounded), title: Text('Inactivar'), contentPadding: EdgeInsets.zero)),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _StatusChip(active: active, palette: palette),
              const SizedBox(height: 13),
              _InfoLine(icon: Icons.business_rounded, text: catalogs.empresa(item.emprId), palette: palette),
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.location_on_rounded, text: catalogs.ciudad(item.ciudId), palette: palette),
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.phone_rounded, text: item.sucuTelefono?.trim().isNotEmpty == true ? item.sucuTelefono! : 'Sin teléfono', palette: palette),
              const SizedBox(height: 8),
              _InfoLine(icon: Icons.payments_rounded, text: catalogs.moneda(item.moneId), palette: palette),
              const SizedBox(height: 14),
              Divider(color: palette.cardBorder, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.sucuDireccion?.trim().isNotEmpty == true ? item.sucuDireccion! : 'Dirección no registrada',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: palette.secondary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchIcon extends StatelessWidget {
  const _BranchIcon({required this.palette, required this.active, required this.size});

  final AppPalette palette;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.secondary : palette.warning;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.92), palette.primary.withOpacity(0.86)]),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(Icons.storefront_rounded, color: Colors.white, size: size * 0.54),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active, required this.palette});

  final bool active;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.success : palette.warning;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(active ? 'Sucursal activa' : 'Sucursal inactiva', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, required this.palette});

  final IconData icon;
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.item, required this.catalogs, required this.palette});

  final SucursalesResponseModel item;
  final SucursalCatalogs catalogs;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final details = <({IconData icon, String label, String value})>[
      (icon: Icons.business_rounded, label: 'Empresa', value: catalogs.empresa(item.emprId)),
      (icon: Icons.location_city_rounded, label: 'Ciudad', value: catalogs.ciudad(item.ciudId)),
      (icon: Icons.location_on_rounded, label: 'Dirección', value: item.sucuDireccion ?? 'Sin dirección'),
      (icon: Icons.phone_rounded, label: 'Teléfono', value: item.sucuTelefono ?? 'Sin teléfono'),
      (icon: Icons.payments_rounded, label: 'Moneda', value: catalogs.moneda(item.moneId)),
      (icon: Icons.schedule_rounded, label: 'Zona horaria', value: catalogs.zona(item.zohoId)),
      (icon: Icons.flag_rounded, label: 'País teléfono', value: catalogs.pais(item.paisIdtelefono)),
      (icon: Icons.badge_rounded, label: 'Código interno', value: item.sucuCodigoInterno ?? 'Sin código'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final spacing = 10.0;
        final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final detail in details)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(detail.icon, color: palette.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11.5)),
                            const SizedBox(height: 2),
                            Text(detail.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, height: 1.2)),
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
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.palette,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final AppPalette palette;
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pages = math.max(1, (totalItems / pageSize).ceil()).toInt();
    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = math.min((currentPage + 1) * pageSize, totalItems);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: onPrevious, tooltip: 'Página anterior', icon: const Icon(Icons.chevron_left_rounded)),
          Flexible(
            child: Text(
              '$start-$end de $totalItems · Página ${currentPage + 1} de $pages',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
          IconButton(onPressed: onNext, tooltip: 'Página siguiente', icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette, required this.filtered, required this.onCreate});

  final AppPalette palette;
  final bool filtered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filtered ? Icons.search_off_rounded : Icons.add_business_rounded, size: 58, color: palette.secondary),
            const SizedBox(height: 14),
            Text(
              filtered ? 'No hay sucursales con esos filtros' : 'Todavía no hay sucursales registradas',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              filtered ? 'Ajusta la búsqueda o limpia los filtros.' : 'Crea la primera sede para empezar a operar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
            ),
            if (!filtered) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Crear sucursal')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.palette, required this.message, required this.onRetry});

  final AppPalette palette;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 58, color: palette.warning),
            const SizedBox(height: 14),
            Text('No fue posible cargar las sucursales', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
