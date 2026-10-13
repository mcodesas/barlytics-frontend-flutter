import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../productos/data/models/productos_response_model.dart';
import '../../../productos/presentation/providers/productos_provider.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/precios_response_model.dart';

enum _PriceFilter { all, withPrice, withoutPrice, changed }

final _preciosProductosPagedProvider = StateNotifierProvider.autoDispose<
    ProductosPagedNotifier, ProductosPagedState>((ref) {
  return ProductosPagedNotifier(
    ref.watch(productosCrudRepositoryProvider),
    ref.watch(apiClientProvider),
    autoLoad: false,
  );
});


class PreciosListPage extends ConsumerStatefulWidget {
  const PreciosListPage({super.key});

  @override
  ConsumerState<PreciosListPage> createState() => _PreciosListPageState();
}

class _PreciosListPageState extends ConsumerState<PreciosListPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, _PriceDraft> _drafts = <int, _PriceDraft>{};
  final Map<int, ProductosResponseModel> _loadedProducts = <int, ProductosResponseModel>{};
  final Map<int, PreciosResponseModel?> _loadedPrices = <int, PreciosResponseModel?>{};
  final Set<int> _savingProductIds = <int>{};

  Timer? _searchDebounce;
  _PriceFilter _filter = _PriceFilter.all;
  int? _sucursalId;
  int? _initializedBranchId;
  bool _savingAll = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final pagedState = ref.watch(_preciosProductosPagedProvider);
    _sucursalId = branchState.activeBranchId;

    _ensureBranchLoaded(branchState.activeBranchId, pagedState);

    final pageProducts = pagedState.items
        .where((item) => _sucursalId == null || item.sucuId == _sucursalId)
        .toList(growable: false);
    final pagePrices = <int, PreciosResponseModel?>{};
    for (final product in pageProducts) {
      final productId = product.prodId;
      if (productId == null) continue;
      final current = _priceFromProduct(product);
      pagePrices[productId] = current;
      _loadedProducts[productId] = product;
      _loadedPrices[productId] = current;
    }
    _synchronizeDrafts(pageProducts, pagePrices);

    final loading = branchState.loading || pagedState.loading;
    final failure = branchState.failure ?? pagedState.failure;

    if (loading && pageProducts.isEmpty && _filter != _PriceFilter.changed) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [Positioned.fill(child: AppPageBackground()), AppLoader()],
        ),
      );
    }

    if (failure != null && pageProducts.isEmpty && _filter != _PriceFilter.changed) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: AppPageBackground()),
            AppErrorView(message: failure.message, onRetry: _refresh),
          ],
        ),
      );
    }

    final visible = _filter == _PriceFilter.changed
        ? _changedProducts()
        : pageProducts;
    final changed = _pendingDrafts.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    palette.pagePadding.left,
                    palette.pagePadding.top,
                    palette.pagePadding.right,
                    12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _PricingToolbar(
                      palette: palette,
                      searchController: _searchController,
                      filter: _filter,
                      visibleOnPage: visible.length,
                      totalElements: _filter == _PriceFilter.changed ? changed : pagedState.totalElements,
                      changed: changed,
                      loading: loading,
                      branches: branchState.branches,
                      activeBranchId: branchState.activeBranchId,
                      onBranchChanged: _changeBranch,
                      onSearchChanged: _onSearchChanged,
                      onFilterChanged: _changeFilter,
                      onRefresh: _refresh,
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      message: _emptyMessage(pageProducts),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      palette.pagePadding.left,
                      0,
                      palette.pagePadding.right,
                      14,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 1500
                            ? 4
                            : width >= 1040
                                ? 3
                                : width >= 680
                                    ? 2
                                    : 1;
                        final cardHeight = width < 680 ? 438.0 : 408.0;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: cardHeight,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final producto = visible[index];
                              final productId = producto.prodId!;
                              final draft = _drafts[productId]!;
                              final currentPrice = _loadedPrices[productId] ?? _priceFromProduct(producto);
                              return _PriceProductCard(
                                producto: producto,
                                currentPrice: currentPrice,
                                draft: draft,
                                palette: palette,
                                saving: _savingProductIds.contains(productId),
                                onChanged: () => setState(() {}),
                                onReset: () {
                                  draft.reset();
                                  setState(() {});
                                },
                                onSave: () => _saveProduct(producto, currentPrice),
                              );
                            },
                            childCount: visible.length,
                          ),
                        );
                      },
                    ),
                  ),
                if (_filter != _PriceFilter.changed && (pagedState.totalPages > 1 || pagedState.size != 12))
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      palette.pagePadding.left,
                      0,
                      palette.pagePadding.right,
                      changed > 0 ? 126 : 88,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _PricePaginationBar(
                        palette: palette,
                        page: pagedState.page,
                        size: pagedState.size,
                        totalElements: pagedState.totalElements,
                        totalPages: pagedState.totalPages,
                        first: pagedState.first,
                        last: pagedState.last,
                        loading: pagedState.loading,
                        onPrevious: () => ref.read(_preciosProductosPagedProvider.notifier).previousPage(),
                        onNext: () => ref.read(_preciosProductosPagedProvider.notifier).nextPage(),
                        onSizeChanged: (size) => ref.read(_preciosProductosPagedProvider.notifier).changeSize(size),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(child: SizedBox(height: changed > 0 ? 126 : 88)),
              ],
            ),
          ),
          if (changed > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _PendingChangesBar(
                  count: changed,
                  saving: _savingAll,
                  palette: palette,
                  onDiscard: _discardAll,
                  onSave: _saveAll,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _ensureBranchLoaded(int? branchId, ProductosPagedState state) {
    if (branchId == null || branchId == _initializedBranchId) return;
    _initializedBranchId = branchId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_preciosProductosPagedProvider.notifier).load(
            page: 0,
            size: 12,
            query: _searchController.text.trim(),
            sucursalId: branchId,
            clearTipoId: true,
            clearMarcaId: true,
            quickFilter: ProductosQuickFilter.all,
            priceStatus: _priceStatusFor(_filter),
            sortOption: ProductosSortOption.nombreAsc,
          );
    });
  }

  PreciosResponseModel? _priceFromProduct(ProductosResponseModel product) {
    if (product.precioVigenteId == null) return null;
    return PreciosResponseModel(
      precId: product.precioVigenteId,
      prodId: product.prodId,
      sucuId: product.sucuId,
      precEstado: 1,
      precValorVenta: product.precioVentaVigente,
      precValorCompra: product.precioCompraVigente,
      precAplicaImpuesto: product.precioAplicaImpuesto,
      precPorcentajeImpuesto: product.precioPorcentajeImpuesto,
    );
  }

  void _synchronizeDrafts(
    List<ProductosResponseModel> products,
    Map<int, PreciosResponseModel?> currentPrices,
  ) {
    for (final product in products) {
      final productId = product.prodId;
      if (productId == null) continue;
      final current = currentPrices[productId];
      final existing = _drafts[productId];
      if (existing == null) {
        _drafts[productId] = _PriceDraft.fromProduct(current, product);
      } else if (!existing.isDirty) {
        existing.synchronize(current, product);
      }
    }
  }

  List<ProductosResponseModel> _changedProducts() {
    final query = _searchController.text.trim().toLowerCase();
    final result = _pendingDrafts
        .map((entry) => _loadedProducts[entry.key])
        .whereType<ProductosResponseModel>()
        .where((product) {
          if (query.isEmpty) return true;
          return <String>[
            product.prodNombre ?? '',
            product.prodDescripcion ?? '',
            product.prodId?.toString() ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false)
      ..sort((a, b) => (a.prodNombre ?? '').toLowerCase().compareTo((b.prodNombre ?? '').toLowerCase()));
    return result;
  }

  List<MapEntry<int, _PriceDraft>> get _pendingDrafts => _drafts.entries
      .where((entry) => entry.value.isDirty)
      .toList(growable: false);

  ProductosPriceStatus _priceStatusFor(_PriceFilter filter) => switch (filter) {
        _PriceFilter.withPrice => ProductosPriceStatus.withPrice,
        _PriceFilter.withoutPrice => ProductosPriceStatus.withoutPrice,
        _ => ProductosPriceStatus.all,
      };

  String _emptyMessage(List<ProductosResponseModel> pageProducts) {
    if (_filter == _PriceFilter.changed) return 'No hay precios modificados pendientes.';
    if (pageProducts.isEmpty && _searchController.text.trim().isNotEmpty) {
      return 'No hay productos que coincidan con la búsqueda.';
    }
    return switch (_filter) {
      _PriceFilter.withPrice => 'No hay productos con precio vigente en esta sucursal.',
      _PriceFilter.withoutPrice => 'Todos los productos de esta sucursal ya tienen precio.',
      _ => 'No hay productos disponibles en la sucursal.',
    };
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    if (_filter == _PriceFilter.changed) return;
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      ref.read(_preciosProductosPagedProvider.notifier).load(
            page: 0,
            query: value.trim(),
            sucursalId: _sucursalId,
            priceStatus: _priceStatusFor(_filter),
          );
    });
  }

  Future<void> _changeFilter(_PriceFilter value) async {
    if (value == _filter) return;
    setState(() => _filter = value);
    if (value == _PriceFilter.changed) return;
    await ref.read(_preciosProductosPagedProvider.notifier).load(
          page: 0,
          query: _searchController.text.trim(),
          sucursalId: _sucursalId,
          priceStatus: _priceStatusFor(value),
        );
  }

  Future<void> _changeBranch(int? branchId) async {
    if (branchId == null || branchId == _sucursalId) return;

    if (_pendingDrafts.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambiar de sucursal'),
          content: const Text(
            'Hay precios modificados sin guardar. Al cambiar de sucursal se descartarán esos cambios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Descartar y cambiar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }

    _clearDrafts();
    _filter = _PriceFilter.all;
    _searchController.clear();
    _initializedBranchId = branchId;

    await ref.read(branchScopeProvider.notifier).select(branchId);
    if (!mounted) return;
    setState(() => _sucursalId = branchId);
    await ref.read(_preciosProductosPagedProvider.notifier).load(
          page: 0,
          size: 12,
          query: '',
          sucursalId: branchId,
          clearTipoId: true,
          clearMarcaId: true,
          quickFilter: ProductosQuickFilter.all,
          priceStatus: ProductosPriceStatus.all,
          sortOption: ProductosSortOption.nombreAsc,
        );
  }

  void _clearDrafts() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _drafts.clear();
    _loadedProducts.clear();
    _loadedPrices.clear();
  }

  Future<void> _refresh() async {
    await ref.read(_preciosProductosPagedProvider.notifier).load(
          page: _filter == _PriceFilter.changed ? 0 : null,
          query: _searchController.text.trim(),
          sucursalId: _sucursalId,
          priceStatus: _priceStatusFor(_filter),
        );
  }

  Future<bool> _saveProduct(
    ProductosResponseModel product,
    PreciosResponseModel? currentPrice, {
    bool showSuccess = true,
    bool refreshAfter = true,
  }) async {
    final productId = product.prodId;
    if (productId == null) return false;
    final draft = _drafts[productId];
    if (draft == null) return false;

    final validation = draft.validationMessage;
    if (validation != null) {
      _showMessage(validation, error: true);
      return false;
    }

    final sale = draft.saleValue!;
    final purchase = draft.purchaseValue!;
    final branchId = product.sucuId ?? _sucursalId;
    if (branchId == null) {
      _showMessage('No se encontró la sucursal del producto.', error: true);
      return false;
    }

    setState(() => _savingProductIds.add(productId));
    try {
      final appliesTax = currentPrice?.precAplicaImpuesto ?? 0;
      final taxPercentage = currentPrice?.precPorcentajeImpuesto ?? 0;
      final savedResponse = await ref.read(apiClientProvider).post<PreciosResponseModel>(
            '/api/v1/precios',
            <String, dynamic>{
              'prodId': productId,
              'sucuId': branchId,
              'precEstado': 1,
              'precValorVenta': sale,
              'precValorCompra': purchase,
              'precFechaInicia': DateTime.now().toIso8601String(),
              'precAplicaImpuesto': appliesTax,
              'precPorcentajeImpuesto': taxPercentage,
              'precValorImpuesto': appliesTax == 1 ? sale * taxPercentage / 100 : 0,
              'prodCompraPorCantidad': draft.purchaseByQuantity ? 1 : 0,
              'prodCantidadCompra':
                  draft.purchaseByQuantity ? draft.purchaseUnits : null,
              'prodPresentacionCompra':
                  draft.purchaseByQuantity ? draft.purchasePresentation : null,
            },
            (json) => PreciosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
          );
      final saved = savedResponse.data;
      draft.commit(saved, sale: sale, purchase: purchase);
      _loadedPrices[productId] = saved;
      if (refreshAfter) await _refresh();
      if (showSuccess) _showMessage('Precio de ${product.prodNombre ?? 'producto'} actualizado.');
      return true;
    } catch (error) {
      _showMessage('No fue posible guardar el precio: $error', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _savingProductIds.remove(productId));
    }
  }

  Future<void> _saveAll() async {
    final pending = _pendingDrafts;
    if (pending.isEmpty || _savingAll) return;

    for (final entry in pending) {
      final validation = entry.value.validationMessage;
      if (validation != null) {
        _showMessage('Revisa los valores pendientes antes de guardar. $validation', error: true);
        return;
      }
    }

    setState(() => _savingAll = true);
    var saved = 0;
    var failed = 0;

    for (final entry in pending) {
      final product = _loadedProducts[entry.key];
      if (product == null) continue;
      final ok = await _saveProduct(
        product,
        _loadedPrices[entry.key],
        showSuccess: false,
        refreshAfter: false,
      );
      if (ok) {
        saved++;
      } else {
        failed++;
      }
    }

    await _refresh();
    if (!mounted) return;
    setState(() => _savingAll = false);
    if (failed == 0) {
      _showMessage('$saved ${saved == 1 ? 'precio actualizado' : 'precios actualizados'} correctamente.');
    } else {
      _showMessage('$saved precios guardados y $failed sin guardar.', error: true);
    }
  }

  void _discardAll() {
    for (final entry in _pendingDrafts) {
      entry.value.reset();
    }
    setState(() {});
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }
}

