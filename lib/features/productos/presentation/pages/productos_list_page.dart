import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../marcas/data/models/marcas_response_model.dart';
import '../../../marcas/presentation/providers/marcas_provider.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../../sucursales/presentation/providers/sucursales_provider.dart';
import '../../../tipos_producto/data/models/tipos_producto_response_model.dart';
import '../../../tipos_producto/presentation/providers/tipos_producto_provider.dart';
import '../../data/models/productos_response_model.dart';
import '../providers/productos_provider.dart';

class ProductosListPage extends ConsumerStatefulWidget {
  const ProductosListPage({super.key});

  @override
  ConsumerState<ProductosListPage> createState() => _ProductosListPageState();
}

class _ProductosListPageState extends ConsumerState<ProductosListPage> {
  final _searchController = TextEditingController();
  int? _selectedTipoId;
  int? _selectedMarcaId;
  int? _selectedSucursalId;
  bool _gridView = true;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(productosPagedProvider.notifier).load(page: 0, query: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final state = ref.watch(productosPagedProvider);
    final marcasState = ref.watch(marcasProvider);
    final tiposState = ref.watch(tiposproductoProvider);
    final sucursalesState = ref.watch(sucursalesProvider);
    final notifier = ref.read(productosPagedProvider.notifier);
    final items = state.items;

    final lowStock = items.where((item) => (item.inventarioActual ?? 0) <= 5).length;
    final outOfStock = items.where((item) => (item.inventarioActual ?? 0) <= 0).length;
    final expiringSoon = items.where((item) => _expiresWithinDays(item.prodFechaVencimiento, 30)).length;
    final salesYesterday = items.fold<double>(0, (sum, item) => sum + (item.ventasAyer ?? 0));
    final hasFilters = _searchController.text.trim().isNotEmpty ||
        _selectedTipoId != null ||
        _selectedMarcaId != null ||
        _selectedSucursalId != null;

    Widget content;
    if (state.loading && items.isEmpty) {
      content = const AppLoader();
    } else if (state.failure != null && items.isEmpty) {
      content = AppErrorView(
        message: state.failure!.message,
        onRetry: notifier.load,
      );
    } else if (items.isEmpty) {
      content = AppEmptyView(
        message: hasFilters
            ? 'No encontramos productos con los filtros aplicados.'
            : 'Aún no hay productos registrados.',
      );
    } else {
      content = _ProductosResults(
        items: items,
        marcas: marcasState.items,
        tipos: tiposState.items,
        sucursales: sucursalesState.items,
        palette: palette,
        gridView: _gridView,
        onDelete: (id) => _deleteProduct(context, id),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        onPressed: () => context.go('/productos/nuevo'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo producto'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: notifier.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ProductosHeader(
                    total: state.totalElements,
                    visible: items.length,
                    lowStock: lowStock,
                    outOfStock: outOfStock,
                    expiringSoon: expiringSoon,
                    salesYesterday: salesYesterday,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    tipos: tiposState.items,
                    marcas: marcasState.items,
                    sucursales: sucursalesState.items,
                    selectedTipoId: _selectedTipoId,
                    selectedMarcaId: _selectedMarcaId,
                    selectedSucursalId: _selectedSucursalId,
                    sortOption: state.sortOption,
                    gridView: _gridView,
                    onTipoChanged: (value) {
                      setState(() => _selectedTipoId = value);
                      notifier.load(page: 0, tipoId: value, clearTipoId: value == null);
                    },
                    onMarcaChanged: (value) {
                      setState(() => _selectedMarcaId = value);
                      notifier.load(page: 0, marcaId: value, clearMarcaId: value == null);
                    },
                    onSucursalChanged: (value) {
                      setState(() => _selectedSucursalId = value);
                      notifier.load(page: 0, sucursalId: value, clearSucursalId: value == null);
                    },
                    onSortChanged: (value) {
                      if (value == null) return;
                      notifier.load(page: 0, sortOption: value);
                    },
                    onViewChanged: (grid) => setState(() => _gridView = grid),
                    onClearFilters: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      setState(() {
                        _selectedTipoId = null;
                        _selectedMarcaId = null;
                        _selectedSucursalId = null;
                      });
                      notifier.load(
                        page: 0,
                        query: '',
                        clearTipoId: true,
                        clearMarcaId: true,
                        clearSucursalId: true,
                        sortOption: ProductosSortOption.nombreAsc,
                      );
                    },
                    onRefresh: notifier.refresh,
                    palette: palette,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProductosPaginationBar(
                    page: state.page,
                    size: state.size,
                    totalElements: state.totalElements,
                    totalPages: state.totalPages,
                    first: state.first,
                    last: state.last,
                    loading: state.loading,
                    palette: palette,
                    onPrevious: notifier.previousPage,
                    onNext: notifier.nextPage,
                    onSizeChanged: notifier.changeSize,
                  ),
                ),
                SliverToBoxAdapter(child: content),
                if (state.loading && items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LinearProgressIndicator(
                        color: palette.secondary,
                        backgroundColor: palette.surface,
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

  Future<void> _deleteProduct(BuildContext context, Object id) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Eliminar o inactivar producto',
      message: '¿Deseas eliminar o inactivar este producto?',
    );
    if (!confirmed) return;

    final ok = await ref.read(productosPagedProvider.notifier).remove(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Producto procesado correctamente' : 'No fue posible procesar el producto',
        ),
      ),
    );
  }
}

