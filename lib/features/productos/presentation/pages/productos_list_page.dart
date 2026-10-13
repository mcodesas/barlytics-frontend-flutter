import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../marcas/data/models/marcas_response_model.dart';
import '../../../marcas/presentation/providers/marcas_provider.dart';
import '../../../movimientos/data/models/movimientos_response_model.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../precios/data/models/precios_response_model.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../../tipos_producto/data/models/tipos_producto_response_model.dart';
import '../../../tipos_producto/presentation/providers/tipos_producto_provider.dart';
import '../../data/models/productos_response_model.dart';
import '../providers/productos_provider.dart';
import '../widgets/productos_setup_tools.dart';

enum _ProductViewMode { cards, list, table }

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
  _ProductViewMode _viewMode = _ProductViewMode.cards;
  Timer? _searchDebounce;
  Map<String, int>? _movementTypeIds;
  bool _branchInitialized = false;
  final Set<int> _stockSavingIds = <int>{};
  final Set<int> _productSavingIds = <int>{};
  final Set<int> _selectedProductIds = <int>{};
  bool _bulkDeleting = false;

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
    final branchState = ref.watch(branchScopeProvider);
    final state = ref.watch(productosPagedProvider);
    final marcasState = ref.watch(marcasProvider);
    final tiposState = ref.watch(tiposproductoProvider);
    final notifier = ref.read(productosPagedProvider.notifier);
    final items = state.items;
    final activeRoles = ref.watch(activeRolesProvider);
    final movementOnly = activeRoles.isNotEmpty &&
        activeRoles.every((role) {
          final normalized = normalizeRoleName(role);
          return const {
            'MOVIMIENTOS',
            'MOVIMIENTO',
            'INVENTARIO',
            'INVENTORY',
            'BODEGA',
            'ALMACEN',
          }.contains(normalized);
        });

    if (!_branchInitialized && !branchState.loading && branchState.activeBranchId != null) {
      _branchInitialized = true;
      final branchId = branchState.activeBranchId!;
      _selectedSucursalId = branchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifier.load(page: 0, sucursalId: branchId);
      });
    }

    final lowStock = items.where((item) => (item.inventarioActual ?? 0) <= 5).length;
    final outOfStock = items.where((item) => (item.inventarioActual ?? 0) <= 0).length;
    final expiringSoon = items.where((item) => _expiresWithinDays(item.prodFechaVencimiento, 30)).length;
    final salesYesterday = items.fold<double>(0, (sum, item) => sum + (item.ventasAyer ?? 0));
    final hasMultipleBranches = branchState.branches.length > 1;
    final hasFilters = _searchController.text.trim().isNotEmpty ||
        _selectedTipoId != null ||
        _selectedMarcaId != null ||
        (hasMultipleBranches && _selectedSucursalId != null) ||
        state.quickFilter != ProductosQuickFilter.all;

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
        sucursales: branchState.branches,
        palette: palette,
        viewMode: _viewMode,
        onDelete: (id) => _deleteProduct(context, id),
        onRegisterMovement: _registerMovementInline,
        onUpdateProduct: _updateProductInline,
        stockSavingIds: _stockSavingIds,
        productSavingIds: _productSavingIds,
        allowProductManagement: !movementOnly,
        selectedProductIds: _selectedProductIds,
        onSelectionChanged: _toggleProductSelection,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: movementOnly
          ? null
          : FloatingActionButton.extended(
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
                if (!movementOnly)
                  SliverToBoxAdapter(
                    child: ProductosSetupTools(
                      palette: palette,
                      branches: branchState.branches,
                      activeBranchId: branchState.activeBranchId,
                      onCompleted: () async {
                        _selectedProductIds.clear();
                        await notifier.refresh();
                      },
                    ),
                  ),
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
                    sucursales: branchState.branches,
                    selectedTipoId: _selectedTipoId,
                    selectedMarcaId: _selectedMarcaId,
                    selectedSucursalId: _selectedSucursalId,
                    activeBranchId: branchState.activeBranchId,
                    onActiveBranchChanged: _changeActiveBranch,
                    sortOption: state.sortOption,
                    viewMode: _viewMode,
                    selectedQuickFilter: state.quickFilter,
                    onQuickFilterChanged: (filter) {
                      final nextFilter = state.quickFilter == filter
                          ? ProductosQuickFilter.all
                          : filter;
                      final nextSort = switch (nextFilter) {
                        ProductosQuickFilter.lowStock => ProductosSortOption.inventarioAsc,
                        ProductosQuickFilter.outOfStock => ProductosSortOption.inventarioAsc,
                        ProductosQuickFilter.soldYesterday => ProductosSortOption.ventasAyerDesc,
                        _ => state.sortOption,
                      };
                      notifier.load(
                        page: 0,
                        quickFilter: nextFilter,
                        sortOption: nextSort,
                      );
                    },
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
                    onViewChanged: (mode) => setState(() => _viewMode = mode),
                    onClearFilters: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      final singleBranchId = branchState.branches.length == 1
                          ? branchState.activeBranchId
                          : null;
                      setState(() {
                        _selectedTipoId = null;
                        _selectedMarcaId = null;
                        _selectedSucursalId = singleBranchId;
                      });
                      notifier.load(
                        page: 0,
                        query: '',
                        clearTipoId: true,
                        clearMarcaId: true,
                        sucursalId: singleBranchId,
                        clearSucursalId: singleBranchId == null,
                        sortOption: ProductosSortOption.nombreAsc,
                        quickFilter: ProductosQuickFilter.all,
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
                if (!movementOnly && _selectedProductIds.isNotEmpty)
                  SliverToBoxAdapter(child: _buildBulkActions(palette, items)),
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

  void _toggleProductSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedProductIds.add(id);
      } else {
        _selectedProductIds.remove(id);
      }
    });
  }

  Widget _buildBulkActions(AppPalette palette, List<ProductosResponseModel> items) {
    final visibleIds = items.map((item) => item.prodId).whereType<int>().toSet();
    final allVisibleSelected = visibleIds.isNotEmpty && visibleIds.every(_selectedProductIds.contains);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: palette.panelDecoration(baseRadius: 18, tint: palette.secondary, elevated: false),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${_selectedProductIds.length} producto(s) seleccionado(s)',
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            TextButton.icon(
              onPressed: _bulkDeleting ? null : () {
                setState(() {
                  if (allVisibleSelected) {
                    _selectedProductIds.removeAll(visibleIds);
                  } else {
                    _selectedProductIds.addAll(visibleIds);
                  }
                });
              },
              icon: Icon(allVisibleSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
              label: Text(allVisibleSelected ? 'Quitar selección' : 'Seleccionar visibles'),
            ),
            FilledButton.icon(
              onPressed: _bulkDeleting ? null : () => _deleteSelectedProducts(context),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              icon: _bulkDeleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(_bulkDeleting ? 'Inactivando...' : 'Inactivar seleccionados'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedProducts(BuildContext context) async {
    if (_selectedProductIds.isEmpty || _bulkDeleting) return;
    final count = _selectedProductIds.length;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Inactivar productos',
      message: '¿Deseas inactivar los $count productos seleccionados? Dejarán de aparecer en la operación, pero conservarán su historial.',
    );
    if (!confirmed || !mounted) return;

    final ids = _selectedProductIds.toList(growable: false);
    setState(() => _bulkDeleting = true);
    var success = 0;
    try {
      for (final id in ids) {
        final ok = await ref.read(productosPagedProvider.notifier).remove(id);
        if (ok) {
          success++;
          if (mounted) setState(() => _selectedProductIds.remove(id));
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success == count
            ? '$success productos inactivados.'
            : '$success de $count productos fueron inactivados.')),
      );
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _changeActiveBranch(int? branchId) async {
    if (branchId == null || branchId == ref.read(branchScopeProvider).activeBranchId) return;
    await ref.read(branchScopeProvider.notifier).select(branchId);
    if (!mounted) return;
    setState(() {
      _selectedSucursalId = branchId;
    });
    await ref.read(productosPagedProvider.notifier).load(
          page: 0,
          sucursalId: branchId,
        );
  }

  Future<bool> _registerMovementInline(
    ProductosResponseModel item,
    _QuickMovementDraft draft,
  ) async {
    if (item.prodId == null || item.sucuId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El producto no tiene sucursal o identificador válido.'),
        ),
      );
      return false;
    }

    final productId = item.prodId!;
    final quantity = draft.quantity.abs();
    if (quantity <= 0 || _stockSavingIds.contains(productId)) return false;

    if (!draft.kind.increasesStock &&
        quantity > (item.inventarioActual ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes retirar más unidades que el stock disponible.'),
        ),
      );
      return false;
    }

    setState(() => _stockSavingIds.add(productId));

    try {
      final typeIds = await _loadMovementTypeIds();
      final typeId = typeIds[_movementTypeKey(draft.kind.backendName)];
      if (typeId == null) {
        throw StateError(
          'No existe el tipo de movimiento ${draft.kind.label}.',
        );
      }

      await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/api/v1/movimientos',
        <String, dynamic>{
          'prodId': productId,
          'sucuId': item.sucuId,
          'timoId': typeId,
          'moviCantidad': quantity,
          'moviUnidad': 'UNIDAD',
          'moviOperacion': draft.kind.increasesStock ? 'ENTRADA' : 'SALIDA',
          'moviMotivo': draft.reason,
          'moviReferencia': draft.reference,
        },
        (json) => Map<String, dynamic>.from(json as Map),
      );

      await ref.read(productosPagedProvider.notifier).refresh();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${draft.kind.label}: ${_formatNumber(quantity)} unidades de '
            '${item.prodNombre ?? 'producto'} registradas.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible registrar el movimiento: $error')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _stockSavingIds.remove(productId));
      }
    }
  }

  Future<bool> _updateProductInline(
    ProductosResponseModel item,
    Map<String, dynamic> body,
  ) async {
    final productId = item.prodId;
    final branchId = item.sucuId;
    if (productId == null ||
        branchId == null ||
        _productSavingIds.contains(productId)) {
      return false;
    }

    final productBody = Map<String, dynamic>.from(body);
    final salePrice = (productBody.remove('_uiPrecioVenta') as num?)?.toDouble();
    final purchasePrice =
        (productBody.remove('_uiPrecioCompra') as num?)?.toDouble();
    final priceChanged = productBody.remove('_uiPrecioCambio') == true;

    setState(() => _productSavingIds.add(productId));
    try {
      final client = ref.read(apiClientProvider);
      await client.put<ProductosResponseModel>(
        '/api/v1/productos/$productId',
        productBody,
        (json) => ProductosResponseModel.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );

      if (priceChanged) {
        if (salePrice == null ||
            purchasePrice == null ||
            salePrice <= 0 ||
            purchasePrice <= 0) {
          throw StateError(
            'Los precios de venta y compra deben ser mayores que cero.',
          );
        }
        final purchaseByQuantity = switch (productBody['prodCompraPorCantidad']) {
          final num value => value.toInt() == 1,
          final bool value => value,
          _ => item.prodCompraPorCantidad == 1,
        };
        final purchaseQuantity =
            (productBody['prodCantidadCompra'] as num?)?.toDouble() ??
            item.prodCantidadCompra;
        if (purchaseByQuantity &&
            (purchaseQuantity == null || purchaseQuantity <= 0)) {
          throw StateError(
            'Indica cuántas unidades contiene la presentación de compra.',
          );
        }
        final unitPurchasePrice = purchaseByQuantity
            ? purchasePrice / purchaseQuantity!
            : purchasePrice;
        if (salePrice < unitPurchasePrice) {
          throw StateError(
            'El precio de venta no puede ser menor que el costo unitario de compra.',
          );
        }

        final taxPercentage = item.precioPorcentajeImpuesto;
        final appliesTax = item.precioAplicaImpuesto ?? 0;
        final taxValue = appliesTax == 1 && taxPercentage != null
            ? salePrice * (taxPercentage / 100)
            : 0.0;

        await client.post<PreciosResponseModel>(
          '/api/v1/precios',
          <String, dynamic>{
            'prodId': productId,
            'sucuId': branchId,
            'precEstado': 1,
            'precValorVenta': salePrice,
            'precValorCompra': purchasePrice,
            'precFechaInicia': DateTime.now().toIso8601String(),
            'precFechaFinaliza': null,
            'precAplicaImpuesto': appliesTax,
            'precPorcentajeImpuesto': taxPercentage,
            'precValorImpuesto': taxValue,
          },
          (json) => PreciosResponseModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        );
      }

      await ref.read(productosPagedProvider.notifier).refresh();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            priceChanged
                ? 'Producto y precios actualizados. El precio anterior quedó en el historial.'
                : 'Datos del producto actualizados.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible completar la actualización del producto: $error',
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _productSavingIds.remove(productId));
      }
    }
  }

  Future<Map<String, int>> _loadMovementTypeIds() async {
    if (_movementTypeIds != null) return _movementTypeIds!;
    final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
      '/api/v1/tiposmovimiento',
      (json) => (json is List ? json : const <Object>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
    final values = <String, int>{};
    for (final item in response.data ?? const <Map<String, dynamic>>[]) {
      final id = item['timoId'];
      final name = _movementTypeKey(item['timoNombre']?.toString() ?? '');
      if (id is num && name.isNotEmpty) {
        values[name] = id.toInt();
      }
    }
    _movementTypeIds = values;
    return values;
  }

  Future<void> _deleteProduct(BuildContext context, Object id) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Inactivar producto',
      message: '¿Deseas inactivar este producto? Dejará de aparecer en la operación, pero se conservará su historial.',
    );
    if (!confirmed) return;

    final ok = await ref.read(productosPagedProvider.notifier).remove(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Producto inactivado correctamente' : 'No fue posible inactivar el producto',
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
    required this.activeBranchId,
    required this.onActiveBranchChanged,
    required this.sortOption,
    required this.viewMode,
    required this.selectedQuickFilter,
    required this.onQuickFilterChanged,
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
  final int? activeBranchId;
  final ValueChanged<int?> onActiveBranchChanged;
  final ProductosSortOption sortOption;
  final _ProductViewMode viewMode;
  final ProductosQuickFilter selectedQuickFilter;
  final ValueChanged<ProductosQuickFilter> onQuickFilterChanged;
  final ValueChanged<int?> onTipoChanged;
  final ValueChanged<int?> onMarcaChanged;
  final ValueChanged<int?> onSucursalChanged;
  final ValueChanged<ProductosSortOption?> onSortChanged;
  final ValueChanged<_ProductViewMode> onViewChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final AppPalette palette;

  int get _activeFilterCount {
    var count = 0;
    if (controller.text.trim().isNotEmpty) count++;
    if (selectedTipoId != null) count++;
    if (selectedMarcaId != null) count++;
    if (sucursales.length > 1 && selectedSucursalId != null) count++;
    if (selectedQuickFilter != ProductosQuickFilter.all) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sucursales.length > 1) ...[
            _ProductBranchScope(
              palette: palette,
              branches: sucursales,
              activeBranchId: activeBranchId,
              onChanged: onActiveBranchChanged,
            ),
            const SizedBox(height: 10),
          ],
          _CatalogSummary(
            palette: palette,
            visible: visible,
            lowStock: lowStock,
            outOfStock: outOfStock,
            expiringSoon: expiringSoon,
            salesYesterday: salesYesterday,
            selectedFilter: selectedQuickFilter,
            onFilterSelected: onQuickFilterChanged,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: palette.panelDecoration(
              baseRadius: 22,
              tint: palette.primary,
              elevated: false,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 720;
                if (mobile) {
                  return _buildMobileToolbar(context);
                }
                return _buildDesktopToolbar(context, constraints.maxWidth);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileToolbar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(
          controller: controller,
          onChanged: onChanged,
          palette: palette,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppControlMetrics.filterHeight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _showMobileFilters(context),
                  style: FilledButton.styleFrom(
                    foregroundColor: palette.secondary,
                    backgroundColor: palette.secondary.withOpacity(0.13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune_rounded, size: 20),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.actionColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: TextStyle(
                                color: palette.onAction,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: Text(
                    _activeFilterCount == 0 ? 'Filtros' : 'Filtros activos',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 154,
              child: _ViewSelector(
                viewMode: viewMode,
                palette: palette,
                onChanged: onViewChanged,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(
              tooltip: 'Actualizar catálogo',
              icon: Icons.refresh_rounded,
              palette: palette,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '$visible de $total productos visibles',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_activeFilterCount > 0)
              TextButton.icon(
                onPressed: onClearFilters,
                style: TextButton.styleFrom(
                  foregroundColor: palette.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text(
                  'Limpiar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopToolbar(BuildContext context, double maxWidth) {
    const gap = 10.0;
    final filterWidth = maxWidth >= 1280
        ? (maxWidth - gap * 3) / 4
        : maxWidth >= 900
            ? (maxWidth - gap * 2) / 3
            : (maxWidth - gap) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SearchField(
                controller: controller,
                onChanged: onChanged,
                palette: palette,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 246,
              child: _ViewSelector(
                viewMode: viewMode,
                palette: palette,
                onChanged: onViewChanged,
              ),
            ),
            const SizedBox(width: 10),
            _CounterPill(label: '$visible / $total', palette: palette),
            const SizedBox(width: 8),
            _HeaderIconButton(
              tooltip: 'Actualizar catálogo',
              icon: Icons.refresh_rounded,
              palette: palette,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: filterWidth,
              child: _HeaderDropdown<int?>(
                label: 'Tipo',
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
              width: filterWidth,
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
            if (sucursales.length > 1)
              SizedBox(
                width: filterWidth,
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
              width: filterWidth,
              child: _HeaderDropdown<ProductosSortOption>(
                label: 'Orden',
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
            if (_activeFilterCount > 0)
              SizedBox(
                height: AppControlMetrics.filterHeight,
                child: _ClearButton(
                  palette: palette,
                  onPressed: onClearFilters,
                  compact: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showMobileFilters(BuildContext context) async {
    var localTipo = selectedTipoId;
    var localMarca = selectedMarcaId;
    var localSucursal = selectedSucursalId;
    var localSort = sortOption;
    var localViewMode = viewMode;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.72),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.none,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.86,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(palette.radius(28)),
                    topRight: Radius.circular(palette.radius(28)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: palette.textSecondary.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: palette.secondary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.tune_rounded, color: palette.secondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Filtrar productos',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Reduce el catálogo para encontrar lo que necesitas.',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.cardBorder),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FilterSectionLabel(
                              icon: Icons.category_rounded,
                              label: 'Clasificación',
                              palette: palette,
                            ),
                            const SizedBox(height: 10),
                            _HeaderDropdown<int?>(
                              label: 'Tipo de producto',
                              value: localTipo,
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
                              onChanged: (value) {
                                setModalState(() => localTipo = value);
                                onTipoChanged(value);
                              },
                            ),
                            const SizedBox(height: 10),
                            _HeaderDropdown<int?>(
                              label: 'Marca',
                              value: localMarca,
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
                              onChanged: (value) {
                                setModalState(() => localMarca = value);
                                onMarcaChanged(value);
                              },
                            ),
                            if (sucursales.length > 1) ...[
                              const SizedBox(height: 10),
                              _HeaderDropdown<int?>(
                                label: 'Sucursal',
                                value: localSucursal,
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
                                onChanged: (value) {
                                  setModalState(() => localSucursal = value);
                                  onSucursalChanged(value);
                                },
                              ),
                            ],
                            const SizedBox(height: 22),
                            _FilterSectionLabel(
                              icon: Icons.sort_rounded,
                              label: 'Orden y presentación',
                              palette: palette,
                            ),
                            const SizedBox(height: 10),
                            _HeaderDropdown<ProductosSortOption>(
                              label: 'Ordenar por',
                              value: localSort,
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
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() => localSort = value);
                                onSortChanged(value);
                              },
                            ),
                            const SizedBox(height: 10),
                            _ViewSelector(
                              viewMode: localViewMode,
                              palette: palette,
                              onChanged: (value) {
                                setModalState(() => localViewMode = value);
                                onViewChanged(value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        boxShadow: [
                          BoxShadow(
                            color: palette.cardShadow.withOpacity(0.30),
                            blurRadius: 18,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                onClearFilters();
                                setModalState(() {
                                  localTipo = null;
                                  localMarca = null;
                                  localSucursal = sucursales.length == 1
                                      ? activeBranchId
                                      : null;
                                  localSort = ProductosSortOption.nombreAsc;
                                  localViewMode = viewMode;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.secondary,
                                side: BorderSide(color: palette.cardBorder),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text(
                                'Limpiar',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.actionColor,
                                foregroundColor: palette.onAction,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                'Aplicar filtros',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: palette.secondary, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ProductBranchScope extends StatelessWidget {
  const _ProductBranchScope({
    required this.palette,
    required this.branches,
    required this.activeBranchId,
    required this.onChanged,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (branches.length <= 1) return const SizedBox.shrink();
    SucursalesResponseModel? branch;
    for (final item in branches) {
      if (item.sucuId == activeBranchId) {
        branch = item;
        break;
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: palette.panelDecoration(
        baseRadius: 18,
        tint: palette.secondary,
        elevated: false,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final selector = DropdownButtonFormField<int>(
            value: branches.any((item) => item.sucuId == activeBranchId) ? activeBranchId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sucursal activa',
              prefixIcon: Icon(Icons.storefront_rounded),
            ).compactFilter(),
            hint: const Text('Selecciona una sucursal'),
            items: branches
                .where((item) => item.sucuId != null)
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.sucuId!,
                    child: Text(
                      item.sucuNombre?.trim().isNotEmpty == true
                          ? item.sucuNombre!.trim()
                          : 'Sucursal ${item.sucuId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: branches.length <= 1 ? null : onChanged,
          );

          final info = Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: palette.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Los productos nuevos y los movimientos se registrarán en ${branch?.sucuNombre ?? 'la sucursal seleccionada'}. El filtro puede mostrar todas las sucursales permitidas.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [selector, const SizedBox(height: 8), info],
            );
          }
          return Row(
            children: [
              SizedBox(width: 300, child: selector),
              const SizedBox(width: 14),
              Expanded(child: info),
            ],
          );
        },
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
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final AppPalette palette;
  final int visible;
  final int lowStock;
  final int outOfStock;
  final int expiringSoon;
  final double salesYesterday;
  final ProductosQuickFilter selectedFilter;
  final ValueChanged<ProductosQuickFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CatalogMetric(
        icon: Icons.grid_view_rounded,
        label: 'Todos',
        value: '$visible',
        color: palette.secondary,
        filter: ProductosQuickFilter.all,
        helper: 'Mostrar todo el catálogo',
      ),
      _CatalogMetric(
        icon: Icons.inventory_2_outlined,
        label: 'Stock bajo',
        value: '$lowStock',
        color: palette.warning,
        filter: ProductosQuickFilter.lowStock,
        helper: 'Productos entre 1 y 5 unidades',
      ),
      _CatalogMetric(
        icon: Icons.remove_shopping_cart_rounded,
        label: 'Sin stock',
        value: '$outOfStock',
        color: Colors.redAccent,
        filter: ProductosQuickFilter.outOfStock,
        helper: 'Productos sin unidades disponibles',
      ),
      _CatalogMetric(
        icon: Icons.schedule_rounded,
        label: 'Vence pronto',
        value: '$expiringSoon',
        color: palette.primary,
        filter: ProductosQuickFilter.expiringSoon,
        helper: 'Vencimiento dentro de 30 días',
      ),
      _CatalogMetric(
        icon: Icons.local_shipping_rounded,
        label: 'Salida ayer',
        value: _formatNumber(salesYesterday),
        color: palette.success,
        filter: ProductosQuickFilter.soldYesterday,
        helper: 'Productos vendidos durante ayer',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1150
            ? 5
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 430
                    ? 2
                    : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _CatalogMetricCard(
                  metric: card,
                  palette: palette,
                  selected: selectedFilter == card.filter,
                  onTap: () => onFilterSelected(card.filter),
                ),
              ),
          ],
        );
      },
    );
  }
}
class _CatalogMetric {
  const _CatalogMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.filter,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ProductosQuickFilter filter;
  final String helper;
}


class _CatalogMetricCard extends StatelessWidget {
  const _CatalogMetricCard({
    required this.metric,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final _CatalogMetric metric;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${metric.label}: ${metric.value}. ${metric.helper}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? metric.color.withOpacity(palette.darkBackground ? 0.18 : 0.12)
                  : palette.surface.withOpacity(palette.darkBackground ? 0.76 : 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? metric.color.withOpacity(0.72)
                    : metric.color.withOpacity(0.15),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: metric.color.withOpacity(0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: metric.color.withOpacity(selected ? 0.24 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? metric.color : palette.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  size: selected ? 18 : 19,
                  color: selected ? metric.color : palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
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
      maxLength: InputConstraints.search,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(InputConstraints.search)],
      onChanged: onChanged,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar producto, marca o categoría',
        hintStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
        prefixIcon: Icon(Icons.search_rounded, color: palette.secondary, size: 21),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: palette.textSecondary, size: 19),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: palette.darkBackground
            ? Colors.white.withOpacity(0.045)
            : palette.background.withOpacity(0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.secondary, width: 1.4),
        ),
      ).compactFilter(),
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
      height: AppControlMetrics.filterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.045)
            : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: palette.secondary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: palette.surface,
                icon: Icon(Icons.expand_more_rounded, color: palette.textSecondary, size: 20),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                hint: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                ),
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
  const _ViewSelector({
    required this.viewMode,
    required this.palette,
    required this.onChanged,
    this.compact = false,
  });

  final _ProductViewMode viewMode;
  final AppPalette palette;
  final ValueChanged<_ProductViewMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppControlMetrics.filterHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.045)
            : palette.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ViewOption(
              active: viewMode == _ProductViewMode.cards,
              icon: Icons.grid_view_rounded,
              label: compact ? '' : 'Tarjetas',
              palette: palette,
              onTap: () => onChanged(_ProductViewMode.cards),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ViewOption(
              active: viewMode == _ProductViewMode.list,
              icon: Icons.view_list_rounded,
              label: compact ? '' : 'Lista',
              palette: palette,
              onTap: () => onChanged(_ProductViewMode.list),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ViewOption(
              active: viewMode == _ProductViewMode.table,
              icon: Icons.table_rows_rounded,
              label: compact ? '' : 'Tabla',
              palette: palette,
              onTap: () => onChanged(_ProductViewMode.table),
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
            if (label.isNotEmpty) ...[
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
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.palette,
    required this.onPressed,
    this.compact = false,
  });

  final AppPalette palette;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppControlMetrics.filterHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.secondary,
          side: BorderSide(color: palette.secondary.withOpacity(0.22)),
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
        label: Text(
          compact ? 'Limpiar' : 'Limpiar filtros',
          style: const TextStyle(fontWeight: FontWeight.w900),
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
    required this.palette,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            width: AppControlMetrics.filterHeight,
            height: AppControlMetrics.filterHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.secondary.withOpacity(0.24)),
            ),
            child: Icon(icon, color: palette.secondary),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.label, required this.palette});

  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textPrimary,
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
    required this.viewMode,
    required this.onDelete,
    required this.onRegisterMovement,
    required this.onUpdateProduct,
    required this.stockSavingIds,
    required this.productSavingIds,
    required this.allowProductManagement,
    required this.selectedProductIds,
    required this.onSelectionChanged,
  });

  final List<ProductosResponseModel> items;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final List<SucursalesResponseModel> sucursales;
  final AppPalette palette;
  final _ProductViewMode viewMode;
  final ValueChanged<Object> onDelete;
  final Future<bool> Function(ProductosResponseModel item, _QuickMovementDraft draft) onRegisterMovement;
  final Future<bool> Function(ProductosResponseModel item, Map<String, dynamic> body) onUpdateProduct;
  final Set<int> stockSavingIds;
  final Set<int> productSavingIds;
  final bool allowProductManagement;
  final Set<int> selectedProductIds;
  final void Function(int id, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (viewMode == _ProductViewMode.table) {
      return _ProductsTableView(
        items: items,
        marcas: marcas,
        tipos: tipos,
        sucursales: sucursales,
        palette: palette,
        allowProductManagement: allowProductManagement,
        selectedProductIds: selectedProductIds,
        onSelectionChanged: onSelectionChanged,
        onDelete: onDelete,
      );
    }

    if (viewMode == _ProductViewMode.list) {
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
                  _SimpleProductoTile(
                    item: items[index],
                    palette: palette,
                    brandName: _brandName(marcas, items[index]),
                    typeName: _typeName(tipos, items[index]),
                    sucursalName: _sucursalName(sucursales, items[index]),
                    last: index == items.length - 1,
                    listMode: true,
                    onDelete: onDelete,
                    marcas: marcas,
                    tipos: tipos,
                    stockSaving: stockSavingIds.contains(items[index].prodId),
                    productSaving: productSavingIds.contains(items[index].prodId),
                    onRegisterMovement: onRegisterMovement,
                    onUpdateProduct: onUpdateProduct,
                    allowProductManagement: allowProductManagement,
                    selected: items[index].prodId != null && selectedProductIds.contains(items[index].prodId),
                    onSelectionChanged: onSelectionChanged,
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
        final columns = math.max(1, (availableWidth / 360).floor()).clamp(1, 4);
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
                  child: _SimpleProductoTile(
                    item: item,
                    palette: palette,
                    brandName: _brandName(marcas, item),
                    typeName: _typeName(tipos, item),
                    sucursalName: _sucursalName(sucursales, item),
                    last: true,
                    listMode: false,
                    onDelete: onDelete,
                    marcas: marcas,
                    tipos: tipos,
                    stockSaving: stockSavingIds.contains(item.prodId),
                    productSaving: productSavingIds.contains(item.prodId),
                    onRegisterMovement: onRegisterMovement,
                    onUpdateProduct: onUpdateProduct,
                    allowProductManagement: allowProductManagement,
                    selected: item.prodId != null && selectedProductIds.contains(item.prodId),
                    onSelectionChanged: onSelectionChanged,
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


class _ProductsTableView extends StatelessWidget {
  const _ProductsTableView({
    required this.items,
    required this.marcas,
    required this.tipos,
    required this.sucursales,
    required this.palette,
    required this.allowProductManagement,
    required this.selectedProductIds,
    required this.onSelectionChanged,
    required this.onDelete,
  });

  final List<ProductosResponseModel> items;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final List<SucursalesResponseModel> sucursales;
  final AppPalette palette;
  final bool allowProductManagement;
  final Set<int> selectedProductIds;
  final void Function(int id, bool selected) onSelectionChanged;
  final ValueChanged<Object> onDelete;

  @override
  Widget build(BuildContext context) {
    String brandName(ProductosResponseModel item) =>
        _firstOrNull(marcas.where((value) => value.mrcaId == item.mrcaId))
            ?.mrcaNombre ??
        '-';
    String typeName(ProductosResponseModel item) =>
        _firstOrNull(tipos.where((value) => value.tpprId == item.tpprId))
            ?.tpprNombre ??
        '-';
    String branchName(ProductosResponseModel item) =>
        _firstOrNull(sucursales.where((value) => value.sucuId == item.sucuId))
            ?.sucuNombre ??
        'Sucursal ${item.sucuId ?? '-'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(palette.darkBackground ? .94 : .99),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow.withOpacity(.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 50,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 66,
              horizontalMargin: 14,
              columnSpacing: 22,
              columns: [
                if (allowProductManagement)
                  const DataColumn(label: Text('')),
                const DataColumn(label: Text('Producto')),
                const DataColumn(label: Text('Tipo')),
                const DataColumn(label: Text('Marca')),
                const DataColumn(label: Text('Cantidad'), numeric: true),
                const DataColumn(label: Text('Unidad')),
                const DataColumn(label: Text('Precio compra'), numeric: true),
                const DataColumn(label: Text('Precio venta'), numeric: true),
                const DataColumn(label: Text('Sucursal')),
                if (allowProductManagement)
                  const DataColumn(label: Text('Acciones')),
              ],
              rows: items.map((item) {
                final id = item.prodId;
                final selected =
                    id != null && selectedProductIds.contains(id);
                return DataRow(
                  selected: selected,
                  cells: [
                    if (allowProductManagement)
                      DataCell(
                        id == null
                            ? const SizedBox.shrink()
                            : Checkbox(
                                value: selected,
                                onChanged: (value) =>
                                    onSelectionChanged(id, value ?? false),
                              ),
                      ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          item.prodNombre ?? 'Producto ${item.prodId ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(typeName(item))),
                    DataCell(Text(brandName(item))),
                    DataCell(
                      Text(
                        _formatNumber(item.inventarioActual ?? 0),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(Text(item.prodUnidadBase ?? 'UND')),
                    DataCell(Text(_tableMoney(item.precioCompraVigente))),
                    DataCell(
                      Text(
                        _tableMoney(item.precioVentaVigente),
                        style: TextStyle(
                          color: palette.secondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(Text(branchName(item))),
                    if (allowProductManagement)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver detalle',
                              onPressed:
                                  id == null ? null : () => context.go('/productos/$id'),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            IconButton(
                              tooltip: 'Eliminar o inactivar',
                              onPressed: id == null ? null : () => onDelete(id),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleProductoTile extends StatelessWidget {
  const _SimpleProductoTile({
    required this.item,
    required this.palette,
    required this.brandName,
    required this.typeName,
    required this.sucursalName,
    required this.last,
    required this.listMode,
    required this.onDelete,
    required this.marcas,
    required this.tipos,
    required this.stockSaving,
    required this.productSaving,
    required this.onRegisterMovement,
    required this.onUpdateProduct,
    required this.allowProductManagement,
    required this.selected,
    required this.onSelectionChanged,
  });

  final ProductosResponseModel item;
  final AppPalette palette;
  final String brandName;
  final String typeName;
  final String sucursalName;
  final bool last;
  final bool listMode;
  final ValueChanged<Object> onDelete;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final bool stockSaving;
  final bool productSaving;
  final Future<bool> Function(ProductosResponseModel item, _QuickMovementDraft draft) onRegisterMovement;
  final Future<bool> Function(ProductosResponseModel item, Map<String, dynamic> body) onUpdateProduct;
  final bool allowProductManagement;
  final bool selected;
  final void Function(int id, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final id = item.prodId;
    final title = (item.prodNombre ?? '').trim().isEmpty
        ? 'Producto sin nombre'
        : item.prodNombre!.trim();
    final stock = item.inventarioActual ?? 0;
    final stockStatus = _stockStatus(stock, palette);
    final expiryStatus = _expiryStatus(item.prodFechaVencimiento, palette);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: listMode
            ? Colors.transparent
            : palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: listMode ? null : BorderRadius.circular(22),
        border: listMode
            ? (last ? null : Border(bottom: BorderSide(color: palette.cardBorder)))
            : Border.all(color: stockStatus.color.withOpacity(0.18)),
        boxShadow: listMode
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: palette.cardShadow.withOpacity(0.13),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allowProductManagement && id != null) ...[
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelectionChanged(id, value ?? false),
                ),
                const SizedBox(width: 4),
              ],
              _ProductImage(
                value: item.prodFoto,
                width: listMode ? 80 : 72,
                height: listMode ? 80 : 72,
                palette: palette,
              ),
              const SizedBox(width: 12),
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
                              color: palette.textPrimary,
                              fontSize: listMode ? 17 : 16,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (allowProductManagement)
                          PopupMenuButton<String>(
                            tooltip: 'Más opciones',
                            padding: EdgeInsets.zero,
                            color: palette.surface,
                            icon: Icon(Icons.more_horiz_rounded, color: palette.textSecondary),
                            onSelected: (value) {
                              if (id == null) return;
                              if (value == 'detail') context.go('/productos/$id');
                              if (value == 'delete') onDelete(id);
                            },
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'detail',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.visibility_outlined),
                                  title: Text('Ver detalle'),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.delete_outline_rounded),
                                  title: Text('Eliminar o inactivar'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$brandName · $typeName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(
                          icon: stockStatus.icon,
                          label: stockStatus.label,
                          color: stockStatus.color,
                          palette: palette,
                        ),
                        _SubtleInfoBadge(
                          icon: Icons.storefront_rounded,
                          label: sucursalName,
                          color: palette.secondary,
                          palette: palette,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.65),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CompactStockValue(
                    label: 'Stock actual',
                    value: _formatNumber(stock),
                    color: stockStatus.color,
                    palette: palette,
                  ),
                ),
                Container(width: 1, height: 30, color: palette.cardBorder),
                Expanded(
                  child: _CompactStockValue(
                    label: 'Salieron ayer',
                    value: _formatNumber(item.ventasAyer ?? 0),
                    color: palette.success,
                    palette: palette,
                  ),
                ),
                Container(width: 1, height: 30, color: palette.cardBorder),
                Expanded(
                  child: _CompactStockValue(
                    label: 'Vencimiento',
                    value: expiryStatus.label,
                    color: expiryStatus.color,
                    palette: palette,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _InlineProductControls(
            key: ValueKey<String>('producto-controles-${item.prodId}-${item.sucuId}'),
            item: item,
            palette: palette,
            marcas: marcas,
            tipos: tipos,
            stockSaving: stockSaving,
            productSaving: productSaving,
            onRegisterMovement: onRegisterMovement,
            onUpdateProduct: onUpdateProduct,
            allowProductManagement: allowProductManagement,
          ),
        ],
      ),
    );
  }
}


class _InlineProductControls extends StatefulWidget {
  const _InlineProductControls({
    super.key,
    required this.item,
    required this.palette,
    required this.marcas,
    required this.tipos,
    required this.stockSaving,
    required this.productSaving,
    required this.onRegisterMovement,
    required this.onUpdateProduct,
    required this.allowProductManagement,
  });

  final ProductosResponseModel item;
  final AppPalette palette;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final bool stockSaving;
  final bool productSaving;
  final Future<bool> Function(ProductosResponseModel item, _QuickMovementDraft draft) onRegisterMovement;
  final Future<bool> Function(ProductosResponseModel item, Map<String, dynamic> body) onUpdateProduct;
  final bool allowProductManagement;

  @override
  State<_InlineProductControls> createState() => _InlineProductControlsState();
}

class _InlineProductControlsState extends State<_InlineProductControls> {
  Future<void> _openMovementPanel(_QuickMovementType type) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.72),
      elevation: 0,
      builder: (sheetContext) {
        return _QuickMovementPanel(
          item: widget.item,
          initialType: type,
          palette: widget.palette,
          onSubmit: (draft) => widget.onRegisterMovement(widget.item, draft),
        );
      },
    );
  }

  Future<void> _openHistoryPanel() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.72),
      elevation: 0,
      builder: (sheetContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: FractionallySizedBox(
                  heightFactor: constraints.maxHeight < 720 ? 0.98 : 0.92,
                  child: _ProductMovementHistoryBottomSheet(
                    item: widget.item,
                    palette: widget.palette,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditPanel() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.72),
      elevation: 0,
      builder: (sheetContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: FractionallySizedBox(
                  heightFactor: constraints.maxHeight < 720 ? 0.98 : 0.94,
                  child: _ProductEditBottomSheet(
                    item: widget.item,
                    palette: widget.palette,
                    marcas: widget.marcas,
                    tipos: widget.tipos,
                    onUpdateProduct: widget.onUpdateProduct,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.42 : 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final columns = widget.allowProductManagement
              ? (constraints.maxWidth < 315 ? 2 : 4)
              : (constraints.maxWidth < 315 ? 2 : 3);
          final itemWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: itemWidth,
                child: _CompactProductAction(
                  label: 'Agregar',
                  icon: Icons.add_rounded,
                  color: palette.success,
                  palette: palette,
                  busy: widget.stockSaving,
                  onPressed: widget.stockSaving
                      ? null
                      : () => _openMovementPanel(_QuickMovementType.entry),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _CompactProductAction(
                  label: 'Quitar',
                  icon: Icons.remove_rounded,
                  color: Colors.redAccent,
                  palette: palette,
                  onPressed: widget.stockSaving
                      ? null
                      : () => _openMovementPanel(_QuickMovementType.exit),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _CompactProductAction(
                  label: 'Historial',
                  icon: Icons.history_rounded,
                  color: palette.secondary,
                  palette: palette,
                  onPressed: _openHistoryPanel,
                ),
              ),
              if (widget.allowProductManagement)
                SizedBox(
                  width: itemWidth,
                  child: _CompactProductAction(
                    label: 'Modificar',
                    icon: Icons.edit_outlined,
                    color: palette.secondary,
                    palette: palette,
                    busy: widget.productSaving,
                    onPressed: widget.productSaving ? null : _openEditPanel,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactProductAction extends StatelessWidget {
  const _CompactProductAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.palette,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final AppPalette palette;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.08),
          side: BorderSide(color: color.withOpacity(0.24)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          minimumSize: Size.zero,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: busy
            ? SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
              )
            : Icon(icon, size: 15),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

String _movementTypeKey(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll('Ü', 'U')
    .replaceAll(RegExp(r'\s+'), ' ');

enum _QuickMovementType { entry, exit }

enum _InventoryMovementKind {
  initialEntry,
  purchase,
  sale,
  positiveAdjustment,
  negativeAdjustment,
  incomingLoan,
  outgoingLoan,
  returnEntry,
}

extension _QuickMovementTypeX on _QuickMovementType {
  String get label => switch (this) {
        _QuickMovementType.entry => 'Ingreso',
        _QuickMovementType.exit => 'Retiro',
      };

  IconData get icon => switch (this) {
        _QuickMovementType.entry => Icons.add_box_rounded,
        _QuickMovementType.exit => Icons.indeterminate_check_box_rounded,
      };

  bool get increasesStock => this == _QuickMovementType.entry;

  _InventoryMovementKind get defaultKind => switch (this) {
        _QuickMovementType.entry => _InventoryMovementKind.purchase,
        _QuickMovementType.exit => _InventoryMovementKind.sale,
      };
}

extension _InventoryMovementKindX on _InventoryMovementKind {
  String get label => switch (this) {
        _InventoryMovementKind.initialEntry => 'Entrada inicial',
        _InventoryMovementKind.purchase => 'Compra',
        _InventoryMovementKind.sale => 'Venta',
        _InventoryMovementKind.positiveAdjustment => 'Ajuste positivo',
        _InventoryMovementKind.negativeAdjustment => 'Ajuste negativo',
        _InventoryMovementKind.incomingLoan => 'Préstamo entrante',
        _InventoryMovementKind.outgoingLoan => 'Préstamo saliente',
        _InventoryMovementKind.returnEntry => 'Devolución',
      };

  String get backendName => switch (this) {
        _InventoryMovementKind.initialEntry => 'ENTRADA INICIAL',
        _InventoryMovementKind.purchase => 'COMPRA',
        _InventoryMovementKind.sale => 'VENTA',
        _InventoryMovementKind.positiveAdjustment => 'AJUSTE POSITIVO',
        _InventoryMovementKind.negativeAdjustment => 'AJUSTE NEGATIVO',
        _InventoryMovementKind.incomingLoan => 'PRESTAMO ENTRANTE',
        _InventoryMovementKind.outgoingLoan => 'PRESTAMO SALIENTE',
        _InventoryMovementKind.returnEntry => 'DEVOLUCION',
      };

  String get description => switch (this) {
        _InventoryMovementKind.initialEntry =>
          'Carga inicial al comenzar el control del producto.',
        _InventoryMovementKind.purchase =>
          'Ingreso recibido por una compra a proveedor.',
        _InventoryMovementKind.sale =>
          'Salida manual asociada a una venta.',
        _InventoryMovementKind.positiveAdjustment =>
          'Corrección que aumenta el inventario disponible.',
        _InventoryMovementKind.negativeAdjustment =>
          'Corrección que disminuye el inventario disponible.',
        _InventoryMovementKind.incomingLoan =>
          'Producto recibido temporalmente de otro negocio.',
        _InventoryMovementKind.outgoingLoan =>
          'Producto entregado temporalmente a otro negocio.',
        _InventoryMovementKind.returnEntry =>
          'Producto que vuelve al inventario por devolución.',
      };

  String get defaultReason => switch (this) {
        _InventoryMovementKind.initialEntry => 'Carga inicial de inventario',
        _InventoryMovementKind.purchase => 'Entrada por compra',
        _InventoryMovementKind.sale => 'Salida por venta',
        _InventoryMovementKind.positiveAdjustment =>
          'Ajuste positivo de inventario',
        _InventoryMovementKind.negativeAdjustment =>
          'Ajuste negativo de inventario',
        _InventoryMovementKind.incomingLoan =>
          'Préstamo recibido de otro negocio',
        _InventoryMovementKind.outgoingLoan =>
          'Préstamo entregado a otro negocio',
        _InventoryMovementKind.returnEntry => 'Devolución de producto',
      };

  IconData get icon => switch (this) {
        _InventoryMovementKind.initialEntry =>
          Icons.playlist_add_circle_rounded,
        _InventoryMovementKind.purchase =>
          Icons.shopping_cart_checkout_rounded,
        _InventoryMovementKind.sale => Icons.point_of_sale_rounded,
        _InventoryMovementKind.positiveAdjustment => Icons.add_chart_rounded,
        _InventoryMovementKind.negativeAdjustment =>
          Icons.remove_circle_outline_rounded,
        _InventoryMovementKind.incomingLoan => Icons.call_received_rounded,
        _InventoryMovementKind.outgoingLoan => Icons.call_made_rounded,
        _InventoryMovementKind.returnEntry => Icons.assignment_return_rounded,
      };

  bool get increasesStock => switch (this) {
        _InventoryMovementKind.initialEntry => true,
        _InventoryMovementKind.purchase => true,
        _InventoryMovementKind.positiveAdjustment => true,
        _InventoryMovementKind.incomingLoan => true,
        _InventoryMovementKind.returnEntry => true,
        _InventoryMovementKind.sale => false,
        _InventoryMovementKind.negativeAdjustment => false,
        _InventoryMovementKind.outgoingLoan => false,
      };

  Color color(AppPalette palette) => switch (this) {
        _InventoryMovementKind.initialEntry => palette.success,
        _InventoryMovementKind.purchase => palette.success,
        _InventoryMovementKind.sale => Colors.orangeAccent,
        _InventoryMovementKind.positiveAdjustment => palette.secondary,
        _InventoryMovementKind.negativeAdjustment => palette.warning,
        _InventoryMovementKind.incomingLoan => Colors.tealAccent.shade400,
        _InventoryMovementKind.outgoingLoan => Colors.deepOrangeAccent,
        _InventoryMovementKind.returnEntry =>
          Colors.lightGreenAccent.shade400,
      };
}

List<_InventoryMovementKind> _movementKindsFor(_QuickMovementType type) =>
    switch (type) {
      _QuickMovementType.entry => const <_InventoryMovementKind>[
          _InventoryMovementKind.purchase,
          _InventoryMovementKind.initialEntry,
          _InventoryMovementKind.positiveAdjustment,
          _InventoryMovementKind.incomingLoan,
          _InventoryMovementKind.returnEntry,
        ],
      _QuickMovementType.exit => const <_InventoryMovementKind>[
          _InventoryMovementKind.sale,
          _InventoryMovementKind.negativeAdjustment,
          _InventoryMovementKind.outgoingLoan,
        ],
    };

class _QuickMovementDraft {
  const _QuickMovementDraft({
    required this.kind,
    required this.quantity,
    required this.reason,
    required this.reference,
  });

  final _InventoryMovementKind kind;
  final double quantity;
  final String reason;
  final String reference;
}

class _QuickMovementPanel extends StatefulWidget {
  const _QuickMovementPanel({
    required this.item,
    required this.initialType,
    required this.palette,
    required this.onSubmit,
  });

  final ProductosResponseModel item;
  final _QuickMovementType initialType;
  final AppPalette palette;
  final Future<bool> Function(_QuickMovementDraft draft) onSubmit;

  @override
  State<_QuickMovementPanel> createState() => _QuickMovementPanelState();
}

class _QuickMovementPanelState extends State<_QuickMovementPanel> {
  late _InventoryMovementKind _kind;
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _referenceController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialType.defaultKind;
    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController(text: _kind.defaultReason);
    _referenceController = TextEditingController(
      text:
          'MOV-${widget.item.prodId ?? 'PRODUCTO'}-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double get _quantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.')) ??
      0;

  void _changeKind(_InventoryMovementKind value) {
    setState(() {
      _kind = value;
      _reasonController.text = value.defaultReason;
    });
  }

  void _changeQuantity(double delta) {
    final next = math.max(1, _quantity + delta);
    _quantityController.text = _editableNumber(next.toDouble());
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final quantity = _quantity;
    final reason = _reasonController.text.trim();
    final reference = _referenceController.text.trim();
    final stock = widget.item.inventarioActual ?? 0;

    if (quantity <= 0 || reason.isEmpty || reference.isEmpty) return;
    if (!_kind.increasesStock && quantity > stock) return;

    setState(() => _saving = true);
    final ok = await widget.onSubmit(
      _QuickMovementDraft(
        kind: _kind,
        quantity: quantity,
        reason: reason,
        reference: reference,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final type = widget.initialType;
    final name = (widget.item.prodNombre ?? '').trim().isEmpty
        ? 'Producto sin nombre'
        : widget.item.prodNombre!.trim();
    final stock = widget.item.inventarioActual ?? 0;
    final preview = _kind.increasesStock
        ? stock + _quantity
        : math.max(0, stock - _quantity);
    final exceedsStock = !_kind.increasesStock && _quantity > stock;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final operationColor = _kind.color(palette);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final panel = Container(
            width: wide ? 720 : double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.94,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(palette.radius(28)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.34),
                  blurRadius: 34,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: palette.textSecondary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProductImage(
                              value: widget.item.prodFoto,
                              width: 68,
                              height: 68,
                              palette: palette,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Registrar ${type.label.toLowerCase()}',
                                    style: TextStyle(
                                      color: type.increasesStock
                                          ? palette.success
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Stock actual: ${_formatNumber(stock)} unidades',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          type == _QuickMovementType.entry
                              ? 'Tipo de ingreso'
                              : 'Tipo de retiro',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MovementKindSelector(
                          kinds: _movementKindsFor(type),
                          selected: _kind,
                          palette: palette,
                          onSelected: _saving ? null : _changeKind,
                        ),
                        if (_kind == _InventoryMovementKind.sale) ...[
                          const SizedBox(height: 10),
                          _MovementNotice(
                            icon: Icons.info_outline_rounded,
                            message:
                                'La venta normalmente se registra desde el cobro. Usa esta opción solo cuando corresponda a una salida manual autorizada.',
                            color: Colors.orangeAccent,
                            palette: palette,
                          ),
                        ],
                        if (_kind == _InventoryMovementKind.initialEntry &&
                            stock > 0) ...[
                          const SizedBox(height: 10),
                          _MovementNotice(
                            icon: Icons.warning_amber_rounded,
                            message:
                                'El producto ya tiene stock. Verifica que realmente sea una entrada inicial.',
                            color: palette.warning,
                            palette: palette,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: palette.panelDecoration(
                            baseRadius: 18,
                            tint: operationColor,
                            elevated: false,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cantidad en unidades',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  IconButton.outlined(
                                    onPressed: _saving
                                        ? null
                                        : () => _changeQuantity(-1),
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _quantityController,
                                      enabled: !_saving,
                                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 2),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      textAlign: TextAlign.center,
                                      onChanged: (_) => setState(() {}),
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor:
                                            palette.background.withOpacity(0.55),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide:
                                              BorderSide(color: palette.cardBorder),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _saving
                                        ? null
                                        : () => _changeQuantity(1),
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final value in const [1, 5, 10, 20])
                                    ActionChip(
                                      label: Text('$value'),
                                      onPressed: _saving
                                          ? null
                                          : () {
                                              _quantityController.text =
                                                  value.toString();
                                              setState(() {});
                                            },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MovementPreviewValue(
                                      label: 'Stock actual',
                                      value: _formatNumber(stock),
                                      palette: palette,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: operationColor,
                                    ),
                                  ),
                                  Expanded(
                                    child: _MovementPreviewValue(
                                      label: 'Stock resultante',
                                      value: _formatNumber(preview),
                                      palette: palette,
                                      highlighted: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _reasonController,
                          enabled: !_saving,
                          maxLength: 100,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(100)],
                          decoration: const InputDecoration(
                            labelText: 'Motivo',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _referenceController,
                          enabled: !_saving,
                          maxLength: 300,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(300)],
                          decoration: const InputDecoration(
                            labelText: 'Referencia',
                            prefixIcon: Icon(Icons.receipt_long_rounded),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _saving ||
                                        _quantity <= 0 ||
                                        _reasonController.text.trim().isEmpty ||
                                        _referenceController.text.trim().isEmpty ||
                                        exceedsStock
                                    ? null
                                    : _submit,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(type.icon),
                                label: Text(
                                  _saving
                                      ? 'Registrando...'
                                      : 'Registrar ${type.label.toLowerCase()}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (exceedsStock) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'La cantidad de retiro no puede superar el stock actual.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          return Align(
            alignment: Alignment.bottomCenter,
            child: wide
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(palette.radius(28)),
                      ),
                      child: panel,
                    ),
                  )
                : panel,
          );
        },
      ),
    );
  }
}

class _MovementKindSelector extends StatelessWidget {
  const _MovementKindSelector({
    required this.kinds,
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  final List<_InventoryMovementKind> kinds;
  final _InventoryMovementKind selected;
  final AppPalette palette;
  final ValueChanged<_InventoryMovementKind>? onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in kinds)
              SizedBox(
                width: width,
                child: _MovementKindOption(
                  kind: kind,
                  selected: kind == selected,
                  palette: palette,
                  onTap: onSelected == null ? null : () => onSelected!(kind),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MovementKindOption extends StatelessWidget {
  const _MovementKindOption({
    required this.kind,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _InventoryMovementKind kind;
  final bool selected;
  final AppPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = kind.color(palette);
    return Material(
      color: selected
          ? color.withOpacity(0.16)
          : palette.background.withOpacity(
              palette.darkBackground ? 0.44 : 0.72,
            ),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? color.withOpacity(0.72) : palette.cardBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(kind.icon, color: color, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kind.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 5),
                Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementNotice extends StatelessWidget {
  const _MovementNotice({
    required this.icon,
    required this.message,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String message;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementPreviewValue extends StatelessWidget {
  const _MovementPreviewValue({
    required this.label,
    required this.value,
    required this.palette,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: highlighted
            ? palette.secondary.withOpacity(0.12)
            : palette.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlighted
              ? palette.secondary.withOpacity(0.28)
              : palette.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: highlighted ? palette.secondary : palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MovementHistoryFilter { all, entries, exits }
enum _ProductHistoryView { movements, prices }

class _ProductMovementHistoryBottomSheet extends ConsumerStatefulWidget {
  const _ProductMovementHistoryBottomSheet({
    required this.item,
    required this.palette,
  });

  final ProductosResponseModel item;
  final AppPalette palette;

  @override
  ConsumerState<_ProductMovementHistoryBottomSheet> createState() =>
      _ProductMovementHistoryBottomSheetState();
}

class _ProductMovementHistoryBottomSheetState
    extends ConsumerState<_ProductMovementHistoryBottomSheet> {
  bool _loading = true;
  String? _error;
  List<MovimientosResponseModel> _movements = const [];
  List<PreciosResponseModel> _prices = const [];
  Map<int, String> _movementTypeNames = const {};
  _MovementHistoryFilter _filter = _MovementHistoryFilter.all;
  _ProductHistoryView _view = _ProductHistoryView.movements;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadHistory);
  }

  Future<void> _loadHistory() async {
    final productId = widget.item.prodId;
    final branchId = widget.item.sucuId;
    if (productId == null || branchId == null) {
      setState(() {
        _loading = false;
        _error = 'El producto no tiene un identificador o sucursal válidos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final movementsResponse = await client.get<List<MovimientosResponseModel>>(
        '/api/v1/movimientos/producto/$productId/sucursal/$branchId',
        (json) => (json is List ? json : const <Object?>[])
            .whereType<Map>()
            .map(
              (item) => MovimientosResponseModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
      final pricesResponse = await client.get<List<PreciosResponseModel>>(
        '/api/v1/precios/producto/$productId/sucursal/$branchId/historial',
        (json) => (json is List ? json : const <Object?>[])
            .whereType<Map>()
            .map(
              (item) => PreciosResponseModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
      final typesResponse = await client.get<List<Map<String, dynamic>>>(
        '/api/v1/tiposmovimiento',
        (json) => (json is List ? json : const <Object?>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
      );

      final movements = List<MovimientosResponseModel>.of(
        movementsResponse.data ?? const <MovimientosResponseModel>[],
      )..sort(_compareMovementsNewestFirst);
      final prices = List<PreciosResponseModel>.of(
        pricesResponse.data ?? const <PreciosResponseModel>[],
      )..sort(_comparePricesNewestFirst);
      final names = <int, String>{};
      for (final type in typesResponse.data ?? const <Map<String, dynamic>>[]) {
        final id = type['timoId'];
        final name = type['timoNombre']?.toString().trim();
        if (id is num && name != null && name.isNotEmpty) {
          names[id.toInt()] = name;
        }
      }

      if (!mounted) return;
      setState(() {
        _movements = movements;
        _prices = prices;
        _movementTypeNames = names;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No fue posible consultar el historial: $error';
      });
    }
  }

  List<MovimientosResponseModel> get _visibleMovements {
    return _movements.where((movement) {
      final operation = _resolvedMovementOperation(
        movement,
        _movementTypeName(movement),
      );
      return switch (_filter) {
        _MovementHistoryFilter.all => true,
        _MovementHistoryFilter.entries => operation == 'ENTRADA',
        _MovementHistoryFilter.exits => operation == 'SALIDA',
      };
    }).toList(growable: false);
  }

  String _movementTypeName(MovimientosResponseModel movement) {
    final typeId = movement.timoId;
    if (typeId != null) {
      final value = _movementTypeNames[typeId]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Movimiento ${movement.moviId ?? ''}'.trim();
  }

  double get _entryTotal => _movements.fold<double>(0, (total, movement) {
        final operation = _resolvedMovementOperation(
          movement,
          _movementTypeName(movement),
        );
        return operation == 'ENTRADA'
            ? total + (movement.moviCantidad ?? 0.0).abs()
            : total;
      });

  double get _exitTotal => _movements.fold<double>(0, (total, movement) {
        final operation = _resolvedMovementOperation(
          movement,
          _movementTypeName(movement),
        );
        return operation == 'SALIDA'
            ? total + (movement.moviCantidad ?? 0.0).abs()
            : total;
      });

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(palette.radius(28)),
            topRight: Radius.circular(palette.radius(28)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.36),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withOpacity(0.34),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Icons.history_rounded, color: palette.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historial del producto',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.item.prodNombre ?? 'Producto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar historial',
                        onPressed: _loading ? null : _loadHistory,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final palette = widget.palette;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: palette.secondary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: palette.warning, size: 44),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _MovementFilterButton(
                  label: 'Movimientos',
                  selected: _view == _ProductHistoryView.movements,
                  palette: palette,
                  onPressed: () => setState(
                    () => _view = _ProductHistoryView.movements,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MovementFilterButton(
                  label: 'Historial de precios',
                  selected: _view == _ProductHistoryView.prices,
                  palette: palette,
                  onPressed: () => setState(
                    () => _view = _ProductHistoryView.prices,
                  ),
                ),
              ),
            ],
          ),
        ),
        _ProductLastUpdateCard(
          item: widget.item,
          palette: palette,
        ),
        Divider(height: 1, color: palette.cardBorder),
        Expanded(
          child: _view == _ProductHistoryView.movements
              ? _buildMovementHistory()
              : _buildPriceHistory(),
        ),
      ],
    );
  }

  Widget _buildMovementHistory() {
    final palette = widget.palette;
    final visible = _visibleMovements;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MovementSummaryValue(
                      label: 'Movimientos',
                      value: '${_movements.length}',
                      icon: Icons.receipt_long_outlined,
                      color: palette.secondary,
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MovementSummaryValue(
                      label: 'Entradas',
                      value: _formatNumber(_entryTotal),
                      icon: Icons.south_west_rounded,
                      color: palette.success,
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MovementSummaryValue(
                      label: 'Salidas',
                      value: _formatNumber(_exitTotal),
                      icon: Icons.north_east_rounded,
                      color: Colors.redAccent,
                      palette: palette,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MovementFilterButton(
                      label: 'Todos',
                      selected: _filter == _MovementHistoryFilter.all,
                      palette: palette,
                      onPressed: () => setState(
                        () => _filter = _MovementHistoryFilter.all,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _MovementFilterButton(
                      label: 'Entradas',
                      selected: _filter == _MovementHistoryFilter.entries,
                      palette: palette,
                      onPressed: () => setState(
                        () => _filter = _MovementHistoryFilter.entries,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _MovementFilterButton(
                      label: 'Salidas',
                      selected: _filter == _MovementHistoryFilter.exits,
                      palette: palette,
                      onPressed: () => setState(
                        () => _filter = _MovementHistoryFilter.exits,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.cardBorder),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 46,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _movements.isEmpty
                              ? 'Este producto todavía no tiene movimientos.'
                              : 'No hay movimientos para el filtro seleccionado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final movement = visible[index];
                    return _MovementHistoryTile(
                      movement: movement,
                      typeName: _movementTypeName(movement),
                      palette: palette,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPriceHistory() {
    final palette = widget.palette;
    if (_prices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.price_change_outlined,
                size: 46,
                color: palette.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                'Este producto todavía no tiene historial de precios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _MovementSummaryValue(
                  label: 'Versiones',
                  value: '${_prices.length}',
                  icon: Icons.history_rounded,
                  color: palette.secondary,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MovementSummaryValue(
                  label: 'Venta actual',
                  value: _formatNumber(_currentPrice?.precValorVenta),
                  icon: Icons.point_of_sale_rounded,
                  color: palette.success,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MovementSummaryValue(
                  label: 'Compra actual',
                  value: _formatNumber(_currentPrice?.precValorCompra),
                  icon: Icons.shopping_cart_checkout_rounded,
                  color: palette.warning,
                  palette: palette,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.cardBorder),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: _prices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PriceHistoryTile(
              price: _prices[index],
              palette: palette,
            ),
          ),
        ),
      ],
    );
  }

  PreciosResponseModel? get _currentPrice {
    for (final price in _prices) {
      if (price.precEstado == 1) return price;
    }
    return _prices.isEmpty ? null : _prices.first;
  }

}

class _ProductLastUpdateCard extends StatelessWidget {
  const _ProductLastUpdateCard({
    required this.item,
    required this.palette,
  });

  final ProductosResponseModel item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final user = (item.prodCreadoPor ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.secondary.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_calendar_outlined,
              size: 18,
              color: palette.secondary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Última modificación del producto: '
                '${_formatMovementDate(item.prodFechaCambio)}'
                '${user.isEmpty ? '' : ' · $user'}',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceHistoryTile extends StatelessWidget {
  const _PriceHistoryTile({
    required this.price,
    required this.palette,
  });

  final PreciosResponseModel price;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final active = price.precEstado == 1;
    final color = active ? palette.success : palette.textSecondary;
    final user = (price.precRegistradoPor ?? '').trim();
    final start = _formatMovementDate(price.precFechaInicia);
    final endValue = price.precFechaFinaliza?.trim();
    final end = endValue == null || endValue.isEmpty
        ? 'Sin fecha de cierre'
        : _formatMovementDate(endValue);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.38 : 0.66,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  active ? Icons.sell_rounded : Icons.history_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? 'Precio vigente' : 'Precio anterior',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active ? 'VIGENTE' : 'HISTÓRICO',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PriceHistoryValue(
                  label: 'Precio de venta',
                  value: _formatNumber(price.precValorVenta),
                  icon: Icons.point_of_sale_rounded,
                  color: palette.success,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriceHistoryValue(
                  label: 'Precio de compra',
                  value: _formatNumber(price.precValorCompra),
                  icon: Icons.shopping_cart_checkout_rounded,
                  color: palette.warning,
                  palette: palette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MovementMetadataLine(
            icon: Icons.play_circle_outline_rounded,
            text: 'Desde: $start',
            palette: palette,
          ),
          const SizedBox(height: 5),
          _MovementMetadataLine(
            icon: Icons.stop_circle_outlined,
            text: active ? 'Actualmente vigente' : 'Hasta: $end',
            palette: palette,
          ),
          if (user.isNotEmpty) ...[
            const SizedBox(height: 5),
            _MovementMetadataLine(
              icon: Icons.person_outline_rounded,
              text: 'Registrado por: $user',
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceHistoryValue extends StatelessWidget {
  const _PriceHistoryValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
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

class _MovementSummaryValue extends StatelessWidget {
  const _MovementSummaryValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementFilterButton extends StatelessWidget {
  const _MovementFilterButton({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: palette.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: palette.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

class _MovementHistoryTile extends StatelessWidget {
  const _MovementHistoryTile({
    required this.movement,
    required this.typeName,
    required this.palette,
  });

  final MovimientosResponseModel movement;
  final String typeName;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final operation = _resolvedMovementOperation(movement, typeName);
    final entry = operation == 'ENTRADA';
    final exit = operation == 'SALIDA';
    final color = entry
        ? palette.success
        : exit
            ? Colors.redAccent
            : palette.warning;
    final icon = entry
        ? Icons.south_west_rounded
        : exit
            ? Icons.north_east_rounded
            : Icons.swap_vert_rounded;
    final sign = entry
        ? '+'
        : exit
            ? '-'
            : '';
    final effectiveQuantity = (movement.moviCantidad ?? 0.0).abs();
    final capturedQuantity = movement.moviCantidadCapturada?.abs();
    final unit = (movement.moviUnidad ?? '').trim().toUpperCase();
    final factor = movement.moviFactorConversion;
    final motive = (movement.moviMotivo ?? '').trim();
    final reference = (movement.moviReferencia ?? '').trim();
    final user = (movement.moviRegistradoPor ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.38 : 0.66,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        typeName,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${_formatNumber(effectiveQuantity)} u.',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatMovementDate(movement.moviFechaCambio),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (capturedQuantity != null &&
                    (unit == 'PRESENTACION_COMPRA' ||
                        (capturedQuantity - effectiveQuantity).abs() > 0.0001)) ...[
                  const SizedBox(height: 7),
                  _MovementMetadataLine(
                    icon: Icons.inventory_2_outlined,
                    text: 'Capturado: ${_formatNumber(capturedQuantity)} '
                        '${unit == 'PRESENTACION_COMPRA' ? 'presentación(es)' : 'unidad(es)'}'
                        '${factor != null ? ' · factor ${_formatNumber(factor)}' : ''}',
                    palette: palette,
                  ),
                ],
                if (motive.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _MovementMetadataLine(
                    icon: Icons.notes_rounded,
                    text: motive,
                    palette: palette,
                  ),
                ],
                if (reference.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _MovementMetadataLine(
                    icon: Icons.tag_rounded,
                    text: reference,
                    palette: palette,
                  ),
                ],
                if (user.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _MovementMetadataLine(
                    icon: Icons.person_outline_rounded,
                    text: user,
                    palette: palette,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementMetadataLine extends StatelessWidget {
  const _MovementMetadataLine({
    required this.icon,
    required this.text,
    required this.palette,
  });

  final IconData icon;
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: palette.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

int _comparePricesNewestFirst(
  PreciosResponseModel left,
  PreciosResponseModel right,
) {
  DateTime? priceDate(PreciosResponseModel value) {
    return DateTime.tryParse(value.precFechaInicia ?? '') ??
        DateTime.tryParse(value.precFechaCambio ?? '');
  }

  final leftDate = priceDate(left);
  final rightDate = priceDate(right);
  if (leftDate != null && rightDate != null) {
    final comparison = rightDate.compareTo(leftDate);
    if (comparison != 0) return comparison;
  } else if (leftDate != null) {
    return -1;
  } else if (rightDate != null) {
    return 1;
  }
  return (right.precId ?? 0).compareTo(left.precId ?? 0);
}

int _compareMovementsNewestFirst(
  MovimientosResponseModel left,
  MovimientosResponseModel right,
) {
  final leftDate = DateTime.tryParse(left.moviFechaCambio ?? '');
  final rightDate = DateTime.tryParse(right.moviFechaCambio ?? '');
  if (leftDate != null && rightDate != null) {
    final comparison = rightDate.compareTo(leftDate);
    if (comparison != 0) return comparison;
  } else if (leftDate != null) {
    return -1;
  } else if (rightDate != null) {
    return 1;
  }
  return (right.moviId ?? 0).compareTo(left.moviId ?? 0);
}

String _resolvedMovementOperation(
  MovimientosResponseModel movement,
  String typeName,
) {
  final configured = (movement.moviOperacion ?? '').trim().toUpperCase();
  if (configured == 'ENTRADA' || configured == 'SALIDA') return configured;

  final normalized = typeName.trim().toUpperCase();
  const exitNames = <String>[
    'SALIDA',
    'VENTA',
    'NEGATIVO',
    'PRESTAMO SALIENTE',
    'PRÉSTAMO SALIENTE',
  ];
  if (exitNames.any(normalized.contains)) return 'SALIDA';

  const entryNames = <String>[
    'ENTRADA',
    'COMPRA',
    'POSITIVO',
    'DEVOLUCION',
    'DEVOLUCIÓN',
    'PRESTAMO ENTRANTE',
    'PRÉSTAMO ENTRANTE',
  ];
  if (entryNames.any(normalized.contains)) return 'ENTRADA';
  return 'AJUSTE';
}

String _formatMovementDate(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return 'Fecha no disponible';
  final date = DateTime.tryParse(text);
  if (date == null) return text;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

class _ProductEditBottomSheet extends StatefulWidget {
  const _ProductEditBottomSheet({
    required this.item,
    required this.palette,
    required this.marcas,
    required this.tipos,
    required this.onUpdateProduct,
  });

  final ProductosResponseModel item;
  final AppPalette palette;
  final List<MarcasResponseModel> marcas;
  final List<TiposProductoResponseModel> tipos;
  final Future<bool> Function(ProductosResponseModel item, Map<String, dynamic> body) onUpdateProduct;

  @override
  State<_ProductEditBottomSheet> createState() => _ProductEditBottomSheetState();
}

class _ProductEditBottomSheetState extends State<_ProductEditBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageController;
  late final TextEditingController _expirationController;
  late final TextEditingController _purchaseQuantityController;
  late final TextEditingController _purchasePresentationController;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _purchasePriceController;
  int? _typeId;
  int? _brandId;
  bool _purchaseByQuantity = false;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.prodNombre ?? '');
    _descriptionController = TextEditingController(text: item.prodDescripcion ?? '');
    _imageController = TextEditingController(text: item.prodFoto ?? '');
    _expirationController = TextEditingController(text: _dateOnly(item.prodFechaVencimiento) ?? '');
    _purchaseQuantityController = TextEditingController(
      text: item.prodCantidadCompra == null ? '' : _editableNumber(item.prodCantidadCompra!),
    );
    _purchasePresentationController = TextEditingController(
      text: item.prodPresentacionCompra ?? '',
    );
    _minimumController = TextEditingController(
      text: _editableNumber(item.prodStockMinimo ?? 0),
    );
    _maximumController = TextEditingController(
      text: item.prodStockMaximo == null ? '' : _editableNumber(item.prodStockMaximo!),
    );
    _salePriceController = TextEditingController(
      text: item.precioVentaVigente == null
          ? ''
          : _editableNumber(item.precioVentaVigente!),
    );
    _purchasePriceController = TextEditingController(
      text: item.precioCompraVigente == null
          ? ''
          : _editableNumber(item.precioCompraVigente!),
    );
    _typeId = item.tpprId;
    _brandId = item.mrcaId;
    _purchaseByQuantity = item.prodCompraPorCantidad == 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _expirationController.dispose();
    _purchaseQuantityController.dispose();
    _purchasePresentationController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_pickingImage || _saving) return;
    setState(() => _pickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > InputConstraints.imageMaxBytes) {
        if (mounted) _showMessage('La imagen no puede superar 2 MB.');
        return;
      }
      final extension = (file?.extension ?? 'png').toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/png',
      };
      _imageController.text = 'data:$mime;base64,${base64Encode(bytes)}';
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showMessage('No fue posible cargar la imagen: $error');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _selectExpirationDate() async {
    final current = DateTime.tryParse(_expirationController.text.trim());
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _expirationController.text =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    final item = widget.item;
    if (item.prodId == null || item.sucuId == null) {
      _showMessage('El producto no tiene un identificador o sucursal válidos.');
      return;
    }

    final minimum = _parseNullable(_minimumController.text) ?? 0;
    final maximum = _parseNullable(_maximumController.text);
    final purchaseQuantity = _parseNullable(_purchaseQuantityController.text);
    final saleRaw = _salePriceController.text.trim();
    final purchaseRaw = _purchasePriceController.text.trim();
    final salePrice = _parseNullable(saleRaw);
    final purchasePrice = _parseNullable(purchaseRaw);
    final noPriceRequested = saleRaw.isEmpty &&
        purchaseRaw.isEmpty &&
        item.precioVentaVigente == null &&
        item.precioCompraVigente == null;

    if (_purchaseByQuantity &&
        (purchaseQuantity == null || purchaseQuantity <= 0)) {
      _showMessage('Indica cuántas unidades contiene la presentación de compra.');
      return;
    }

    if (!noPriceRequested) {
      if (salePrice == null || salePrice <= 0) {
        _showMessage('Ingresa un precio de venta mayor que cero.');
        return;
      }
      if (purchasePrice == null || purchasePrice <= 0) {
        _showMessage('Ingresa un precio de compra mayor que cero.');
        return;
      }
      final unitPurchasePrice = _purchaseByQuantity
          ? purchasePrice / purchaseQuantity!
          : purchasePrice;
      if (salePrice < unitPurchasePrice) {
        _showMessage(
          'El precio de venta no puede ser menor que el costo unitario de compra.',
        );
        return;
      }
    }

    if (minimum < 0 || (maximum != null && maximum < 0)) {
      _showMessage('Los límites de stock no pueden ser negativos.');
      return;
    }
    if (maximum != null && maximum < minimum) {
      _showMessage('El stock máximo debe ser mayor o igual al mínimo.');
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onUpdateProduct(
      item,
      <String, dynamic>{
        'prodId': item.prodId,
        'sucuId': item.sucuId,
        'tpprId': _typeId,
        'mrcaId': _brandId,
        'prodNombre': _nameController.text.trim(),
        'prodDescripcion': _descriptionController.text.trim(),
        'prodFoto': _imageController.text.trim(),
        'prodFechaVencimiento': _expirationController.text.trim().isEmpty
            ? null
            : _expirationController.text.trim(),
        'prodCompraPorCantidad': _purchaseByQuantity ? 1 : 0,
        'prodCantidadCompra': _purchaseByQuantity ? purchaseQuantity : null,
        'prodPresentacionCompra': _purchaseByQuantity
            ? _purchasePresentationController.text.trim()
            : null,
        'prodStockMinimo': minimum,
        'prodStockMaximo': maximum,
        '_uiPrecioVenta': salePrice,
        '_uiPrecioCompra': purchasePrice,
        '_uiPrecioCambio': !noPriceRequested &&
            salePrice != null &&
            purchasePrice != null &&
            _priceChanged(
              item,
              salePrice,
              purchasePrice,
            ),
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  bool _priceChanged(
    ProductosResponseModel item,
    double salePrice,
    double purchasePrice,
  ) {
    final currentSale = item.precioVentaVigente;
    final currentPurchase = item.precioCompraVigente;
    if (currentSale == null || currentPurchase == null) return true;
    const tolerance = 0.000001;
    return (currentSale - salePrice).abs() > tolerance ||
        (currentPurchase - purchasePrice).abs() > tolerance;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final typeItems = widget.tipos
        .where((item) => item.tpprId != null)
        .map(
          (item) => DropdownMenuItem<int>(
            value: item.tpprId,
            child: Text(item.tpprNombre ?? 'Tipo ${item.tpprId}'),
          ),
        )
        .toList(growable: false);
    final brandItems = widget.marcas
        .where((item) => item.mrcaId != null)
        .map(
          (item) => DropdownMenuItem<int>(
            value: item.mrcaId,
            child: Text(item.mrcaNombre ?? 'Marca ${item.mrcaId}'),
          ),
        )
        .toList(growable: false);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(palette.radius(28)),
              topRight: Radius.circular(palette.radius(28)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.36),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.edit_note_rounded, color: palette.secondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modificar producto',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.item.prodNombre ?? 'Producto',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.cardBorder),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProductEditImageCard(
                          value: _imageController.text,
                          palette: palette,
                          loading: _pickingImage,
                          enabled: !_saving,
                          onPick: _pickImage,
                          onRemove: _imageController.text.trim().isEmpty
                              ? null
                              : () => setState(_imageController.clear),
                        ),
                        const SizedBox(height: 20),
                        _EditSectionTitle(
                          icon: Icons.info_outline_rounded,
                          title: 'Información general',
                          palette: palette,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          maxLength: 120,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(120)],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto',
                            prefixIcon: Icon(Icons.local_bar_outlined),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Ingresa el nombre del producto.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_saving,
                          maxLength: 400,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(400)],
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Ingresa una descripción.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final typeField = DropdownButtonFormField<int>(
                              value: typeItems.any((entry) => entry.value == _typeId) ? _typeId : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de producto',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: typeItems,
                              onChanged: _saving ? null : (value) => setState(() => _typeId = value),
                              validator: (value) => value == null ? 'Selecciona el tipo.' : null,
                            );
                            final brandField = DropdownButtonFormField<int>(
                              value: brandItems.any((entry) => entry.value == _brandId) ? _brandId : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Marca',
                                prefixIcon: Icon(Icons.sell_outlined),
                              ),
                              items: brandItems,
                              onChanged: _saving ? null : (value) => setState(() => _brandId = value),
                              validator: (value) => value == null ? 'Selecciona la marca.' : null,
                            );
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  typeField,
                                  const SizedBox(height: 10),
                                  brandField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: typeField),
                                const SizedBox(width: 10),
                                Expanded(child: brandField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _expirationController,
                          enabled: !_saving,
                          readOnly: true,
                          onTap: _saving ? null : _selectExpirationDate,
                          decoration: InputDecoration(
                            labelText: 'Fecha de vencimiento',
                            hintText: 'Opcional',
                            prefixIcon: const Icon(Icons.event_outlined),
                            suffixIcon: _expirationController.text.isEmpty
                                ? const Icon(Icons.calendar_month_outlined)
                                : IconButton(
                                    tooltip: 'Quitar fecha',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(_expirationController.clear),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _EditSectionTitle(
                          icon: Icons.payments_outlined,
                          title: 'Precios',
                          palette: palette,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Puedes cambiar el precio de venta y de compra desde aquí. '
                          'Si alguno cambia, el precio vigente actual se conserva en el historial.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            String? validatePrice(String? value, String label) {
                              final raw = (value ?? '').trim();
                              if (raw.isEmpty) return null;
                              final parsed = _parseNullable(raw);
                              if (parsed == null || parsed <= 0) {
                                return 'Ingresa $label.';
                              }
                              return null;
                            }

                            final saleField = TextFormField(
                              controller: _salePriceController,
                              enabled: !_saving,
                              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 0),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Precio de venta',
                                prefixIcon: Icon(Icons.point_of_sale_rounded),
                              ),
                              validator: (value) =>
                                  validatePrice(value, 'un precio de venta válido'),
                            );
                            final purchaseField = TextFormField(
                              controller: _purchasePriceController,
                              enabled: !_saving,
                              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 0),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Precio de compra',
                                prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),
                              ),
                              validator: (value) =>
                                  validatePrice(value, 'un precio de compra válido'),
                            );

                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  saleField,
                                  const SizedBox(height: 10),
                                  purchaseField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: saleField),
                                const SizedBox(width: 10),
                                Expanded(child: purchaseField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _EditSectionTitle(
                          icon: Icons.inventory_2_outlined,
                          title: 'Compra e inventario',
                          palette: palette,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: palette.background.withOpacity(palette.darkBackground ? 0.35 : 0.62),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _purchaseByQuantity,
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _purchaseByQuantity = value),
                            title: Text(
                              'Compra por paquete o presentación',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              'Ejemplo: una canasta contiene 24 unidades.',
                              style: TextStyle(color: palette.textSecondary, fontSize: 11),
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          child: !_purchaseByQuantity
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final quantityField = TextFormField(
                                        controller: _purchaseQuantityController,
                                        enabled: !_saving,
                                        inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 2),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Unidades por presentación',
                                          prefixIcon: Icon(Icons.numbers_rounded),
                                        ),
                                      );
                                      final presentationField = TextFormField(
                                        controller: _purchasePresentationController,
                                        enabled: !_saving,
                                        maxLength: 60,
                                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                        inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(60)],
                                        decoration: const InputDecoration(
                                          labelText: 'Nombre de presentación',
                                          hintText: 'Canasta, paquete, caja...',
                                          prefixIcon: Icon(Icons.inventory_outlined),
                                        ),
                                        validator: (value) => _purchaseByQuantity && (value ?? '').trim().isEmpty
                                            ? 'Indica la presentación.'
                                            : null,
                                      );
                                      if (constraints.maxWidth < 560) {
                                        return Column(
                                          children: [
                                            quantityField,
                                            const SizedBox(height: 10),
                                            presentationField,
                                          ],
                                        );
                                      }
                                      return Row(
                                        children: [
                                          Expanded(child: quantityField),
                                          const SizedBox(width: 10),
                                          Expanded(child: presentationField),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final minimumField = TextFormField(
                              controller: _minimumController,
                              enabled: !_saving,
                              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 28, fractionDigits: 2),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Stock mínimo',
                                prefixIcon: Icon(Icons.south_rounded),
                              ),
                            );
                            final maximumField = TextFormField(
                              controller: _maximumController,
                              enabled: !_saving,
                              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 28, fractionDigits: 2),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Stock máximo',
                                hintText: 'Vacío = sin límite',
                                prefixIcon: Icon(Icons.north_rounded),
                              ),
                            );
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  minimumField,
                                  const SizedBox(height: 10),
                                  maximumField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: minimumField),
                                const SizedBox(width: 10),
                                Expanded(child: maximumField),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.cardBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: palette.actionColor,
                            foregroundColor: palette.onAction,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.onAction,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _saving ? 'Guardando...' : 'Guardar cambios',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProductEditImageCard extends StatelessWidget {
  const _ProductEditImageCard({
    required this.value,
    required this.palette,
    required this.loading,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final String value;
  final AppPalette palette;
  final bool loading;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.35 : 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final preview = _ProductImage(
            value: value,
            width: compact ? 128 : 150,
            height: compact ? 128 : 150,
            palette: palette,
          );
          final actions = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            children: [
              Text(
                'Imagen del producto',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona una imagen clara para reconocer el producto rápidamente.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: enabled && !loading ? onPick : null,
                icon: loading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(value.trim().isEmpty ? 'Seleccionar imagen' : 'Cambiar imagen'),
              ),
              if (onRemove != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Quitar imagen'),
                ),
              ],
            ],
          );
          if (compact) {
            return Column(
              children: [
                Center(child: preview),
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              preview,
              const SizedBox(width: 18),
              Expanded(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _EditSectionTitle extends StatelessWidget {
  const _EditSectionTitle({
    required this.icon,
    required this.title,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: palette.secondary),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}


class _SmallQuantityButton extends StatelessWidget {
  const _SmallQuantityButton({
    required this.icon,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final AppPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton.outlined(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: palette.secondary,
          side: BorderSide(color: palette.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }
}


String _editableNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

double? _parseNullable(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String? _dateOnly(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text.length >= 10 ? text.substring(0, 10) : text;
}


class _CompactStockValue extends StatelessWidget {
  const _CompactStockValue({
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
          ),
        ),
      ],
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
          colors: [palette.secondary.withOpacity(0.10), palette.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Icon(Icons.local_bar_rounded, color: palette.secondary, size: math.min(width, height) * 0.34),
    );

    if (imageValue.isEmpty) return placeholder;

    Widget image;
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex < 0) return placeholder;
      try {
        image = Image.memory(base64Decode(imageValue.substring(commaIndex + 1)), fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(imageValue, fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.22), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(math.max(8, math.min(width, height) * 0.10)),
          child: Center(child: image),
        ),
      ),
    );
  }
}

class _SubtleInfoBadge extends StatelessWidget {
  const _SubtleInfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.05) : palette.background.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final foreground = _adaptiveStatusForeground(color, palette);
    final background = Color.alphaBlend(
      color.withOpacity(palette.darkBackground ? 0.20 : 0.13),
      palette.surface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(palette.darkBackground ? 0.68 : 0.48),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 15, color: palette.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textPrimary)),
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
    return _StockStatus(
      label: 'Stock bajo',
      icon: Icons.inventory_2_outlined,
      color: palette.warning,
    );
  }
  return _StockStatus(label: 'Disponible', icon: Icons.check_circle_rounded, color: Colors.greenAccent.shade400);
}

Color _adaptiveStatusForeground(Color color, AppPalette palette) {
  if (palette.darkBackground) {
    return Color.lerp(color, Colors.white, 0.20)!;
  }

  final darkening = color.computeLuminance() > 0.36 ? 0.42 : 0.14;
  return Color.lerp(color, const Color(0xFF0F172A), darkening)!;
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

String _tableMoney(num? value) {
  if (value == null) return '-';
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return r'$' + buffer.toString();
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

String _presentationSummary(ProductosResponseModel item) {
  final quantity = item.prodCantidadCompra;
  final presentation = (item.prodPresentacionCompra ?? '').trim();
  if (quantity != null && presentation.isNotEmpty) {
    final qty = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
    return '$qty $presentation';
  }
  if (presentation.isNotEmpty) return presentation;
  if (quantity != null) return 'Cantidad $quantity';
  return 'Presentación no definida';
}

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