class _PricingToolbar extends StatelessWidget {
  const _PricingToolbar({
    required this.palette,
    required this.searchController,
    required this.filter,
    required this.visibleOnPage,
    required this.totalElements,
    required this.changed,
    required this.loading,
    required this.branches,
    required this.activeBranchId,
    required this.onBranchChanged,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final AppPalette palette;
  final TextEditingController searchController;
  final _PriceFilter filter;
  final int visibleOnPage;
  final int totalElements;
  final int changed;
  final bool loading;
  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_PriceFilter> onFilterChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: palette.panelPadding(14),
      decoration: palette.panelDecoration(baseRadius: 24, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final branchSelector = _ActiveBranchSelector(
            palette: palette,
            branches: branches,
            activeBranchId: activeBranchId,
            onChanged: onBranchChanged,
          );

          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PriceFilterButton(
                label: 'Todos',
                icon: Icons.apps_rounded,
                selected: filter == _PriceFilter.all,
                color: palette.secondary,
                onTap: () => onFilterChanged(_PriceFilter.all),
              ),
              _PriceFilterButton(
                label: 'Con precio',
                icon: Icons.sell_rounded,
                selected: filter == _PriceFilter.withPrice,
                color: palette.success,
                onTap: () => onFilterChanged(_PriceFilter.withPrice),
              ),
              _PriceFilterButton(
                label: 'Sin precio',
                icon: Icons.price_change_outlined,
                selected: filter == _PriceFilter.withoutPrice,
                color: palette.warning,
                onTap: () => onFilterChanged(_PriceFilter.withoutPrice),
              ),
              _PriceFilterButton(
                label: changed == 0 ? 'Modificados' : 'Modificados $changed',
                icon: Icons.edit_note_rounded,
                selected: filter == _PriceFilter.changed,
                color: palette.accent,
                onTap: () => onFilterChanged(_PriceFilter.changed),
              ),
            ],
          );

          final status = Row(
            children: [
              Icon(Icons.view_module_rounded, color: palette.secondary, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  filter == _PriceFilter.changed
                      ? '$totalElements cambios pendientes'
                      : 'Mostrando $visibleOnPage de $totalElements productos',
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12.2),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                branchSelector,
                const SizedBox(height: 10),
                search,
                const SizedBox(height: 10),
                filters,
                const SizedBox(height: 8),
                status,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(width: 270, child: branchSelector),
                  const SizedBox(width: 12),
                  Expanded(child: search),
                  const SizedBox(width: 8),
                  SizedBox(width: 240, child: status),
                ],
              ),
              const SizedBox(height: 12),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _ActiveBranchSelector extends StatelessWidget {
  const _ActiveBranchSelector({
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
    final validValue = branches.any((branch) => branch.sucuId == activeBranchId) ? activeBranchId : null;
    return DropdownButtonFormField<int>(
      value: validValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sucursal activa',
        prefixIcon: Icon(Icons.storefront_rounded),
      ).compactFilter(),
      items: branches
          .where((branch) => branch.sucuId != null)
          .map(
            (branch) => DropdownMenuItem<int>(
              value: branch.sucuId,
              child: Text(
                branch.sucuNombre?.trim().isNotEmpty == true ? branch.sucuNombre!.trim() : 'Sucursal ${branch.sucuId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: branches.length <= 1 ? null : onChanged,
    );
  }
}

class _PriceFilterButton extends StatelessWidget {
  const _PriceFilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricePaginationBar extends StatelessWidget {
  const _PricePaginationBar({
    required this.palette,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
    required this.onSizeChanged,
  });

  final AppPalette palette;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final from = totalElements == 0 ? 0 : page * size + 1;
    final to = math.min((page + 1) * size, totalElements);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: palette.panelDecoration(baseRadius: 20, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final pageInfo = Text(
            totalPages == 0 ? 'Página 0 de 0' : 'Página ${page + 1} de $totalPages',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
          );
          final rangeInfo = Text(
            '$from–$to de $totalElements',
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
          );
          final sizeSelector = DropdownButton<int>(
            value: const [12, 24, 48].contains(size) ? size : 12,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(16),
            items: const [12, 24, 48]
                .map((value) => DropdownMenuItem<int>(value: value, child: Text('$value por página')))
                .toList(growable: false),
            onChanged: loading ? null : (value) {
              if (value != null) onSizeChanged(value);
            },
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Página anterior',
                onPressed: first || loading ? null : onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Página siguiente',
                onPressed: last || loading ? null : onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [pageInfo, rangeInfo])), controls]),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: sizeSelector),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [pageInfo, rangeInfo])),
              sizeSelector,
              const SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _PriceProductCard extends StatelessWidget {
  const _PriceProductCard({
    required this.producto,
    required this.currentPrice,
    required this.draft,
    required this.palette,
    required this.saving,
    required this.onChanged,
    required this.onReset,
    required this.onSave,
  });

  final ProductosResponseModel producto;
  final PreciosResponseModel? currentPrice;
  final _PriceDraft draft;
  final AppPalette palette;
  final bool saving;
  final VoidCallback onChanged;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final dirty = draft.isDirty;
    final sale = draft.saleValue;
    final purchase = draft.purchaseValue;
    final purchaseUnits = draft.purchaseUnits;
    final purchasePresentation = draft.purchasePresentation;
    final unitPurchaseCost = purchase == null
        ? null
        : !draft.purchaseByQuantity || purchaseUnits == null
            ? purchase
            : purchase / purchaseUnits;
    final margin = sale != null && unitPurchaseCost != null && sale > 0
        ? ((sale - unitPurchaseCost) / sale) * 100
        : null;
    final purchaseFieldLabel = purchaseUnits == null
        ? 'Precio de compra'
        : 'Compra $purchasePresentation (${_formatQuantity(purchaseUnits)} und.)';
    final highlight = dirty ? palette.accent : palette.secondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: palette.panelGradient(tint: highlight),
        borderRadius: BorderRadius.circular(palette.radius(22)),
        border: Border.all(color: highlight.withOpacity(dirty ? 0.62 : 0.16), width: dirty ? 1.5 : 1),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ProductImage(value: producto.prodFoto, size: 62, palette: palette),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.prodNombre?.trim().isNotEmpty == true ? producto.prodNombre!.trim() : 'Producto ${producto.prodId ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15.5, height: 1.1),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Código ${producto.prodId ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5),
                          ),
                        ),
                        if (draft.purchaseByQuantity && purchaseUnits != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.secondary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$purchasePresentation x${_formatQuantity(purchaseUnits)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 10.2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: (currentPrice == null ? palette.warning : palette.success).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  currentPrice == null ? 'Sin precio' : 'Vigente',
                  style: TextStyle(
                    color: currentPrice == null ? palette.warning : palette.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MoneyField(
                  label: 'Precio de venta',
                  controller: draft.saleController,
                  palette: palette,
                  accentColor: palette.success,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => draft.validationMessage == null ? onSave() : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyField(
                  label: purchaseFieldLabel,
                  controller: draft.purchaseController,
                  palette: palette,
                  accentColor: palette.secondary,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => draft.validationMessage == null ? onSave() : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '¿El precio de compra corresponde a varias unidades?',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: draft.purchaseByQuantity,
                      onChanged: saving
                          ? null
                          : (value) {
                              draft.setPurchaseByQuantity(value);
                              onChanged();
                            },
                    ),
                  ],
                ),
                if (draft.purchaseByQuantity) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: draft.unitsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: InputConstraints.decimalFormatters(
                            integerDigits: 10,
                            fractionDigits: 4,
                          ),
                          onChanged: (_) => onChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Unidades de compra',
                            hintText: 'Ej. 24',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: draft.presentationController,
                          maxLength: 60,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          onChanged: (_) => onChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Presentación',
                            hintText: 'Caja, canasta, paquete...',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (purchaseUnits != null) ...[
                    const SizedBox(height: 7),
                    _PurchaseUnitCostSummary(
                      palette: palette,
                      presentation: purchasePresentation,
                      units: purchaseUnits,
                      totalPurchase: purchase,
                      unitPurchaseCost: unitPurchaseCost,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickAmountButton(label: '−500', palette: palette, onTap: () {
                draft.changeSaleBy(-500);
                onChanged();
              }),
              const SizedBox(width: 6),
              _QuickAmountButton(label: '+500', palette: palette, onTap: () {
                draft.changeSaleBy(500);
                onChanged();
              }),
              const SizedBox(width: 6),
              _QuickAmountButton(label: '+1.000', palette: palette, onTap: () {
                draft.changeSaleBy(1000);
                onChanged();
              }),
              const Spacer(),
              if (dirty)
                IconButton(
                  tooltip: 'Deshacer cambio',
                  visualDensity: VisualDensity.compact,
                  onPressed: saving ? null : onReset,
                  icon: const Icon(Icons.undo_rounded),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _MarginIndicator(margin: margin, sale: sale, purchase: unitPurchaseCost, palette: palette)),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: saving || !dirty || draft.validationMessage != null ? null : onSave,
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(currentPrice == null ? 'Crear' : 'Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseUnitCostSummary extends StatelessWidget {
  const _PurchaseUnitCostSummary({
    required this.palette,
    required this.presentation,
    required this.units,
    required this.totalPurchase,
    required this.unitPurchaseCost,
  });

  final AppPalette palette;
  final String presentation;
  final double units;
  final double? totalPurchase;
  final double? unitPurchaseCost;

  @override
  Widget build(BuildContext context) {
    final hasValue = totalPurchase != null && totalPurchase! > 0 && unitPurchaseCost != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: palette.secondary, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasValue
                  ? '$presentation de ${_formatQuantity(units)} unidades · costo unitario ${_formatMoney(unitPurchaseCost)}'
                  : 'Ingresa el costo total del $presentation; el costo unitario se calcula automáticamente.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasValue ? palette.textPrimary : palette.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11.2,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.label,
    required this.controller,
    required this.palette,
    required this.accentColor,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final AppPalette palette;
  final Color accentColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 0),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixText: r'$ ',
        prefixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w900),
        isDense: true,
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({required this.label, required this.palette, required this.onTap});

  final String label;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.secondary.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Text(label, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ),
      ),
    );
  }
}

class _MarginIndicator extends StatelessWidget {
  const _MarginIndicator({required this.margin, required this.sale, required this.purchase, required this.palette});