class _ProductosHeader extends StatelessWidget {
  const _ProductosHeader({
    required this.total,
    required this.visible,
    required this.lowStock,
    required this.outOfStock,
    required this.expiringSoon,
    required this.salesYesterday,
    required this.controller,
    required this.onChanged,
    required this.tipos,
    required this.marcas,
    required this.sucursales,
    required this.selectedTipoId,
    required this.selectedMarcaId,
    required this.selectedSucursalId,
    required this.sortOption,
    required this.gridView,
    required this.onTipoChanged,
    required this.onMarcaChanged,
    required this.onSucursalChanged,
    required this.onSortChanged,
    required this.onViewChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.palette,
  });

  final int total;
  final int visible;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;
  final double salesYesterday;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<TiposProductoResponseModel> tipos;
  final List<MarcasResponseModel> marcas;
  final List<SucursalesResponseModel> sucursales;
  final int? selectedTipoId;
  final int? selectedMarcaId;
  final int? selectedSucursalId;
  final ProductosSortOption sortOption;
  final bool gridView;
  final ValueChanged<int?> onTipoChanged;
  final ValueChanged<int?> onMarcaChanged;
  final ValueChanged<int?> onSucursalChanged;
  final ValueChanged<ProductosSortOption?> onSortChanged;
  final ValueChanged<bool> onViewChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final title = Row(
                children: [
                  Container(
                    width: compact ? 52 : 60,
                    height: compact ? 52 : 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: palette.cardShadow,
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: palette.onTitle,
                      size: compact ? 27 : 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catálogo de productos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inventario, ventas, vencimientos y clasificación en una sola vista.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CounterPill(label: '$visible / $total'),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    tooltip: 'Actualizar',
                    icon: Icons.refresh_rounded,
                    onPressed: onRefresh,
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(children: [Expanded(child: title), const SizedBox(width: 16), actions]);
            },
          ),
          const SizedBox(height: 16),
          _CatalogSummary(
            palette: palette,
            visible: visible,
            lowStock: lowStock,
            outOfStock: outOfStock,
            expiringSoon: expiringSoon,
            salesYesterday: salesYesterday,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.97),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: palette.cardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final columns = constraints.maxWidth >= 1180
                    ? 4
                    : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _SearchField(
                        controller: controller,
                        onChanged: onChanged,
                        palette: palette,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _HeaderDropdown<int?>(
                        label: 'Tipo de producto',
                        value: selectedTipoId,
                        palette: palette,
                        icon: Icons.category_rounded,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Todos los tipos')),
                          ...tipos.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.tpprId,
                              child: Text(item.tpprNombre ?? 'Tipo ${item.tpprId ?? '-'}'),
                            ),
                          ),
                        ],
                        onChanged: onTipoChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _HeaderDropdown<int?>(
                        label: 'Marca',
                        value: selectedMarcaId,
                        palette: palette,
                        icon: Icons.sell_rounded,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Todas las marcas')),
                          ...marcas.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.mrcaId,
                              child: Text(item.mrcaNombre ?? 'Marca ${item.mrcaId ?? '-'}'),
                            ),
                          ),
                        ],
                        onChanged: onMarcaChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _HeaderDropdown<int?>(
                        label: 'Sucursal',
                        value: selectedSucursalId,
                        palette: palette,
                        icon: Icons.storefront_rounded,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Todas las sucursales')),
                          ...sucursales.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.sucuId,
                              child: Text(item.sucuNombre ?? 'Sucursal ${item.sucuId ?? '-'}'),
                            ),
                          ),
                        ],
                        onChanged: onSucursalChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _HeaderDropdown<ProductosSortOption>(
                        label: 'Ordenar por',
                        value: sortOption,
                        palette: palette,
                        icon: Icons.swap_vert_rounded,
                        items: ProductosSortOption.values
                            .map(
                              (item) => DropdownMenuItem<ProductosSortOption>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: onSortChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _ViewSelector(
                        gridView: gridView,
                        palette: palette,
                        onChanged: onViewChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _ClearButton(
                        palette: palette,
                        onPressed: onClearFilters,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSummary extends StatelessWidget {
  const _CatalogSummary({
    required this.palette,
    required this.visible,
    required this.lowStock,
    required this.outOfStock,
    required this.expiringSoon,
    required this.salesYesterday,
  });

  final AppPalette palette;
  final int visible;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;
  final double salesYesterday;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CatalogMetric(icon: Icons.view_module_rounded, label: 'En esta página', value: '$visible', color: palette.secondary),
      _CatalogMetric(icon: Icons.inventory_2_outlined, label: 'Stock bajo', value: '$lowStock', color: palette.primary),
      _CatalogMetric(icon: Icons.remove_shopping_cart_rounded, label: 'Sin stock', value: '$outOfStock', color: Colors.redAccent),
      _CatalogMetric(icon: Icons.event_busy_rounded, label: 'Vencen en 30 días', value: '$expiringSoon', color: palette.secondary),
      _CatalogMetric(icon: Icons.trending_up_rounded, label: 'Unidades ayer', value: _formatNumber(salesYesterday), color: Colors.greenAccent.shade400),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 720
                ? 3
                : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _CatalogMetricCard(metric: card, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _CatalogMetric {
  const _CatalogMetric({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _CatalogMetricCard extends StatelessWidget {
  const _CatalogMetricCard({required this.metric, required this.palette});

  final _CatalogMetric metric;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.palette});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: 'Buscar nombre, descripción, marca o tipo',
        hintStyle: TextStyle(color: palette.textSecondary),
        prefixIcon: Icon(Icons.search_rounded, color: palette.secondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.72),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.secondary, width: 1.4)),
      ),
    );
  }
}

class _HeaderDropdown<T> extends StatelessWidget {
  const _HeaderDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.palette,
    required this.icon,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: palette.secondary),
          const SizedBox(width: 9),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: palette.surface,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
                hint: Text(label, style: TextStyle(color: palette.textSecondary)),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.gridView, required this.palette, required this.onChanged});

  final bool gridView;
  final AppPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ViewOption(
              active: gridView,
              icon: Icons.grid_view_rounded,
              label: 'Tarjetas',
              palette: palette,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ViewOption(
              active: !gridView,
              icon: Icons.view_list_rounded,
              label: 'Lista',
              palette: palette,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewOption extends StatelessWidget {
  const _ViewOption({
    required this.active,
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? palette.secondary.withOpacity(0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? palette.secondary : palette.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? palette.secondary : palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.palette, required this.onPressed});

  final AppPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.secondary,
          side: BorderSide(color: palette.secondary.withOpacity(0.24)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.filter_alt_off_rounded),
        label: const Text('Limpiar filtros', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _ProductosPaginationBar extends StatelessWidget {
  const _ProductosPaginationBar({
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
    required this.loading,
    required this.palette,
    required this.onPrevious,
    required this.onNext,
    required this.onSizeChanged,
  });

  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final bool loading;
  final AppPalette palette;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final currentPage = totalPages == 0 ? 0 : page + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalElements productos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Página $currentPage de $totalPages',
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            );
            final controls = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _PageSizeDropdown(value: size, palette: palette, onChanged: onSizeChanged),
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed: loading || first ? null : onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton.filled(
                  tooltip: 'Página siguiente',
                  onPressed: loading || last ? null : onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 10), controls],
              );
            }
            return Row(children: [Expanded(child: summary), controls]);
          },
        ),
      ),
    );
  }
}

