import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../productos/data/models/productos_response_model.dart';
import '../../data/models/movimientos_response_model.dart';

const String _movementUnit = 'UNIDAD';
const String _purchasePresentationUnit = 'PRESENTACION_COMPRA';

class MovimientosListPage extends ConsumerStatefulWidget {
  const MovimientosListPage({super.key});

  @override
  ConsumerState<MovimientosListPage> createState() => _MovimientosListPageState();
}

class _MovimientosListPageState extends ConsumerState<MovimientosListPage> {
  final _searchController = TextEditingController();
  final _referenceController = TextEditingController();
  final _reasonController = TextEditingController();

  Timer? _searchDebounce;
  List<_MovementTypeOption> _movementTypes = const [];
  _MovementTypeOption? _selectedType;
  List<ProductosResponseModel> _products = const [];
  final Map<int, _SelectedMovementProduct> _selectedProducts = {};

  bool _loadingTypes = true;
  bool _loadingProducts = false;
  bool _saving = false;
  String? _typeError;
  String? _productError;
  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  int? _activeBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMovementTypes());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _referenceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadMovementTypes() async {
    if (!mounted) return;
    setState(() {
      _loadingTypes = true;
      _typeError = null;
    });

    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
            '/api/v1/tiposmovimiento',
            (json) => (json as List? ?? const <dynamic>[])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false),
          );
      final values = (response.data ?? const <Map<String, dynamic>>[])
          .map(_MovementTypeOption.fromJson)
          .where((item) => item.id != null && item.name.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) {
          final left = _movementOrder(a.normalizedName);
          final right = _movementOrder(b.normalizedName);
          if (left != right) return left.compareTo(right);
          return a.name.compareTo(b.name);
        });

      if (!mounted) return;
      setState(() {
        _movementTypes = values;
        _loadingTypes = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _typeError = _readableError(error);
      });
    }
  }

  Future<void> _openMovement(_MovementTypeOption type) async {
    var resolvedType = type;
    if (type.isAdjustment) {
      final operation = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.70),
        builder: (dialogContext) => _MovementDirectionDialog(
          palette: ref.read(selectedAppPaletteProvider),
        ),
      );
      if (operation == null || !mounted) return;
      resolvedType = type.withResolvedOperation(operation);
    }

    final branchState = ref.read(branchScopeProvider);
    final branchId = branchState.activeBranchId ??
        (branchState.branches.length == 1 ? branchState.branches.first.sucuId : null);

    if (branchId == null) {
      _showMessage('Selecciona una sucursal antes de registrar movimientos.');
      return;
    }

    setState(() {
      _selectedType = resolvedType;
      _activeBranchId = branchId;
      _selectedProducts.clear();
      _searchController.clear();
      _referenceController.clear();
      _reasonController.text = resolvedType.name;
      _page = 0;
    });
    await _loadProducts(page: 0);
  }

  Future<void> _closeMovement() async {
    if (_selectedProducts.isNotEmpty) {
      final close = await _confirm(
        title: 'Salir del registro',
        message: 'Hay productos agregados. ¿Deseas descartarlos y volver a los tipos de movimiento?',
        confirmLabel: 'Descartar',
      );
      if (!close) return;
    }
    if (!mounted) return;
    setState(() {
      _selectedType = null;
      _products = const [];
      _selectedProducts.clear();
      _productError = null;
      _searchController.clear();
      _referenceController.clear();
      _reasonController.clear();
      _page = 0;
      _totalPages = 0;
      _totalElements = 0;
    });
  }

  Future<void> _changeBranch(int? branchId) async {
    if (branchId == null || branchId == _activeBranchId) return;
    if (_selectedProducts.isNotEmpty) {
      final change = await _confirm(
        title: 'Cambiar sucursal',
        message: 'Los productos agregados pertenecen a la sucursal actual y se eliminarán del registro.',
        confirmLabel: 'Cambiar',
      );
      if (!change) return;
    }

    await ref.read(branchScopeProvider.notifier).select(branchId);
    if (!mounted) return;
    setState(() {
      _activeBranchId = branchId;
      _selectedProducts.clear();
      _page = 0;
    });
    if (_selectedType != null) await _loadProducts(page: 0);
  }

  void _onSearchChanged(String value) {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _selectedType == null) return;
      _loadProducts(page: 0);
    });
  }

  Future<void> _loadProducts({required int page}) async {
    final branchId = _activeBranchId;
    if (branchId == null) return;

    setState(() {
      _loadingProducts = true;
      _productError = null;
    });

    try {
      final response = await ref.read(apiClientProvider).get<ProductosPageResponseModel>(
            '/api/v1/productos/page',
            (json) => ProductosPageResponseModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
            queryParameters: <String, dynamic>{
              'page': page,
              'size': 16,
              'sortBy': 'nombre',
              'direction': 'ASC',
              'sucursalId': branchId,
              if (_searchController.text.trim().isNotEmpty)
                'q': _searchController.text.trim(),
            },
          );
      final result = response.data ?? const ProductosPageResponseModel();
      if (!mounted) return;
      setState(() {
        _products = result.content;
        _page = result.page;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
        _loadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productError = _readableError(error);
      });
    }
  }

  void _addProduct(ProductosResponseModel product) {
    final productId = product.prodId;
    if (productId == null) return;

    final type = _selectedType;
    if (type == null) return;

    final currentStock = product.inventarioActual ?? 0.0;
    if (type.isOutbound && currentStock <= 0) {
      _showMessage('Este producto no tiene stock disponible.');
      return;
    }

    final purchaseFactor = product.prodCantidadCompra ?? 0.0;
    final captureByPresentation = type.isPurchaseEntry &&
        product.prodCompraPorCantidad == 1 &&
        purchaseFactor > 1;

    setState(() {
      _selectedProducts[productId] = _SelectedMovementProduct(
        product: product,
        quantity: 1,
        quantityUnit: captureByPresentation
            ? _purchasePresentationUnit
            : _movementUnit,
      );
    });
  }

  void _removeProduct(int productId) {
    setState(() => _selectedProducts.remove(productId));
  }

  void _changeQuantity(int productId, double delta) {
    final selected = _selectedProducts[productId];
    final type = _selectedType;
    if (selected == null || type == null) return;

    final next = selected.quantity + delta;
    if (next <= 0) {
      _removeProduct(productId);
      return;
    }

    final updated = selected.copyWith(quantity: next);
    if (type.isOutbound &&
        updated.effectiveQuantity >
            (selected.product.inventarioActual ?? 0.0)) {
      _showMessage('La cantidad no puede superar el stock disponible.');
      return;
    }

    setState(() {
      _selectedProducts[productId] = updated;
    });
  }

  Future<void> _editQuantity(int productId) async {
    final selected = _selectedProducts[productId];
    final type = _selectedType;
    if (selected == null || type == null) return;

    final value = await showDialog<double>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.70),
      builder: (dialogContext) => _QuantityDialog(
        initialValue: selected.quantity,
        maxValue: type.isOutbound
            ? (selected.product.inventarioActual ?? 0.0) /
                selected.conversionFactor
            : null,
        quantityLabel: selected.usesPurchasePresentation
            ? (selected.product.prodPresentacionCompra ?? 'Paquetes')
            : 'Unidades',
        allowDecimals: !selected.usesPurchasePresentation,
        palette: ref.read(selectedAppPaletteProvider),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _selectedProducts[productId] = selected.copyWith(quantity: value);
    });
  }

  Future<void> _registerMovements() async {
    final type = _selectedType;
    final branchId = _activeBranchId;
    final reference = _referenceController.text.trim();
    final reason = _reasonController.text.trim();

    if (type?.id == null || branchId == null) {
      _showMessage('No hay un tipo de movimiento o sucursal válidos.');
      return;
    }
    if (_selectedProducts.isEmpty) {
      _showMessage('Agrega por lo menos un producto.');
      return;
    }
    if (reference.isEmpty) {
      _showMessage('Ingresa una referencia, factura, persona o documento.');
      return;
    }
    if (reason.isEmpty) {
      _showMessage('Ingresa el motivo del movimiento.');
      return;
    }

    for (final selected in _selectedProducts.values) {
      if (selected.quantity <= 0) {
        _showMessage('Todas las cantidades deben ser mayores que cero.');
        return;
      }
      if (type!.isOutbound &&
          selected.effectiveQuantity >
              (selected.product.inventarioActual ?? 0.0)) {
        _showMessage(
          '${selected.product.prodNombre ?? 'Producto'} supera el stock disponible.',
        );
        return;
      }
    }

    final confirmed = await _confirm(
      title: 'Registrar ${type!.name.toLowerCase()}',
      message:
          'Se registrarán ${_selectedProducts.length} productos en una sola transacción. ¿Deseas continuar?',
      confirmLabel: 'Registrar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final response = await ref.read(apiClientProvider).post<List<MovimientosResponseModel>>(
            '/api/v1/movimientos/lote',
            <String, dynamic>{
              'sucuId': branchId,
              'timoId': type.id,
              'moviOperacion': type.effectiveOperation,
              'moviMotivo': reason,
              'moviReferencia': reference,
              'items': _selectedProducts.values
                  .map(
                    (selected) => <String, dynamic>{
                      'prodId': selected.product.prodId,
                      'moviCantidad': selected.quantity,
                      'moviUnidad': selected.quantityUnit,
                    },
                  )
                  .toList(growable: false),
            },
            (json) => (json as List? ?? const <dynamic>[])
                .whereType<Map>()
                .map(
                  (item) => MovimientosResponseModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false),
          );

      if (!mounted) return;
      final completed = response.data?.length ?? _selectedProducts.length;
      setState(() {
        _saving = false;
        _selectedProducts.clear();
      });
      _referenceController.clear();
      _reasonController.text = type.name;
      _showMessage(
        '$completed ${completed == 1 ? 'movimiento registrado' : 'movimientos registrados'} correctamente.',
        success: true,
      );
      await _loadProducts(page: _page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(_readableError(error));
      await _loadProducts(page: _page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);

    final resolvedBranchId = branchState.activeBranchId ??
        (branchState.branches.length == 1 ? branchState.branches.first.sucuId : null);
    if (_activeBranchId == null && resolvedBranchId != null) {
      _activeBranchId = resolvedBranchId;
    }

    return TechBackground(
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _selectedType == null
              ? _buildTypeDashboard(palette, branchState)
              : _buildOperationWorkspace(palette, branchState),
        ),
      ),
    );
  }

  Widget _buildTypeDashboard(AppPalette palette, BranchScopeState branchState) {
    return SingleChildScrollView(
      key: const ValueKey('movement-types'),
      padding: palette.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MovementDashboardHeader(
                palette: palette,
                branches: branchState,
                activeBranchId: _activeBranchId,
                onBranchChanged: _changeBranch,
              ),
              const SizedBox(height: 18),
              if (_loadingTypes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(42),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_typeError != null)
                _ErrorPanel(
                  message: _typeError!,
                  palette: palette,
                  onRetry: _loadMovementTypes,
                )
              else if (_movementTypes.isEmpty)
                _EmptyPanel(
                  palette: palette,
                  icon: Icons.sync_alt_rounded,
                  title: 'No hay tipos de movimiento',
                  message: 'Configura los tipos de movimiento para comenzar.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth >= 1100
                        ? (constraints.maxWidth - 36) / 3
                        : constraints.maxWidth >= 690
                            ? (constraints.maxWidth - 18) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: _movementTypes
                          .map(
                            (type) => SizedBox(
                              width: itemWidth,
                              child: _MovementTypeCard(
                                type: type,
                                palette: palette,
                                onTap: () => _openMovement(type),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationWorkspace(AppPalette palette, BranchScopeState branchState) {
    final type = _selectedType!;
    final selected = _selectedProducts.values.toList(growable: false);

    return LayoutBuilder(
      key: ValueKey('movement-${type.id}'),
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050;
        final catalog = _ProductCatalogPanel(
          palette: palette,
          type: type,
          branches: branchState,
          activeBranchId: _activeBranchId,
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onBranchChanged: _changeBranch,
          products: _products,
          selectedProducts: _selectedProducts,
          loading: _loadingProducts,
          error: _productError,
          totalElements: _totalElements,
          page: _page,
          totalPages: _totalPages,
          onRetry: () => _loadProducts(page: _page),
          onAdd: _addProduct,
          onRemove: _removeProduct,
          onPrevious: _page > 0 ? () => _loadProducts(page: _page - 1) : null,
          onNext: _page + 1 < _totalPages ? () => _loadProducts(page: _page + 1) : null,
        );

        final summary = _MovementSummaryPanel(
          palette: palette,
          scrollProducts: desktop,
          type: type,
          products: selected,
          referenceController: _referenceController,
          reasonController: _reasonController,
          saving: _saving,
          onDecrease: (id) => _changeQuantity(id, -1),
          onIncrease: (id) => _changeQuantity(id, 1),
          onEditQuantity: _editQuantity,
          onRemove: _removeProduct,
          onRegister: _registerMovements,
        );

        return Column(
          children: [
            _OperationTopBar(
              palette: palette,
              type: type,
              selectedCount: selected.length,
              onBack: _closeMovement,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18 * palette.spacingScale,
                  0,
                  18 * palette.spacingScale,
                  18 * palette.spacingScale,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: desktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: catalog),
                              const SizedBox(width: 18),
                              SizedBox(width: 410, child: summary),
                            ],
                          )
                        : ListView(
                            children: [
                              SizedBox(
                                height: (constraints.maxHeight * 0.66).clamp(500.0, 680.0).toDouble(),
                                child: catalog,
                              ),
                              const SizedBox(height: 16),
                              summary,
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final palette = ref.read(selectedAppPaletteProvider);
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.72),
          builder: (dialogContext) => AlertDialog(
        scrollable: true,
            backgroundColor: palette.surface,
            elevation: 24,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(palette.radius(24)),
              side: BorderSide.none,
            ),
            title: Text(title, style: TextStyle(color: palette.textPrimary)),
            content: Text(message, style: TextStyle(color: palette.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.actionColor,
                  foregroundColor: palette.onAction,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    final palette = ref.read(selectedAppPaletteProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: success ? palette.success : Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

class _MovementDashboardHeader extends StatelessWidget {
  const _MovementDashboardHeader({
    required this.palette,
    required this.branches,
    required this.activeBranchId,
    required this.onBranchChanged,
  });

  final AppPalette palette;
  final BranchScopeState branches;
  final int? activeBranchId;
  final ValueChanged<int?> onBranchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: palette.panelPadding(20),
      decoration: _panelDecoration(palette, tint: palette.secondary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona la operación',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige el tipo de movimiento y luego agrega todos los productos de la misma operación.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          );

          final branchSelector = branches.branches.length > 1
              ? SizedBox(
                  width: compact ? double.infinity : 280,
                  child: DropdownButtonFormField<int>(
                    value: activeBranchId,
                    dropdownColor: palette.surface,
                    decoration: InputDecoration(
                      labelText: 'Sucursal',
                      prefixIcon: const Icon(Icons.storefront_rounded),
                      filled: true,
                      fillColor: palette.background.withOpacity(0.42),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(palette.radius(16)),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(palette.radius(16)),
                        borderSide: BorderSide.none,
                      ),
                    ).compactFilter(),
                    items: branches.branches
                        .where((branch) => branch.sucuId != null)
                        .map(
                          (branch) => DropdownMenuItem<int>(
                            value: branch.sucuId,
                            child: Text(branch.sucuNombre ?? 'Sucursal ${branch.sucuId}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onBranchChanged,
                  ),
                )
              : const SizedBox.shrink();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                if (branches.branches.length > 1) ...[
                  const SizedBox(height: 16),
                  branchSelector,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: intro),
              if (branches.branches.length > 1) ...[
                const SizedBox(width: 18),
                branchSelector,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MovementTypeCard extends StatelessWidget {
  const _MovementTypeCard({
    required this.type,
    required this.palette,
    required this.onTap,
  });

  final _MovementTypeOption type;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _movementVisual(type.normalizedName, palette);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _panelDecoration(palette, tint: visual.color),
        child: InkWell(
          borderRadius: BorderRadius.circular(palette.radius(22)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 154),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: visual.color.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(visual.icon, color: visual.color, size: 25),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: visual.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          type.directionLabel,
                          style: TextStyle(
                            color: visual.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    type.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.effectiveDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationTopBar extends StatelessWidget {
  const _OperationTopBar({
    required this.palette,
    required this.type,
    required this.selectedCount,
    required this.onBack,
  });

  final AppPalette palette;
  final _MovementTypeOption type;
  final int selectedCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final visual = _movementVisual(type.normalizedName, palette);
    return Padding(
      padding: EdgeInsets.all(18 * palette.spacingScale),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _panelDecoration(palette, tint: visual.color),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Volver a tipos de movimiento',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(visual.icon, color: visual.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        type.effectiveOperation == 'ENTRADA'
                            ? 'Esta operación aumentará el inventario'
                            : 'Esta operación disminuirá el inventario',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: visual.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$selectedCount ${selectedCount == 1 ? 'producto' : 'productos'}',
                    style: TextStyle(
                      color: visual.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCatalogPanel extends StatelessWidget {
  const _ProductCatalogPanel({
    required this.palette,
    required this.type,
    required this.branches,
    required this.activeBranchId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onBranchChanged,
    required this.products,
    required this.selectedProducts,
    required this.loading,
    required this.error,
    required this.totalElements,
    required this.page,
    required this.totalPages,
    required this.onRetry,
    required this.onAdd,
    required this.onRemove,
    required this.onPrevious,
    required this.onNext,
  });

  final AppPalette palette;
  final _MovementTypeOption type;
  final BranchScopeState branches;
  final int? activeBranchId;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onBranchChanged;
  final List<ProductosResponseModel> products;
  final Map<int, _SelectedMovementProduct> selectedProducts;
  final bool loading;
  final String? error;
  final int totalElements;
  final int page;
  final int totalPages;
  final VoidCallback onRetry;
  final ValueChanged<ProductosResponseModel> onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(palette, tint: palette.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Productos disponibles',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$totalElements resultados',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 660;
                    final search = TextField(
                      maxLength: 120,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto o código',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                        filled: true,
                        fillColor: palette.background.withOpacity(0.42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(palette.radius(16)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(palette.radius(16)),
                          borderSide: BorderSide.none,
                        ),
                      ).compactFilter(),
                    );

                    if (branches.branches.length <= 1) return search;

                    final branch = DropdownButtonFormField<int>(
                      value: activeBranchId,
                      dropdownColor: palette.surface,
                      decoration: InputDecoration(
                        labelText: 'Sucursal',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                        filled: true,
                        fillColor: palette.background.withOpacity(0.42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(palette.radius(16)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(palette.radius(16)),
                          borderSide: BorderSide.none,
                        ),
                      ).compactFilter(),
                      items: branches.branches
                          .where((item) => item.sucuId != null)
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.sucuId,
                              child: Text(item.sucuNombre ?? 'Sucursal ${item.sucuId}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: onBranchChanged,
                    );

                    if (compact) {
                      return Column(
                        children: [
                          search,
                          const SizedBox(height: 10),
                          branch,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 10),
                        SizedBox(width: 245, child: branch),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ErrorPanel(
                      message: error!,
                      palette: palette,
                      onRetry: onRetry,
                    ),
                  );
                }
                if (products.isEmpty) {
                  return _EmptyPanel(
                    palette: palette,
                    icon: Icons.inventory_2_outlined,
                    title: 'No se encontraron productos',
                    message: 'Prueba con otro texto de búsqueda.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final productId = product.prodId;
                    final selected = productId != null && selectedProducts.containsKey(productId);
                    return _CatalogProductRow(
                      palette: palette,
                      type: type,
                      product: product,
                      selected: selected,
                      onTap: productId == null
                          ? null
                          : () => selected ? onRemove(productId) : onAdd(product),
                    );
                  },
                );
              },
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Página anterior',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Página ${page + 1} de $totalPages',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Página siguiente',
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CatalogProductRow extends StatelessWidget {
  const _CatalogProductRow({
    required this.palette,
    required this.type,
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final _MovementTypeOption type;
  final ProductosResponseModel product;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stock = product.inventarioActual ?? 0.0;
    final disabled = type.isOutbound && stock <= 0;
    final visual = _movementVisual(type.normalizedName, palette);
    final purchaseByPackage = product.prodCompraPorCantidad == 1 &&
        (product.prodCantidadCompra ?? 0.0) > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(palette.radius(16)),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? visual.color.withOpacity(0.14)
                : palette.background.withOpacity(0.34),
            borderRadius: BorderRadius.circular(palette.radius(16)),
          ),
          child: Row(
            children: [
              _ProductThumb(
                value: product.prodFoto,
                palette: palette,
                size: 58,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.prodNombre ?? 'Producto ${product.prodId ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: disabled
                            ? palette.textSecondary.withOpacity(0.65)
                            : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _InlineInfo(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock ${_quantityText(stock)} unidades',
                          color: stock <= 0 ? palette.warning : palette.textSecondary,
                        ),
                        if (purchaseByPackage)
                          _InlineInfo(
                            icon: Icons.inventory_outlined,
                            label: _stockPackageEquivalence(product),
                            color: palette.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: disabled
                      ? palette.textSecondary.withOpacity(0.08)
                      : selected
                          ? visual.color
                          : visual.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  color: disabled
                      ? palette.textSecondary.withOpacity(0.45)
                      : selected
                          ? Colors.white
                          : visual.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementSummaryPanel extends StatelessWidget {
  const _MovementSummaryPanel({
    required this.palette,
    required this.scrollProducts,
    required this.type,
    required this.products,
    required this.referenceController,
    required this.reasonController,
    required this.saving,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEditQuantity,
    required this.onRemove,
    required this.onRegister,
  });

  final AppPalette palette;
  final bool scrollProducts;
  final _MovementTypeOption type;
  final List<_SelectedMovementProduct> products;
  final TextEditingController referenceController;
  final TextEditingController reasonController;
  final bool saving;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onEditQuantity;
  final ValueChanged<int> onRemove;
  final VoidCallback onRegister;

  Widget _buildProductSelectionList() {
    final content = products.isEmpty
        ? _EmptyPanel(
            palette: palette,
            icon: Icons.playlist_add_rounded,
            title: 'Aún no hay productos',
            message: 'Agrega los productos que hacen parte de esta operación.',
          )
        : ListView.separated(
            shrinkWrap: !scrollProducts,
            physics: scrollProducts
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = products[index];
              final productId = item.product.prodId!;
              return _SelectedProductRow(
                palette: palette,
                type: type,
                item: item,
                onDecrease: () => onDecrease(productId),
                onIncrease: () => onIncrease(productId),
                onEditQuantity: () => onEditQuantity(productId),
                onRemove: () => onRemove(productId),
              );
            },
          );

    return scrollProducts ? Expanded(child: content) : content;
  }

  @override
  Widget build(BuildContext context) {
    final visual = _movementVisual(type.normalizedName, palette);
    final totalUnits = products.fold<double>(
      0,
      (sum, item) => sum + item.effectiveQuantity,
    );

    return Container(
      decoration: _panelDecoration(palette, tint: visual.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen de la operación',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${products.length} productos · ${_quantityText(totalUnits)} unidades',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(visual.icon, color: visual.color),
                ),
              ],
            ),
          ),
          _buildProductSelectionList(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: referenceController,
                  maxLength: 300,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(300)],
                  style: TextStyle(color: palette.textPrimary),
                  decoration: _fieldDecoration(
                    palette,
                    label: _referenceLabel(type.normalizedName),
                    hint: _referenceHint(type.normalizedName),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLength: 100,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(100)],
                  style: TextStyle(color: palette.textPrimary),
                  maxLines: 2,
                  minLines: 1,
                  decoration: _fieldDecoration(
                    palette,
                    label: 'Motivo o nota',
                    hint: 'Descripción breve de la operación',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: visual.color,
                      foregroundColor: visual.color.computeLuminance() > 0.56
                          ? const Color(0xFF07151D)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(palette.radius(16)),
                      ),
                    ),
                    onPressed: saving || products.isEmpty ? null : onRegister,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      saving ? 'Registrando...' : 'Registrar operación',
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

class _SelectedProductRow extends StatelessWidget {
  const _SelectedProductRow({
    required this.palette,
    required this.type,
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEditQuantity,
    required this.onRemove,
  });

  final AppPalette palette;
  final _MovementTypeOption type;
  final _SelectedMovementProduct item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEditQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final visual = _movementVisual(type.normalizedName, palette);
    final purchaseByPackage = item.product.prodCompraPorCantidad == 1 &&
        (item.product.prodCantidadCompra ?? 0.0) > 1;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.34),
        borderRadius: BorderRadius.circular(palette.radius(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProductThumb(
                value: item.product.prodFoto,
                palette: palette,
                size: 46,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.prodNombre ?? 'Producto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stock ${_quantityText(item.product.inventarioActual ?? 0.0)} unidades',
                      style: TextStyle(color: palette.textSecondary, fontSize: 11),
                    ),
                    if (purchaseByPackage) ...[
                      const SizedBox(height: 2),
                      Text(
                        _stockPackageEquivalence(item.product),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove_rounded,
                color: visual.color,
                onPressed: onDecrease,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onEditQuantity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          _quantityText(item.quantity),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.usesPurchasePresentation
                              ? (item.product.prodPresentacionCompra ?? 'paquetes')
                              : 'unidades',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add_rounded,
                color: visual.color,
                onPressed: onIncrease,
              ),
            ],
          ),
          if (item.usesPurchasePresentation) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: visual.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_quantityText(item.quantity)} '
                '${item.product.prodPresentacionCompra ?? 'paquete'} = '
                '${_quantityText(item.effectiveQuantity)} unidades de inventario',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.initialValue,
    required this.maxValue,
    required this.quantityLabel,
    required this.allowDecimals,
    required this.palette,
  });

  final double initialValue;
  final double? maxValue;
  final String quantityLabel;
  final bool allowDecimals;
  final AppPalette palette;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _quantityText(widget.initialValue));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Ingresa una cantidad mayor que cero.');
      return;
    }
    if (!widget.allowDecimals && value != value.truncateToDouble()) {
      setState(() => _error = 'La cantidad de paquetes debe ser un número entero.');
      return;
    }
    if (widget.maxValue != null && value > widget.maxValue!) {
      setState(() => _error = 'La cantidad supera el stock disponible.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AlertDialog(
        scrollable: true,
      backgroundColor: palette.surface,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.radius(24)),
        side: BorderSide.none,
      ),
      title: Text('Cantidad', style: TextStyle(color: palette.textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.allowDecimals,
        ),
        inputFormatters: InputConstraints.decimalFormatters(
          integerDigits: 13,
          fractionDigits: widget.allowDecimals ? 2 : 0,
        ),
        onSubmitted: (_) => _save(),
        style: TextStyle(color: palette.textPrimary),
        decoration: InputDecoration(
          labelText: widget.quantityLabel,
          errorText: _error,
          filled: true,
          fillColor: palette.background.withOpacity(0.42),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(palette.radius(16)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(palette.radius(16)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: palette.actionColor,
            foregroundColor: palette.onAction,
          ),
          onPressed: _save,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({
    required this.value,
    required this.palette,
    required this.size,
  });

  final String? value;
  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = (value ?? '').trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.local_bar_rounded, color: palette.secondary, size: size * 0.42),
    );

    if (raw.isEmpty) return placeholder;

    Widget image;
    if (raw.startsWith('data:image')) {
      final separator = raw.indexOf(',');
      if (separator < 0) return placeholder;
      try {
        image = Image.memory(
          base64Decode(raw.substring(separator + 1)),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(
        raw,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: image,
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.palette,
    required this.onRetry,
  });

  final String message;
  final AppPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(palette, tint: palette.warning),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: palette.warning, size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.palette,
    required this.icon,
    required this.title,
    required this.message,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: palette.secondary, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementDirectionDialog extends StatelessWidget {
  const _MovementDirectionDialog({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        scrollable: true,
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.radius(22)),
      ),
      title: Text(
        '¿Qué hará este ajuste?',
        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
      ),
      content: Text(
        'Selecciona el sentido real que se aplicará al inventario.',
        style: TextStyle(color: palette.textSecondary),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop('SALIDA'),
          icon: const Icon(Icons.remove_circle_outline_rounded),
          label: const Text('Disminuir stock'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop('ENTRADA'),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Aumentar stock'),
        ),
      ],
    );
  }
}

class _MovementTypeOption {
  const _MovementTypeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.operation,
    required this.allowPurchasePresentation,
    this.resolvedOperation,
  });

  final int? id;
  final String name;
  final String description;
  final String operation;
  final bool allowPurchasePresentation;
  final String? resolvedOperation;

  String get normalizedName => _normalizeMovementName(name);
  String get effectiveOperation => resolvedOperation ?? operation;
  bool get isOutbound => effectiveOperation == 'SALIDA';
  bool get isAdjustment => operation == 'AJUSTE';
  bool get isPurchaseEntry =>
      operation == 'ENTRADA' && allowPurchasePresentation;

  String get directionLabel => switch (operation) {
        'ENTRADA' => 'ENTRADA',
        'SALIDA' => 'SALIDA',
        'AJUSTE' => 'AJUSTE',
        _ => 'MOVIMIENTO',
      };

  _MovementTypeOption withResolvedOperation(String value) {
    return _MovementTypeOption(
      id: id,
      name: name,
      description: description,
      operation: operation,
      allowPurchasePresentation: allowPurchasePresentation,
      resolvedOperation: value,
    );
  }

  String get effectiveDescription {
    if (description.trim().isNotEmpty) return description.trim();
    return _defaultMovementDescription(normalizedName);
  }

  factory _MovementTypeOption.fromJson(Map<String, dynamic> json) {
    final id = json['timoId'];
    final name = json['timoNombre']?.toString().trim() ?? '';
    final configuredOperation = json['timoOperacion']?.toString().trim().toUpperCase();
    final rawPurchasePresentation =
        json['timoPermitePresentacionCompra'];
    final allowPurchasePresentation = rawPurchasePresentation == true ||
        rawPurchasePresentation == 1 ||
        rawPurchasePresentation?.toString().toLowerCase() == 'true' ||
        rawPurchasePresentation?.toString() == '1';
    return _MovementTypeOption(
      id: id is num ? id.toInt() : int.tryParse('$id'),
      name: name,
      description: json['timoDescripcion']?.toString().trim() ?? '',
      operation: _resolveLegacyOperation(configuredOperation, name),
      allowPurchasePresentation: allowPurchasePresentation,
    );
  }
}

class _SelectedMovementProduct {
  const _SelectedMovementProduct({
    required this.product,
    required this.quantity,
    required this.quantityUnit,
  });

  final ProductosResponseModel product;

  /// Cantidad capturada: paquetes cuando quantityUnit es
  /// PRESENTACION_COMPRA; unidades en los demás casos.
  final double quantity;
  final String quantityUnit;

  bool get usesPurchasePresentation =>
      quantityUnit == _purchasePresentationUnit;

  double get conversionFactor => usesPurchasePresentation
      ? (product.prodCantidadCompra ?? 1.0)
      : 1.0;

  /// Cantidad real que aumentará o disminuirá el inventario.
  double get effectiveQuantity => quantity * conversionFactor;

  _SelectedMovementProduct copyWith({
    double? quantity,
    String? quantityUnit,
  }) {
    return _SelectedMovementProduct(
      product: product,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
    );
  }
}

class _MovementVisual {
  const _MovementVisual({
    required this.icon,
    required this.color,
    required this.directionLabel,
  });

  final IconData icon;
  final Color color;
  final String directionLabel;
}

_MovementVisual _movementVisual(String name, AppPalette palette) {
  return switch (name) {
    'ENTRADA INICIAL' => _MovementVisual(
        icon: Icons.inventory_2_rounded,
        color: palette.success,
        directionLabel: 'ENTRADA',
      ),
    'COMPRA' => _MovementVisual(
        icon: Icons.shopping_cart_checkout_rounded,
        color: palette.success,
        directionLabel: 'ENTRADA',
      ),
    'VENTA' => _MovementVisual(
        icon: Icons.point_of_sale_rounded,
        color: palette.warning,
        directionLabel: 'SALIDA',
      ),
    'AJUSTE POSITIVO' => _MovementVisual(
        icon: Icons.add_chart_rounded,
        color: palette.secondary,
        directionLabel: 'AUMENTA',
      ),
    'AJUSTE NEGATIVO' => _MovementVisual(
        icon: Icons.remove_circle_outline_rounded,
        color: palette.warning,
        directionLabel: 'DISMINUYE',
      ),
    'PRESTAMO' => _MovementVisual(
        icon: Icons.call_made_rounded,
        color: palette.warning,
        directionLabel: 'SALIDA',
      ),
    'PRESTAMO ENTRANTE' => _MovementVisual(
        icon: Icons.call_received_rounded,
        color: palette.success,
        directionLabel: 'ENTRADA',
      ),
    'PRESTAMO SALIENTE' => _MovementVisual(
        icon: Icons.call_made_rounded,
        color: palette.warning,
        directionLabel: 'SALIDA',
      ),
    'DEVOLUCION' => _MovementVisual(
        icon: Icons.keyboard_return_rounded,
        color: palette.secondary,
        directionLabel: 'ENTRADA',
      ),
    _ => _MovementVisual(
        icon: Icons.sync_alt_rounded,
        color: palette.secondary,
        directionLabel: 'MOVIMIENTO',
      ),
  };
}

BoxDecoration _panelDecoration(AppPalette palette, {required Color tint}) {
  return BoxDecoration(
    gradient: palette.panelGradient(tint: tint),
    borderRadius: BorderRadius.circular(palette.radius(22)),
    boxShadow: palette.surfaceStyle == AppSurfacePreset.flat
        ? const []
        : [
            BoxShadow(
              color: palette.cardShadow.withOpacity(0.20),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
  );
}

InputDecoration _fieldDecoration(
  AppPalette palette, {
  required String label,
  required String hint,
  required IconData icon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(palette.radius(16)),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: palette.background.withOpacity(0.42),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

int _movementOrder(String name) {
  const values = <String>[
    'ENTRADA INICIAL',
    'COMPRA',
    'VENTA',
    'AJUSTE POSITIVO',
    'AJUSTE NEGATIVO',
    'PRESTAMO',
    'PRESTAMO ENTRANTE',
    'PRESTAMO SALIENTE',
    'DEVOLUCION',
  ];
  final index = values.indexOf(name);
  return index < 0 ? values.length : index;
}

String _resolveLegacyOperation(String? configured, String name) {
  if (configured == 'ENTRADA' || configured == 'SALIDA' || configured == 'AJUSTE') {
    return configured!;
  }
  final normalized = _normalizeMovementName(name);
  if (normalized.contains('COMPRA') ||
      normalized.contains('ENTRADA') ||
      normalized.contains('ENTRANTE') ||
      normalized.contains('DEVOLUCION') ||
      normalized.contains('POSITIVO')) {
    return 'ENTRADA';
  }
  if (normalized.contains('VENTA') ||
      normalized.contains('SALIDA') ||
      normalized.contains('SALIENTE') ||
      normalized.contains('PRESTAMO') ||
      normalized.contains('NEGATIVO') ||
      normalized.contains('PERDIDA') ||
      normalized.contains('MERMA') ||
      normalized.contains('CONSUMO')) {
    return 'SALIDA';
  }
  return 'AJUSTE';
}

String _normalizeMovementName(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _defaultMovementDescription(String name) {
  return switch (name) {
    'ENTRADA INICIAL' => 'Carga el inventario con el que inicia el producto.',
    'COMPRA' => 'Registra los productos recibidos de un proveedor.',
    'VENTA' => 'Registra una salida manual de productos por venta.',
    'AJUSTE POSITIVO' => 'Aumenta existencias por corrección de inventario.',
    'AJUSTE NEGATIVO' => 'Disminuye existencias por pérdida o corrección.',
    'PRESTAMO' => 'Registra los productos entregados temporalmente.',
    'PRESTAMO ENTRANTE' => 'Registra productos recibidos temporalmente.',
    'PRESTAMO SALIENTE' => 'Registra productos entregados temporalmente.',
    'DEVOLUCION' => 'Reintegra productos devueltos al inventario.',
    _ => 'Registra productos para este tipo de movimiento.',
  };
}

String _referenceLabel(String name) {
  return switch (name) {
    'COMPRA' => 'Factura o remisión',
    'VENTA' => 'Venta o comprobante',
    'PRESTAMO' || 'PRESTAMO ENTRANTE' || 'PRESTAMO SALIENTE' => 'Persona o documento',
    'DEVOLUCION' => 'Venta o devolución',
    _ => 'Referencia',
  };
}

String _referenceHint(String name) {
  return switch (name) {
    'COMPRA' => 'Ej. Factura FC-1024',
    'VENTA' => 'Ej. Venta manual 508',
    'PRESTAMO' || 'PRESTAMO ENTRANTE' || 'PRESTAMO SALIENTE' => 'Ej. Juan / Préstamo 15',
    'DEVOLUCION' => 'Ej. Devolución venta 508',
    _ => 'Documento o referencia de control',
  };
}

String _quantityText(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Presenta la equivalencia del stock sin cambiar su unidad base.
///
/// El inventario siempre está expresado en unidades. La presentación de compra
/// solo se muestra como referencia secundaria para evitar interpretar el valor
/// del stock como número de paquetes.
String _stockPackageEquivalence(ProductosResponseModel product) {
  final stockUnits = product.inventarioActual ?? 0.0;
  final unitsPerPackage = product.prodCantidadCompra ?? 0.0;
  final presentation = (product.prodPresentacionCompra ?? 'Paquete').trim();

  if (unitsPerPackage <= 1) return '${_quantityText(stockUnits)} unidades';

  final completePackages = (stockUnits / unitsPerPackage).floor();
  final looseUnits = stockUnits - (completePackages * unitsPerPackage);
  final packageLabel = completePackages == 1
      ? presentation
      : _pluralizePurchasePresentation(presentation);

  if (looseUnits.abs() < 0.000001) {
    return '$completePackages $packageLabel completos · '
        '${_quantityText(unitsPerPackage)} unidades c/u';
  }

  return '$completePackages $packageLabel completos + '
      '${_quantityText(looseUnits)} unidades sueltas · '
      '${_quantityText(unitsPerPackage)} unidades c/u';
}

String _pluralizePurchasePresentation(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'paquetes';
  final lower = normalized.toLowerCase();
  if (lower.endsWith('s')) return normalized;
  if (lower.endsWith('z')) {
    return '${normalized.substring(0, normalized.length - 1)}ces';
  }
  return '${normalized}s';
}

String _readableError(Object error) {
  final value = error.toString().trim();
  if (value.startsWith('ApiException: ')) return value.substring('ApiException: '.length);
  if (value.startsWith('NetworkException: ')) {
    return value.substring('NetworkException: '.length);
  }
  return value.replaceFirst(RegExp(r'^Exception:\s*'), '');
}