  final double? margin;
  final double? sale;
  final double? purchase;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final currentSale = sale;
    final currentPurchase = purchase;
    final isLoss = currentSale != null &&
        currentPurchase != null &&
        currentSale < currentPurchase;
    final color = isLoss ? Theme.of(context).colorScheme.error : palette.success;
    final label = margin == null
        ? 'Completa ambos valores'
        : isLoss
            ? 'Venta menor a compra'
            : 'Margen ${margin!.toStringAsFixed(1)}%';
    return Row(
      children: [
        Icon(isLoss ? Icons.warning_amber_rounded : Icons.trending_up_rounded, size: 17, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _PendingChangesBar extends StatelessWidget {
  const _PendingChangesBar({
    required this.count,
    required this.saving,
    required this.palette,
    required this.onDiscard,
    required this.onSave,
  });

  final int count;
  final bool saving;
  final AppPalette palette;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.98 : 1),
            borderRadius: BorderRadius.circular(palette.radius(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final summary = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: palette.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.edit_note_rounded, color: palette.accent),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$count ${count == 1 ? 'cambio pendiente' : 'cambios pendientes'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                        Text('Puedes seguir editando y guardar todo al final.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Row(
                children: [
                  Expanded(child: TextButton(onPressed: saving ? null : onDiscard, child: const Text('Descartar'))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Guardar todo'),
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(children: [summary, const SizedBox(height: 10), actions]);
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  SizedBox(width: 280, child: actions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.value, required this.size, required this.palette});

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
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.local_bar_rounded, color: palette.secondary, size: 28),
    );
    if (imageValue.isEmpty) return placeholder;

    Widget image;
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex < 0) return placeholder;
      try {
        image = Image.memory(
          base64Decode(imageValue.substring(commaIndex + 1)),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(imageValue, fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(math.max(6, size * 0.09)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: image),
    );
  }
}

class _PriceDraft {
  _PriceDraft({
    required this.saleController,
    required this.purchaseController,
    required this.unitsController,
    required this.presentationController,
    required this.purchaseByQuantity,
    required this.originalSale,
    required this.originalPurchase,
    required this.originalPurchaseByQuantity,
    required this.originalPurchaseUnits,
    required this.originalPresentation,
    required this.priceId,
  });

  factory _PriceDraft.fromProduct(
    PreciosResponseModel? price,
    ProductosResponseModel product,
  ) =>
      _PriceDraft(
        saleController: TextEditingController(text: _editableNumber(price?.precValorVenta)),
        purchaseController: TextEditingController(text: _editableNumber(price?.precValorCompra)),
        unitsController: TextEditingController(text: _editableNumber(product.prodCantidadCompra)),
        presentationController:
            TextEditingController(text: product.prodPresentacionCompra ?? ''),
        purchaseByQuantity: (product.prodCompraPorCantidad ?? 0) == 1,
        originalSale: price?.precValorVenta,
        originalPurchase: price?.precValorCompra,
        originalPurchaseByQuantity: (product.prodCompraPorCantidad ?? 0) == 1,
        originalPurchaseUnits: product.prodCantidadCompra,
        originalPresentation: product.prodPresentacionCompra ?? '',
        priceId: price?.precId,
      );

  final TextEditingController saleController;
  final TextEditingController purchaseController;
  final TextEditingController unitsController;
  final TextEditingController presentationController;

  bool purchaseByQuantity;
  double? originalSale;
  double? originalPurchase;
  bool originalPurchaseByQuantity;
  double? originalPurchaseUnits;
  String originalPresentation;
  int? priceId;

  double? get saleValue => _parseMoney(saleController.text);
  double? get purchaseValue => _parseMoney(purchaseController.text);
  double? get purchaseUnits => _parseMoney(unitsController.text);
  String get purchasePresentation {
    final value = presentationController.text.trim();
    return value.isEmpty ? 'Paquete' : value;
  }

  bool get isDirty =>
      !_sameNumber(saleValue, originalSale) ||
      !_sameNumber(purchaseValue, originalPurchase) ||
      purchaseByQuantity != originalPurchaseByQuantity ||
      !_sameNumber(purchaseUnits, originalPurchaseUnits) ||
      presentationController.text.trim() != originalPresentation.trim();

  String? get validationMessage {
    if ((saleController.text.trim().isEmpty && purchaseController.text.trim().isEmpty) && !isDirty) return null;
    if (saleValue == null || saleValue! <= 0) return 'El precio de venta debe ser mayor que cero.';
    if (purchaseValue == null || purchaseValue! <= 0) return 'El precio de compra debe ser mayor que cero.';
    if (purchaseByQuantity) {
      if (purchaseUnits == null || purchaseUnits! <= 1) {
        return 'Indica cuántas unidades trae la compra; debe ser mayor que 1.';
      }
      if (presentationController.text.trim().isEmpty) {
        return 'Indica la presentación de compra: caja, canasta, paquete, etc.';
      }
    }
    return null;
  }

  void setPurchaseByQuantity(bool value) {
    purchaseByQuantity = value;
    if (!value) {
      unitsController.clear();
      presentationController.clear();
    } else {
      if (unitsController.text.trim().isEmpty) unitsController.text = '2';
      if (presentationController.text.trim().isEmpty) {
        presentationController.text = 'Paquete';
      }
    }
  }

  void changeSaleBy(double amount) {
    final next = math.max(0, (saleValue ?? originalSale ?? 0) + amount).toDouble();
    saleController.text = _editableNumber(next);
    saleController.selection = TextSelection.collapsed(offset: saleController.text.length);
  }

  void reset() {
    saleController.text = _editableNumber(originalSale);
    purchaseController.text = _editableNumber(originalPurchase);
    purchaseByQuantity = originalPurchaseByQuantity;
    unitsController.text = _editableNumber(originalPurchaseUnits);
    presentationController.text = originalPresentation;
  }

  void synchronize(
    PreciosResponseModel? price,
    ProductosResponseModel product,
  ) {
    originalSale = price?.precValorVenta;
    originalPurchase = price?.precValorCompra;
    originalPurchaseByQuantity = (product.prodCompraPorCantidad ?? 0) == 1;
    originalPurchaseUnits = product.prodCantidadCompra;
    originalPresentation = product.prodPresentacionCompra ?? '';
    priceId = price?.precId;
    reset();
  }

  void commit(
    PreciosResponseModel? price, {
    required double sale,
    required double purchase,
  }) {
    originalSale = price?.precValorVenta ?? sale;
    originalPurchase = price?.precValorCompra ?? purchase;
    originalPurchaseByQuantity = purchaseByQuantity;
    originalPurchaseUnits = purchaseByQuantity ? purchaseUnits : null;
    originalPresentation =
        purchaseByQuantity ? presentationController.text.trim() : '';
    priceId = price?.precId ?? priceId;
    reset();
  }

  void dispose() {
    saleController.dispose();
    purchaseController.dispose();
    unitsController.dispose();
    presentationController.dispose();
  }
}

String _formatQuantity(num value) {
  final number = value.toDouble();
  return number % 1 == 0 ? number.toInt().toString() : number.toStringAsFixed(2);
}

String _formatMoney(num? value) {
  if (value == null) return '-';
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final remaining = rounded.length - i;
    buffer.write(rounded[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '\$${buffer.toString()}';
}

double? _parseMoney(String value) {
  var normalized = value.trim().replaceAll(RegExp(r'\s'), '');
  if (normalized.isEmpty) return null;
  final lastComma = normalized.lastIndexOf(',');
  final lastDot = normalized.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final decimals = normalized.length - lastComma - 1;
    normalized = decimals == 3 ? normalized.replaceAll(',', '') : normalized.replaceAll(',', '.');
  } else if (lastDot >= 0) {
    final decimals = normalized.length - lastDot - 1;
    if (decimals == 3) normalized = normalized.replaceAll('.', '');
  }
  return double.tryParse(normalized);
}

String _editableNumber(num? value) {
  if (value == null) return '';
  final number = value.toDouble();
  return number % 1 == 0 ? number.toInt().toString() : number.toStringAsFixed(2);
}

bool _sameNumber(num? a, num? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return (a.toDouble() - b.toDouble()).abs() < 0.0001;
}

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