class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({required this.value, required this.palette, required this.onChanged});

  final int value;
  final AppPalette palette;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: palette.surface,
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
          items: const [10, 20, 50, 100]
              .map((item) => DropdownMenuItem<int>(value: item, child: Text('$item por página')))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _ProductosResults extends StatelessWidget {
  const _ProductosResults({
    required this.items,
    required this.marcas,
    required this.tipos,
    required this.sucursales,
    required this.palette,
    required this.gridView,
    required this.onDelete,
  });

  final List<ProductosResponseModel> items;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final List<SucursalesResponseModel> sucursales;
  final AppPalette palette;
  final bool gridView;
  final ValueChanged<Object> onDelete;

  @override
  Widget build(BuildContext context) {
    if (!gridView) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _ProductoListRow(
                    item: items[index],
                    palette: palette,
                    brandName: _brandName(marcas, items[index]),
                    typeName: _typeName(tipos, items[index]),
                    sucursalName: _sucursalName(sucursales, items[index]),
                    last: index == items.length - 1,
                    onDelete: onDelete,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 16.0;
        const spacing = 14.0;
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final columns = math.max(1, (availableWidth / 320).floor()).clamp(1, 6);
        final cardWidth = (availableWidth - (spacing * (columns - 1))) / columns;

        return Padding(
          padding: const EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 100),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: cardWidth,
                  child: _ProductoCard(
                    item: item,
                    palette: palette,
                    brandName: _brandName(marcas, item),
                    typeName: _typeName(tipos, item),
                    sucursalName: _sucursalName(sucursales, item),
                    onDelete: onDelete,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _brandName(List<MarcasResponseModel> values, ProductosResponseModel item) =>
      _firstOrNull(values.where((element) => element.mrcaId == item.mrcaId))?.mrcaNombre ?? 'Marca no definida';

  String _typeName(List<TiposProductoResponseModel> values, ProductosResponseModel item) =>
      _firstOrNull(values.where((element) => element.tpprId == item.tpprId))?.tpprNombre ?? 'Tipo no definido';

  String _sucursalName(List<SucursalesResponseModel> values, ProductosResponseModel item) =>
      _firstOrNull(values.where((element) => element.sucuId == item.sucuId))?.sucuNombre ?? 'Sucursal ${item.sucuId ?? '-'}';
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({
    required this.item,
    required this.palette,
    required this.brandName,
    required this.typeName,
    required this.sucursalName,
    required this.onDelete,
  });

  final ProductosResponseModel item;
  final AppPalette palette;
  final String brandName;
  final String typeName;
  final String sucursalName;
  final ValueChanged<Object> onDelete;

  @override
  Widget build(BuildContext context) {
    final id = item.prodId;
    final title = (item.prodNombre ?? '').trim().isEmpty ? 'Producto sin nombre' : item.prodNombre!.trim();
    final description = (item.prodDescripcion ?? '').trim();
    final stock = item.inventarioActual ?? 0;
    final stockStatus = _stockStatus(stock, palette);
    final expiryStatus = _expiryStatus(item.prodFechaVencimiento, palette);

    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: id == null ? null : () => context.go('/productos/$id'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.55), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _ProductImage(value: item.prodFoto, height: 174, palette: palette),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _StatusBadge(
                      icon: stockStatus.icon,
                      label: stockStatus.label,
                      color: stockStatus.color,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      color: palette.surface,
                      onSelected: (value) {
                        if (id == null) return;
                        if (value == 'detail') context.go('/productos/$id');
                        if (value == 'edit') context.go('/productos/$id/editar');
                        if (value == 'delete') onDelete(id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'detail', child: Text('Ver producto')),
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar/Inactivar')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: palette.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$brandName · $typeName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description.isEmpty ? 'Sin descripción registrada.' : description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 14),
              _ProductMetrics(
                palette: palette,
                stock: stock,
                salesYesterday: item.ventasAyer ?? 0,
                expiry: expiryStatus,
              ),
              const SizedBox(height: 12),
              _ProductChip(icon: Icons.storefront_rounded, label: sucursalName, palette: palette),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: id == null ? null : () => context.go('/productos/$id'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.secondary,
                        side: BorderSide(color: palette.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Ver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: id == null ? null : () => context.go('/productos/$id/editar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.actionColor,
                        foregroundColor: palette.onAction,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductoListRow extends StatelessWidget {
  const _ProductoListRow({
    required this.item,
    required this.palette,
    required this.brandName,
    required this.typeName,
    required this.sucursalName,
    required this.last,
    required this.onDelete,
  });

  final ProductosResponseModel item;
  final AppPalette palette;
  final String brandName;
  final String typeName;
  final String sucursalName;
  final bool last;
  final ValueChanged<Object> onDelete;

  @override
  Widget build(BuildContext context) {
    final id = item.prodId;
    final stock = item.inventarioActual ?? 0;
    final status = _stockStatus(stock, palette);
    final expiry = _expiryStatus(item.prodFechaVencimiento, palette);
    final title = (item.prodNombre ?? '').trim().isEmpty ? 'Producto sin nombre' : item.prodNombre!.trim();

    return InkWell(
      onTap: id == null ? null : () => context.go('/productos/$id'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final mainInfo = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(value: item.prodFoto, width: compact ? 74 : 86, height: compact ? 74 : 86, palette: palette),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(icon: status.icon, label: status.label, color: status.color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$brandName · $typeName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (item.prodDescripcion ?? '').trim().isEmpty ? 'Sin descripción registrada.' : item.prodDescripcion!.trim(),
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        sucursalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final metrics = _ProductMetrics(
              palette: palette,
              stock: stock,
              salesYesterday: item.ventasAyer ?? 0,
              expiry: expiry,
              compact: true,
            );

            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: 'Ver producto',
                  onPressed: id == null ? null : () => context.go('/productos/$id'),
                  icon: const Icon(Icons.visibility_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Editar producto',
                  onPressed: id == null ? null : () => context.go('/productos/$id/editar'),
                  icon: const Icon(Icons.edit_rounded),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Eliminar o inactivar',
                  onPressed: id == null ? null : () => onDelete(id),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  mainInfo,
                  const SizedBox(height: 12),
                  metrics,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 5, child: mainInfo),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: metrics),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductMetrics extends StatelessWidget {
  const _ProductMetrics({
    required this.palette,
    required this.stock,
    required this.salesYesterday,
    required this.expiry,
    this.compact = false,
  });

  final AppPalette palette;
  final num stock;
  final num salesYesterday;
  final _ExpiryStatus expiry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(icon: Icons.inventory_rounded, label: 'Inventario', value: _formatNumber(stock), color: palette.secondary),
      _Metric(icon: Icons.trending_up_rounded, label: 'Venta ayer', value: _formatNumber(salesYesterday), color: Colors.greenAccent.shade400),
      _Metric(icon: expiry.icon, label: 'Vencimiento', value: expiry.label, color: expiry.color),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 320 && !compact;
        if (stacked) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                _MetricTile(metric: cards[index], palette: palette),
                if (index < cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: _MetricTile(metric: cards[index], palette: palette)),
              if (index < cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.palette});

  final _Metric metric;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.045) : palette.background.withOpacity(0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 17, color: metric.color),
          const SizedBox(height: 5),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
          ),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.value,
    required this.height,
    required this.palette,
    this.width = double.infinity,
  });

  final String? value;
  final double width;
  final double height;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final imageValue = (value ?? '').trim();
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.secondary.withOpacity(0.16), palette.primary.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Icon(Icons.local_bar_rounded, color: palette.secondary, size: 38),
    );

    if (imageValue.isEmpty) return placeholder;

    Widget image;
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex < 0) return placeholder;
      try {
        image = Image.memory(
          base64Decode(imageValue.substring(commaIndex + 1)),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(
        imageValue,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return ClipRRect(borderRadius: BorderRadius.circular(22), child: image);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.icon, required this.label, required this.palette});

  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.05) : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.secondary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockStatus {
  const _StockStatus({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

class _ExpiryStatus {
  const _ExpiryStatus({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

_StockStatus _stockStatus(num stock, AppPalette palette) {
  if (stock <= 0) {
    return const _StockStatus(label: 'Sin stock', icon: Icons.remove_shopping_cart_rounded, color: Colors.redAccent);
  }
  if (stock <= 5) {
    return _StockStatus(label: 'Stock bajo', icon: Icons.inventory_2_outlined, color: palette.primary);
  }
  return _StockStatus(label: 'Disponible', icon: Icons.check_circle_rounded, color: Colors.greenAccent.shade400);
}

_ExpiryStatus _expiryStatus(String? value, AppPalette palette) {
  final date = _parseDate(value);
  if (date == null) {
    return _ExpiryStatus(label: 'No aplica', icon: Icons.event_available_rounded, color: palette.textSecondary);
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;
  if (days < 0) {
    return const _ExpiryStatus(label: 'Vencido', icon: Icons.event_busy_rounded, color: Colors.redAccent);
  }
  if (days <= 30) {
    return _ExpiryStatus(label: '$days días', icon: Icons.schedule_rounded, color: palette.primary);
  }
  return _ExpiryStatus(label: _shortDate(value), icon: Icons.event_rounded, color: palette.secondary);
}

bool _expiresWithinDays(String? value, int days) {
  final date = _parseDate(value);
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;
  return difference >= 0 && difference <= days;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

String _formatNumber(num? value) {
  if (value == null) return '0';
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _shortDate(String? value) {
  final parsed = _parseDate(value);
  if (parsed == null) return '-';
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
