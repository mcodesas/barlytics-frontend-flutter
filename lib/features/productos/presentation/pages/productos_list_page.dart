
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

  List<ProductosResponseModel> _filter(
    List<ProductosResponseModel> items,
    List<MarcasResponseModel> marcas,
    List<TiposProductoResponseModel> tipos,
    List<SucursalesResponseModel> sucursales,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      final marca = _firstOrNull(marcas.where((m) => m.mrcaId == item.mrcaId));
      final tipo = _firstOrNull(tipos.where((t) => t.tpprId == item.tpprId));
      final sucursal = _firstOrNull(sucursales.where((s) => s.sucuId == item.sucuId));

      final matchesTipo = _selectedTipoId == null || item.tpprId == _selectedTipoId;
      final matchesMarca = _selectedMarcaId == null || item.mrcaId == _selectedMarcaId;
      final text = [
        item.prodNombre,
        item.prodDescripcion,
        item.prodFechaVencimiento,
        marca?.mrcaNombre,
        tipo?.tpprNombre,
        sucursal?.sucuNombre,
      ].whereType<Object>().join(' ').toLowerCase();
      final matchesText = query.isEmpty || text.contains(query);

      return matchesTipo && matchesMarca && matchesText;
    }).toList();
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

    Widget content;
    if (state.loading && state.items.isEmpty) {
      content = const AppLoader();
    } else if (state.failure != null) {
      content = AppErrorView(
        message: state.failure!.message,
        onRetry: notifier.load,
      );
    } else if (state.items.isEmpty) {
      final hasFilters = state.query.trim().isNotEmpty || state.tipoId != null || state.marcaId != null;
      content = AppEmptyView(
        message: hasFilters
            ? 'No encontramos productos con ese filtro.'
            : 'Aún no hay productos registrados.',
      );
    } else {
      content = _ProductosCardGrid(
        items: items,
        marcas: marcasState.items,
        tipos: tiposState.items,
        sucursales: sucursalesState.items,
        palette: palette,
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
        label: const Text('Producto'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: notifier.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProductosHeader(
                    total: state.totalElements,
                    visible: items.length,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    tipos: tiposState.items,
                    marcas: marcasState.items,
                    selectedTipoId: _selectedTipoId,
                    selectedMarcaId: _selectedMarcaId,
                    sortOption: state.sortOption,
                    onTipoChanged: (value) {
                      setState(() => _selectedTipoId = value);
                      notifier.load(page: 0, tipoId: value, clearTipoId: value == null);
                    },
                    onMarcaChanged: (value) {
                      setState(() => _selectedMarcaId = value);
                      notifier.load(page: 0, marcaId: value, clearMarcaId: value == null);
                    },
                    onSortChanged: (value) {
                      if (value == null) return;
                      notifier.load(page: 0, sortOption: value);
                    },
                    onClearFilters: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      setState(() {
                        _selectedTipoId = null;
                        _selectedMarcaId = null;
                      });
                      notifier.load(
                        page: 0,
                        query: '',
                        clearTipoId: true,
                        clearMarcaId: true,
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
          ok
              ? 'Producto procesado correctamente'
              : 'No fue posible procesar el producto',
        ),
      ),
    );
  }
}

class _ProductosHeader extends StatelessWidget {
  const _ProductosHeader({
    required this.total,
    required this.visible,
    required this.controller,
    required this.onChanged,
    required this.tipos,
    required this.marcas,
    required this.selectedTipoId,
    required this.selectedMarcaId,
    required this.sortOption,
    required this.onTipoChanged,
    required this.onMarcaChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.palette,
  });

  final int total;
  final int visible;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<TiposProductoResponseModel> tipos;
  final List<MarcasResponseModel> marcas;
  final int? selectedTipoId;
  final int? selectedMarcaId;
  final ProductosSortOption sortOption;
  final ValueChanged<int?> onTipoChanged;
  final ValueChanged<int?> onMarcaChanged;
  final ValueChanged<ProductosSortOption?> onSortChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: palette.mainGradient,
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
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta, filtra y administra productos de forma rápida.',
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
              _CounterPill(label: '$visible / $total'),
              const SizedBox(width: 8),
              _HeaderIconButton(
                tooltip: 'Actualizar',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                final columns = constraints.maxWidth >= 1080
                    ? 4
                    : constraints.maxWidth >= 720
                        ? 2
                        : 1;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
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
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todos los tipos'),
                          ),
                          ...tipos.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.tpprId,
                              child: Text(
                                item.tpprNombre ??
                                    'Tipo ${item.tpprId ?? '-'}',
                              ),
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
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas las marcas'),
                          ),
                          ...marcas.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.mrcaId,
                              child: Text(
                                item.mrcaNombre ??
                                    'Marca ${item.mrcaId ?? '-'}',
                              ),
                            ),
                          ),
                        ],
                        onChanged: onMarcaChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _HeaderDropdown<ProductosSortOption>(
                        label: 'Ordenar por',
                        value: sortOption,
                        palette: palette,
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.palette,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o descripción',
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
        fillColor: palette.darkBackground
            ? Colors.white.withOpacity(0.04)
            : palette.background.withOpacity(0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.secondary, width: 1.4),
        ),
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
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.04)
            : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: palette.surface,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          hint: Text(
            label,
            style: TextStyle(color: palette.textSecondary),
          ),
          items: items,
          onChanged: onChanged,
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
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.secondary, palette.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text(
            'Limpiar filtros',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}


class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

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
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
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
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final summary = Text(
              '$totalElements productos · Página $currentPage de $totalPages',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            );
            final controls = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _PageSizeDropdown(value: size, palette: palette, onChanged: onSizeChanged),
                OutlinedButton.icon(
                  onPressed: loading || first ? null : onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Anterior'),
                ),
                FilledButton.icon(
                  onPressed: loading || last ? null : onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Siguiente'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 10), controls],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                controls,
              ],
            );
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

class _ProductosCardGrid extends StatelessWidget {
  const _ProductosCardGrid({
    required this.items,
    required this.marcas,
    required this.tipos,
    required this.sucursales,
    required this.palette,
    required this.onDelete,
  });

  final List<ProductosResponseModel> items;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final List<SucursalesResponseModel> sucursales;
  final AppPalette palette;
  final ValueChanged<Object> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 16.0;
        const spacing = 14.0;
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final columns = math.max(1, (availableWidth / 280).floor()).clamp(1, 8);
        final cardWidth =
            (availableWidth - (spacing * (columns - 1))) / columns;

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 100),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: cardWidth,
                  child: _ProductoMobileCard(
                    item: item,
                    palette: palette,
                    brandName: _firstOrNull(
                          marcas.where((element) => element.mrcaId == item.mrcaId),
                        )?.mrcaNombre ??
                        'Marca no definida',
                    typeName: _firstOrNull(
                          tipos.where((element) => element.tpprId == item.tpprId),
                        )?.tpprNombre ??
                        'Tipo no definido',
                    sucursalName: _firstOrNull(
                          sucursales.where((element) => element.sucuId == item.sucuId),
                        )?.sucuNombre ??
                        'Sucursal ${item.sucuId ?? '-'}',
                    onDelete: onDelete,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductoMobileCard extends StatelessWidget {
  const _ProductoMobileCard({
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
    final title = (item.prodNombre ?? '').trim().isEmpty
        ? 'Producto sin nombre'
        : item.prodNombre!.trim();
    final description = (item.prodDescripcion ?? '').trim();

    return Card(
      elevation: 0,
      color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: id == null ? null : () => context.go('/productos/$id'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductImage(
                    value: item.prodFoto,
                    size: 82,
                    palette: palette,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: palette.textSecondary,
                              ),
                              color: palette.surface,
                              onSelected: (value) {
                                if (id == null) return;
                                if (value == 'detail') context.go('/productos/$id');
                                if (value == 'edit') context.go('/productos/$id/editar');
                                if (value == 'delete') onDelete(id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'detail',
                                  child: Text('Ver producto'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar/Inactivar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description.isEmpty
                              ? 'Sin descripción registrada.'
                              : description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProductChip(
                    icon: Icons.storefront_rounded,
                    label: sucursalName,
                    palette: palette,
                  ),
                  _ProductChip(
                    icon: Icons.category_rounded,
                    label: typeName,
                    palette: palette,
                  ),
                  _ProductChip(
                    icon: Icons.sell_rounded,
                    label: brandName,
                    palette: palette,
                  ),
                  _ProductChip(
                    icon: Icons.inventory_rounded,
                    label: 'Inv. ${_formatNumber(item.inventarioActual)}',
                    palette: palette,
                  ),
                  _ProductChip(
                    icon: Icons.trending_up_rounded,
                    label: 'Ayer ${_formatNumber(item.ventasAyer)}',
                    palette: palette,
                  ),
                  if ((item.prodFechaVencimiento ?? '').trim().isNotEmpty)
                    _ProductChip(
                      icon: Icons.event_busy_rounded,
                      label:
                          'Vence ${_shortDate(item.prodFechaVencimiento)}',
                      palette: palette,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: id == null ? null : () => context.go('/productos/$id'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Ver producto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          id == null ? null : () => context.go('/productos/$id/editar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.actionColor,
                        foregroundColor: palette.onAction,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.value,
    required this.size,
    required this.palette,
  });

  final String? value;
  final double size;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final imageValue = (value ?? '').trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.secondary.withOpacity(0.14),
            palette.accent.withOpacity(0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Icon(Icons.image_rounded, color: palette.secondary, size: 32),
    );

    if (imageValue.isEmpty) return placeholder;

    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.memory(
              base64Decode(imageValue.substring(commaIndex + 1)),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
        } catch (_) {
          return placeholder;
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.06)
            : palette.background.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(num? value) {
  if (value == null) return '0';
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _shortDate(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
