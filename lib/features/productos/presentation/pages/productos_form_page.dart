import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../business_setup/presentation/providers/business_setup_provider.dart';
import '../../../inventario/data/models/inventario_response_model.dart';
import '../../../inventario/presentation/providers/inventario_provider.dart';
import '../../../marcas/data/models/marcas_response_model.dart';
import '../../../marcas/presentation/providers/marcas_provider.dart';
import '../../../precios/data/models/precios_response_model.dart';
import '../../../precios/presentation/providers/precios_provider.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../../sucursales/presentation/providers/sucursales_provider.dart';
import '../../../tipos_producto/data/models/tipos_producto_response_model.dart';
import '../../../tipos_producto/presentation/providers/tipos_producto_provider.dart';
import '../../data/models/productos_response_model.dart';
import '../providers/productos_provider.dart';

class ProductosFormPage extends ConsumerStatefulWidget {
  const ProductosFormPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<ProductosFormPage> createState() => _ProductosFormPageState();
}

class _ProductosFormPageState extends ConsumerState<ProductosFormPage> {
  final _generalFormKey = GlobalKey<FormState>();
  final _priceFormKey = GlobalKey<FormState>();
  final _inventoryFormKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fotoController = TextEditingController();
  final _fechaVencimientoController = TextEditingController();
  final _valorCompraController = TextEditingController();
  final _valorVentaController = TextEditingController();
  final _presentacionCompraController = TextEditingController(text: 'Canasta');
  final _cantidadCompraController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(text: '19');
  final _inventarioCantidadController = TextEditingController();
  final _stockMinimoController = TextEditingController(text: '0');
  final _stockMaximoController = TextEditingController();

  int _currentStep = 0;
  int? _sucursalId;
  int? _tipoId;
  int? _marcaId;
  DateTime? _fechaVencimiento;
  bool _aplicaImpuesto = false;
  bool _compraPorCantidad = false;
  bool _registrarInventario = false;
  bool _stockMaximoSinLimite = true;
  bool _saving = false;
  bool _loadedStorage = false;
  bool _hydratedProduct = false;
  bool _hydratedPrice = false;
  bool _gastroLoaded = false;
  String _tipoControl = 'NORMAL';
  String _unidadBase = 'UND';
  String _estacionPreparacion = 'COCINA';
  final List<_GastroIngredientDraft> _gastroIngredientes = <_GastroIngredientDraft>[];
  final List<_GastroAdditionDraft> _gastroAdiciones = <_GastroAdditionDraft>[];
  double? _originalValorCompra;
  double? _originalValorVenta;
  double? _originalPorcentajeImpuesto;
  bool? _originalAplicaImpuesto;

  bool get _editing => widget.id != null && widget.id!.trim().isNotEmpty;
  int? get _editingId => int.tryParse(widget.id ?? '');

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAssignedSucursal);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _fotoController.dispose();
    _fechaVencimientoController.dispose();
    _valorCompraController.dispose();
    _valorVentaController.dispose();
    _presentacionCompraController.dispose();
    _cantidadCompraController.dispose();
    _porcentajeImpuestoController.dispose();
    _inventarioCantidadController.dispose();
    _stockMinimoController.dispose();
    _stockMaximoController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedSucursal() async {
    final raw = await ref.read(secureStorageProvider).read(StorageKeys.sucursalId);
    if (!mounted) return;
    setState(() {
      _sucursalId = int.tryParse(raw ?? '');
      _loadedStorage = true;
    });
    if (_editing) {
      await _loadGastroConfig();
    }
  }

  Future<void> _loadGastroConfig() async {
    if (_gastroLoaded) return;
    final productId = _editingId;
    final branchId = _sucursalId;
    if (productId == null || branchId == null) return;

    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '/api/v1/productos/$productId/gastro',
            (json) => Map<String, dynamic>.from(json as Map),
            queryParameters: <String, dynamic>{'sucursalId': branchId},
          );
      final data = response.data;
      if (!mounted || data == null) return;

      final ingredientes = (data['ingredientes'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => _GastroIngredientDraft.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final adiciones = (data['adiciones'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => _GastroAdditionDraft.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      setState(() {
        _tipoControl = (data['tipoControl']?.toString() ?? 'NORMAL').toUpperCase();
        _unidadBase = (data['unidadBase']?.toString() ?? 'UND').toUpperCase();
        _estacionPreparacion =
            (data['estacionPreparacion']?.toString() ?? 'COCINA').toUpperCase();
        _gastroIngredientes
          ..clear()
          ..addAll(ingredientes);
        _gastroAdiciones
          ..clear()
          ..addAll(adiciones);
        _gastroLoaded = true;
      });
    } catch (_) {
      // Los productos existentes siguen siendo compatibles como NORMAL aunque
      // la configuración gastrobar todavía no haya sido creada.
      if (mounted) setState(() => _gastroLoaded = true);
    }
  }

  void _hydrateProduct(ProductosResponseModel producto) {
    if (_hydratedProduct) return;
    _hydratedProduct = true;
    _sucursalId = producto.sucuId ?? _sucursalId;
    _tipoId = producto.tpprId;
    _marcaId = producto.mrcaId;
    _nombreController.text = producto.prodNombre ?? '';
    _descripcionController.text = producto.prodDescripcion ?? '';
    _fotoController.text = producto.prodFoto ?? '';
    _fechaVencimiento = _tryParseDate(producto.prodFechaVencimiento);
    _fechaVencimientoController.text = _formatDate(_fechaVencimiento);
    _compraPorCantidad = (producto.prodCompraPorCantidad ?? 0) == 1;
    _cantidadCompraController.text = _toFieldNumber(producto.prodCantidadCompra);
    _presentacionCompraController.text = (producto.prodPresentacionCompra ?? '').trim().isEmpty
        ? 'Canasta'
        : producto.prodPresentacionCompra!.trim();
    _stockMinimoController.text = _toFieldNumber(producto.prodStockMinimo ?? 0);
    _stockMaximoSinLimite = producto.prodStockMaximo == null;
    _stockMaximoController.text = _stockMaximoSinLimite
        ? ''
        : _toFieldNumber(producto.prodStockMaximo);
    if (!_gastroLoaded) {
      _tipoControl = (producto.prodTipoControl ?? 'NORMAL').toUpperCase();
      _unidadBase = (producto.prodUnidadBase ?? 'UND').toUpperCase();
    }
  }

  void _hydratePrice(List<PreciosResponseModel> precios) {
    if (_hydratedPrice || !_editing) return;
    final productId = _editingId;
    if (productId == null || _sucursalId == null) return;
    final related = precios
        .where((item) => item.prodId == productId && item.sucuId == _sucursalId)
        .toList()
      ..sort((a, b) => (b.precFechaInicia ?? '').compareTo(a.precFechaInicia ?? ''));
    if (related.isEmpty) return;
    final active = related.firstWhere(
      (item) => item.precEstado == 1,
      orElse: () => related.first,
    );
    _hydratedPrice = true;
    _originalValorCompra = active.precValorCompra?.toDouble();
    _originalValorVenta = active.precValorVenta?.toDouble();
    _originalAplicaImpuesto = (active.precAplicaImpuesto ?? 0) == 1;
    _originalPorcentajeImpuesto = active.precPorcentajeImpuesto?.toDouble() ?? 0.0;
    _valorCompraController.text = _toFieldNumber(active.precValorCompra);
    _valorVentaController.text = _toFieldNumber(active.precValorVenta);
    _aplicaImpuesto = _originalAplicaImpuesto ?? false;
    if ((_originalPorcentajeImpuesto ?? 0.0) > 0) {
      _porcentajeImpuestoController.text = _toFieldNumber(_originalPorcentajeImpuesto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final productosState = ref.watch(productosProvider);
    final preciosState = ref.watch(preciosProvider);
    final inventarioState = ref.watch(inventarioProvider);
    final marcasState = ref.watch(marcasProvider);
    final tiposState = ref.watch(tiposproductoProvider);
    final sucursalesState = ref.watch(sucursalesProvider);

    final producto = _editingId == null
        ? null
        : _firstOrNull(productosState.items.where((item) => item.prodId == _editingId));

    if (_editing && producto != null) {
      _hydrateProduct(producto);
    }
    _hydratePrice(preciosState.items);

    if (!_loadedStorage || (_editing && productosState.loading && producto == null)) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [Positioned.fill(child: AppPageBackground()), AppLoader()]),
      );
    }

    final sucursal = _firstOrNull(
      sucursalesState.items.where((item) => item.sucuId == _sucursalId),
    );
    final sucursalNombre = sucursal?.sucuNombre ?? 'Sucursal asignada ${_sucursalId ?? '-'}';
    final tipoSeleccionado = _firstOrNull(tiposState.items.where((item) => item.tpprId == _tipoId));
    final marcaSeleccionada = _firstOrNull(marcasState.items.where((item) => item.mrcaId == _marcaId));
    final inventarioActual = _editingId == null
        ? 0.0
        : inventarioState.items
            .where((item) => item.prodId == _editingId && item.sucuId == _sucursalId)
            .fold<double>(0, (total, item) => total + (item.invtCantidad ?? 0));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _WizardHeader(
                    palette: palette,
                    editing: _editing,
                    currentStep: _currentStep,
                    onBack: () => context.go('/productos'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                            final form = _StepShell(
                              palette: palette,
                              title: _titleForStep(_currentStep),
                              subtitle: _subtitleForStep(_currentStep),
                              child: IndexedStack(
                                index: _currentStep,
                                children: [
                                  _buildGeneralStep(
                                    palette,
                                    tiposState.items,
                                    marcasState.items,
                                    productosState.items,
                                    sucursalNombre,
                                  ),
                                  _buildPriceStep(palette),
                                  _buildInventoryStep(
                                    palette,
                                    sucursalNombre,
                                    inventarioState.items,
                                  ),
                                  _buildConfirmationStep(
                                    palette,
                                    tiposState.items,
                                    marcasState.items,
                                    sucursalNombre,
                                    inventarioState.items,
                                  ),
                                ],
                              ),
                            );
                            final overview = _ProductDraftOverview(
                              palette: palette,
                              image: _fotoController.text,
                              name: _nombreController.text,
                              description: _descripcionController.text,
                              typeName: tipoSeleccionado?.tpprNombre ?? 'Tipo pendiente',
                              brandName: marcaSeleccionada?.mrcaNombre ?? 'Marca pendiente',
                              branchName: sucursalNombre,
                              purchasePrice: _parseDouble(_valorCompraController.text),
                              salePrice: _parseDouble(_valorVentaController.text),
                              purchaseByQuantity: _compraPorCantidad,
                              purchaseQuantity: _parseDouble(_cantidadCompraController.text),
                              currentInventory: inventarioActual,
                              inventoryToAdd: _registrarInventario ? _parseDouble(_inventarioCantidadController.text) : null,
                              expirationDate: _fechaVencimiento,
                              currentStep: _currentStep,
                            );

                                if (constraints.maxWidth >= 980) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: form),
                                      const SizedBox(width: 9),
                                      SizedBox(width: 270, child: overview),
                                    ],
                                  );
                                }
                                // En tablet/móvil la vista previa completa ocupaba demasiado
                                // espacio antes de llegar a los campos. El formulario queda
                                // como protagonista y la confirmación mantiene el resumen.
                                return form;
                              },
                            ),
                            const SizedBox(height: 10),
                            _NavigationButtons(
                              palette: palette,
                              saving: _saving,
                              currentStep: _currentStep,
                              onPrevious: _currentStep == 0 ? null : () => setState(() => _currentStep--),
                              onNext: _goNext,
                              onSave: () => _confirmAndSave(context, palette),
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

  Widget _buildGeneralStep(
    AppPalette palette,
    List<TiposProductoResponseModel> tipos,
    List<MarcasResponseModel> marcas,
    List<ProductosResponseModel> productos,
    String sucursalNombre,
  ) {
    return Form(
      key: _generalFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final imagePanel = SizedBox(
            width: wide ? 210 : double.infinity,
            child: _ProductImagePicker(
              palette: palette,
              controller: _fotoController,
              onChanged: () => setState(() {}),
            ),
          );
          final fields = Column(
            children: [
              _FormTextField(
                palette: palette,
                controller: _nombreController,
                label: 'Nombre del producto',
                maxLength: 120,
                icon: Icons.local_bar_rounded,
                validator: _required,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _FormTextField(
                palette: palette,
                controller: _descripcionController,
                label: 'Descripción',
                maxLength: 400,
                icon: Icons.description_rounded,
                validator: _required,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _DateField(
                palette: palette,
                controller: _fechaVencimientoController,
                label: 'Fecha de vencimiento opcional',
                onPick: _pickExpirationDate,
                onClear: () => setState(() {
                  _fechaVencimiento = null;
                  _fechaVencimientoController.clear();
                }),
              ),
              const SizedBox(height: 12),
              _ReadOnlyInfoField(
                palette: palette,
                label: 'Sucursal asignada',
                value: sucursalNombre,
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 12),
              _LookupRow<TiposProductoResponseModel>(
                palette: palette,
                value: _tipoId,
                label: 'Tipo de producto',
                items: tipos,
                itemId: (item) => item.tpprId,
                itemLabel: (item) => item.tpprNombre ?? 'Tipo ${item.tpprId ?? '-'}',
                onChanged: (value) => setState(() => _tipoId = value),
                onCreate: () => _createTipoProducto(palette),
              ),
              const SizedBox(height: 12),
              _LookupRow<MarcasResponseModel>(
                palette: palette,
                value: _marcaId,
                label: 'Marca',
                items: marcas,
                itemId: (item) => item.mrcaId,
                itemLabel: (item) => item.mrcaNombre ?? 'Marca ${item.mrcaId ?? '-'}',
                onChanged: (value) => setState(() => _marcaId = value),
                onCreate: () => _createMarca(palette),
                allowNone: true,
              ),
              const SizedBox(height: 18),
              _GastroControlSection(
                palette: palette,
                tipoControl: _tipoControl,
                unidadBase: _unidadBase,
                estacionPreparacion: _estacionPreparacion,
                ingredientes: _gastroIngredientes,
                adiciones: _gastroAdiciones,
                onTipoChanged: (value) => setState(() {
                  _tipoControl = value;
                  if (value != 'PREPARADO') {
                    _gastroIngredientes.clear();
                    _gastroAdiciones.clear();
                  }
                }),
                onUnidadChanged: (value) => setState(() => _unidadBase = value),
                onEstacionChanged: (value) =>
                    setState(() => _estacionPreparacion = value),
                onAddIngredient: _tipoControl == 'PREPARADO'
                    ? () => _addGastroIngredient(productos)
                    : null,
                onAddAddition: _tipoControl == 'PREPARADO'
                    ? () => _addGastroAddition(productos)
                    : null,
                onRemoveIngredient: (index) => setState(() => _gastroIngredientes.removeAt(index)),
                onRemoveAddition: (index) => setState(() => _gastroAdiciones.removeAt(index)),
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [imagePanel, const SizedBox(height: 12), fields],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [imagePanel, const SizedBox(width: 14), Expanded(child: fields)],
          );
        },
      ),
    );
  }

  Widget _buildPriceStep(AppPalette palette) {
    final compra = _parseDouble(_valorCompraController.text) ?? 0.0;
    final venta = _parseDouble(_valorVentaController.text) ?? 0.0;
    final porcentaje = _aplicaImpuesto ? (_parseDouble(_porcentajeImpuestoController.text) ?? 0.0) : 0.0;
    final cantidadCompra = _compraPorCantidad ? (_parseDouble(_cantidadCompraController.text) ?? 0.0) : 0.0;
    final costoUnitarioCompra = _compraPorCantidad && cantidadCompra > 0 ? compra / cantidadCompra : compra;
    final impuesto = venta * porcentaje / 100;
    final totalConImpuesto = venta + impuesto;

    return Form(
      key: _priceFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              const spacing = 12.0;
              final width = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _FormTextField(
                      palette: palette,
                      controller: _valorCompraController,
                      label: 'Valor compra',
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 0),
                      icon: Icons.shopping_cart_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _requiredPositive,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _FormTextField(
                      palette: palette,
                      controller: _valorVentaController,
                      label: _tipoControl == 'INSUMO'
                          ? 'Valor venta (puede ser 0)'
                          : 'Valor venta',
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 0),
                      icon: Icons.payments_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _tipoControl == 'INSUMO'
                          ? _requiredPositiveOrZero
                          : _requiredPositive,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _SwitchTile(
            palette: palette,
            value: _compraPorCantidad,
            title: 'La compra viene por presentación o cantidad',
            subtitle: 'Ejemplo: canasta de cerveza de 30 unidades comprada por \$67.000.',
            icon: Icons.inventory_2_rounded,
            onChanged: (value) => setState(() => _compraPorCantidad = value),
          ),
          if (_compraPorCantidad) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                const spacing = 12.0;
                final width = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: _FormTextField(
                        palette: palette,
                        controller: _presentacionCompraController,
                        label: 'Presentación de compra',
                        maxLength: 60,
                        icon: Icons.shopping_bag_rounded,
                        validator: _required,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _FormTextField(
                        palette: palette,
                        controller: _cantidadCompraController,
                        label: 'Unidades incluidas',
                        inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 2),
                        icon: Icons.numbers_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _requiredPositive,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          _SwitchTile(
            palette: palette,
            value: _aplicaImpuesto,
            title: 'Este precio aplica impuesto',
            subtitle: 'El impuesto queda guardado en el registro de precio, no en el producto.',
            icon: Icons.receipt_long_rounded,
            onChanged: (value) => setState(() => _aplicaImpuesto = value),
          ),
          if (_aplicaImpuesto) ...[
            const SizedBox(height: 12),
            _FormTextField(
              palette: palette,
              controller: _porcentajeImpuestoController,
              label: 'Porcentaje de impuesto',
              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 3, fractionDigits: 2),
              icon: Icons.percent_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _requiredPositiveOrZero,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          _PricePreview(
            palette: palette,
            compra: compra,
            venta: venta,
            compraPorCantidad: _compraPorCantidad,
            presentacionCompra: _presentacionCompraController.text,
            cantidadCompra: cantidadCompra,
            costoUnitarioCompra: costoUnitarioCompra,
            aplicaImpuesto: _aplicaImpuesto,
            porcentaje: porcentaje,
            impuesto: impuesto,
            totalConImpuesto: totalConImpuesto,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStep(
    AppPalette palette,
    String sucursalNombre,
    List<InventarioResponseModel> inventarios,
  ) {
    final productId = _editingId;
    final inventarioHistorial = productId == null
        ? <InventarioResponseModel>[]
        : inventarios.where((item) => item.prodId == productId && item.sucuId == _sucursalId).toList()
      ..sort((a, b) => (b.invtFecha ?? '').compareTo(a.invtFecha ?? ''));
    final inventarioActual = inventarioHistorial.fold<double>(
      0,
      (total, item) => total + (item.invtCantidad ?? 0),
    );

    return Form(
      key: _inventoryFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryPanel(
            palette: palette,
            rows: [
              _SummaryRow('Sucursal', sucursalNombre),
              _SummaryRow('Inventario actual', '${_formatNumber(inventarioActual)} unidades'),
      _SummaryRow(
        'Stock mínimo',
        '${_formatNumber(_parseDouble(_stockMinimoController.text) ?? 0)} unidades',
      ),
      _SummaryRow(
        'Stock máximo',
        _stockMaximoSinLimite
            ? 'Sin límite'
            : '${_formatNumber(_parseDouble(_stockMaximoController.text) ?? 0)} unidades',
      ),
              _SummaryRow('Registros históricos', '${inventarioHistorial.length} registros'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Control de reposición',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando el inventario llegue al mínimo, el reporte sugerirá la reposición. El máximo es opcional; vacío significa sin límite superior.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680 ? 2 : 1;
              const spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _FormTextField(
                      palette: palette,
                      controller: _stockMinimoController,
                      label: 'Stock mínimo',
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 28, fractionDigits: 2),
                      icon: Icons.notification_important_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _requiredPositiveOrZero,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _FormTextField(
                      palette: palette,
                      controller: _stockMaximoController,
                      label: 'Stock máximo (opcional)',
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 28, fractionDigits: 2),
                      icon: Icons.inventory_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _validateStockMaximo,
                      enabled: !_stockMaximoSinLimite,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: palette.background.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: SwitchListTile.adaptive(
              value: _stockMaximoSinLimite,
              onChanged: (value) {
                setState(() {
                  _stockMaximoSinLimite = value;
                  if (value) {
                    _stockMaximoController.clear();
                  } else if (_stockMaximoController.text.trim().isEmpty) {
                    final minimo = _parseDouble(_stockMinimoController.text) ?? 0;
                    _stockMaximoController.text = _toFieldNumber(minimo);
                  }
                });
              },
              title: Text(
                'Sin límite máximo',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                'El producto seguirá generando alerta por stock mínimo, pero no será marcado como sobrestock.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              secondary: Icon(Icons.all_inclusive, color: palette.secondary),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.secondary.withOpacity(0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_graph_rounded, color: palette.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    !_stockMaximoSinLimite
                        ? 'Reposición con objetivo: al llegar al mínimo se sugerirá comprar hasta alcanzar el máximo.'
                        : 'Sin límite máximo: al llegar al mínimo se sugerirá al menos una presentación de compra y el usuario podrá ajustar libremente la cantidad.',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Historial de inventario',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          _InventoryHistoryPanel(
            palette: palette,
            items: inventarioHistorial,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => setState(() => _registrarInventario = !_registrarInventario),
              icon: Icon(_registrarInventario ? Icons.close_rounded : Icons.add_rounded),
              label: Text(_registrarInventario ? 'No agregar inventario ahora' : 'Agregar inventario'),
            ),
          ),
          if (_registrarInventario) ...[
            const SizedBox(height: 12),
            _FormTextField(
              palette: palette,
              controller: _inventarioCantidadController,
              label: 'Cantidad a agregar',
              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 30, fractionDigits: 0),
              icon: Icons.add_box_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _requiredPositive,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.darkBackground
                    ? Colors.white.withOpacity(0.04)
                    : palette.background.withOpacity(0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: palette.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El inventario es opcional. Puedes continuar a la confirmación sin registrar cantidad.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationStep(
    AppPalette palette,
    List<TiposProductoResponseModel> tipos,
    List<MarcasResponseModel> marcas,
    String sucursalNombre,
    List<InventarioResponseModel> inventarios,
  ) {
    final rows = _buildConfirmationRows(
      tipos: tipos,
      marcas: marcas,
      sucursalNombre: sucursalNombre,
      inventarios: inventarios,
    );
    final compra = _parseDouble(_valorCompraController.text) ?? 0.0;
    final venta = _parseDouble(_valorVentaController.text) ?? 0.0;
    final porcentaje = _aplicaImpuesto ? (_parseDouble(_porcentajeImpuestoController.text) ?? 0.0) : 0.0;
    final shouldCreatePrice = _shouldCreatePrice(
      compra: compra,
      venta: venta,
      aplicaImpuesto: _aplicaImpuesto,
      porcentaje: porcentaje,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.darkBackground
                ? Colors.white.withOpacity(0.04)
                : palette.background.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.fact_check_rounded, color: palette.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Revisa la información antes de guardar. Solo al presionar Confirmar y guardar se enviará la información a la base de datos.',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SummaryPanel(palette: palette, rows: rows),
        const SizedBox(height: 14),
        _SummaryPanel(
          palette: palette,
          rows: [
            _SummaryRow(
              'Precio',
              shouldCreatePrice
                  ? (_editing ? 'Se creará un nuevo precio activo porque cambió la información de precio.' : 'Se registrará el precio inicial activo.')
                  : 'No se creará precio nuevo porque no cambió compra, venta ni impuesto.',
            ),
            _SummaryRow(
              'Inventario',
              _registrarInventario ? 'Se registrará la cantidad indicada.' : 'No se registrará inventario en este momento.',
            ),
          ],
        ),
      ],
    );
  }

  List<_SummaryRow> _buildConfirmationRows({
    required List<TiposProductoResponseModel> tipos,
    required List<MarcasResponseModel> marcas,
    required String sucursalNombre,
    required List<InventarioResponseModel> inventarios,
  }) {
    final tipoNombre = _firstOrNull(tipos.where((item) => item.tpprId == _tipoId))?.tpprNombre ?? 'No seleccionado';
    final marcaNombre = _firstOrNull(marcas.where((item) => item.mrcaId == _marcaId))?.mrcaNombre ?? 'No seleccionada';
    final productId = _editingId;
    final inventarioHistorial = productId == null
        ? <InventarioResponseModel>[]
        : inventarios.where((item) => item.prodId == productId && item.sucuId == _sucursalId).toList();
    final inventarioActual = inventarioHistorial.fold<double>(
      0,
      (total, item) => total + (item.invtCantidad ?? 0),
    );

    return [
      _SummaryRow('Producto', _nombreController.text),
      _SummaryRow('Descripción', _descripcionController.text),
      _SummaryRow('Sucursal', sucursalNombre),
      _SummaryRow('Tipo de producto', tipoNombre),
      _SummaryRow('Marca', marcaNombre),
      _SummaryRow(
        'Preparación',
        _tipoControl == 'PREPARADO'
            ? 'Producto preparado · ${_estacionPreparacion == 'BARRA' ? 'Barra' : 'Cocina'}'
            : _tipoControl == 'INSUMO'
                ? 'Ingrediente / insumo'
                : 'Producto normal',
      ),
      _SummaryRow(
        'Fecha de vencimiento',
        _fechaVencimientoController.text.trim().isEmpty ? 'No registrada' : _fechaVencimientoController.text,
      ),
      _SummaryRow('Valor compra', _money(_parseDouble(_valorCompraController.text))),
      _SummaryRow(
        'Presentación compra',
        _compraPorCantidad
            ? '${_presentacionCompraController.text.trim()} · ${_cantidadCompraController.text.trim()} unidades'
            : 'Compra por unidad',
      ),
      _SummaryRow(
        'Costo unitario compra',
        _money(
          _compraPorCantidad && (_parseDouble(_cantidadCompraController.text) ?? 0) > 0
              ? ((_parseDouble(_valorCompraController.text) ?? 0) / (_parseDouble(_cantidadCompraController.text) ?? 1))
              : _parseDouble(_valorCompraController.text),
        ),
      ),
      _SummaryRow('Valor venta', _money(_parseDouble(_valorVentaController.text))),
      _SummaryRow('Impuesto', _aplicaImpuesto ? '${_porcentajeImpuestoController.text}% aplica' : 'No aplica'),
      _SummaryRow('Inventario actual', '${_formatNumber(inventarioActual)} unidades'),
      _SummaryRow(
        'Stock mínimo',
        '${_formatNumber(_parseDouble(_stockMinimoController.text) ?? 0)} unidades',
      ),
      _SummaryRow(
        'Stock máximo',
        _stockMaximoSinLimite
            ? 'Sin límite'
            : '${_formatNumber(_parseDouble(_stockMaximoController.text) ?? 0)} unidades',
      ),
      _SummaryRow(
        'Inventario a registrar',
        _registrarInventario ? '${_inventarioCantidadController.text} unidades' : 'No se registrará ahora',
      ),
    ];
  }

  Future<void> _addGastroIngredient(List<ProductosResponseModel> productos) async {
    final candidates = productos
        .where((item) =>
            item.prodId != null &&
            item.prodId != _editingId &&
            item.sucuId == _sucursalId &&
            (item.prodTipoControl ?? '').trim().toUpperCase() == 'INSUMO')
        .toList()
      ..sort((a, b) => (a.prodNombre ?? '').toLowerCase().compareTo((b.prodNombre ?? '').toLowerCase()));

    final formKey = GlobalKey<FormState>();
    int? selectedId;
    String unit = 'UND';
    bool removable = true;
    String quantityValue = '1';
    final result = await showDialog<_GastroIngredientDraft>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text('Agregar ingrediente'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _createGastroIngredientInline();
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Crear ingrediente nuevo'),
                      ),
                    ),
                    if (candidates.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ingrediente / insumo',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded),
                      ),
                      items: candidates
                          .map((item) => DropdownMenuItem<int>(
                                value: item.prodId,
                                child: Text(
                                  '${item.prodNombre ?? 'Producto'} · costo ${_formatNumber(item.precioCompraVigente ?? 0)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedId = value),
                      validator: (value) => value == null ? 'Selecciona un ingrediente' : null,
                    ),
                    if (candidates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Todavía no hay ingredientes. Puedes crear uno aquí mismo.'),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '1',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 4),
                            decoration: const InputDecoration(
                              labelText: 'Cantidad por preparación',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: _requiredPositive,
                            onChanged: (value) => quantityValue = value,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<String>(
                            value: unit,
                            decoration: const InputDecoration(labelText: 'Unidad'),
                            items: const ['UND', 'G', 'KG', 'ML', 'L']
                                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setDialogState(() => unit = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: removable,
                      title: const Text('Se puede quitar del pedido'),
                      subtitle: const Text('Ejemplo: sin cebolla, sin tomate o sin salsa.'),
                      onChanged: (value) => setDialogState(() => removable = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: candidates.isEmpty ? null : () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final product = candidates.firstWhere((item) => item.prodId == selectedId);
                  Navigator.pop(
                    dialogContext,
                    _GastroIngredientDraft(
                      prodId: selectedId!,
                      nombre: product.prodNombre ?? 'Producto $selectedId',
                      cantidad: _parseDouble(quantityValue) ?? 1,
                      unidad: unit,
                      removible: removable,
                      precioCompra: product.precioCompraVigente,
                    ),
                  );
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
        ),
      );

    if (result == null || !mounted) return;
    setState(() {
      _gastroIngredientes.removeWhere((item) => item.prodId == result.prodId);
      _gastroIngredientes.add(result);
    });
  }


  Future<void> _createGastroIngredientInline() async {
    if (_sucursalId == null || _tipoId == null) {
      _showError('Selecciona primero el tipo de producto y la marca del producto preparado.');
      return;
    }
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final purchaseController = TextEditingController(text: '0');
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    String unit = 'UND';
    bool removable = true;
    try {
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            scrollable: true,
            title: const Text('Crear ingrediente / insumo'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Nombre del ingrediente'),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      maxLength: 400,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      validator: _required,
                    ),
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'Unidad base'),
                      items: const ['UND', 'G', 'KG', 'ML', 'L']
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) update(() => unit = value);
                      },
                    ),
                    TextFormField(
                      controller: purchaseController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 2),
                      decoration: const InputDecoration(labelText: 'Costo de compra por unidad', helperText: 'Puedes actualizarlo después'),
                      validator: (value) {
                        final amount = _parseDouble(value ?? '');
                        return amount == null || amount < 0 ? 'Indica un costo válido' : null;
                      },
                    ),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 4),
                      decoration: const InputDecoration(labelText: 'Cantidad por preparación'),
                      validator: _requiredPositive,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Se puede quitar del pedido'),
                      value: removable,
                      onChanged: (value) => update(() => removable = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(ctx, <String, dynamic>{
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'unit': unit,
                    'cost': _parseDouble(purchaseController.text) ?? 0.0,
                    'quantity': _parseDouble(quantityController.text) ?? 1.0,
                    'removable': removable,
                  });
                },
                child: const Text('Crear y agregar'),
              ),
            ],
          ),
        ),
      );
      if (values == null || !mounted) return;
      final client = ref.read(apiClientProvider);
      final response = await client.post<ProductosResponseModel>(
        '/api/v1/productos',
        <String, dynamic>{
          'sucuId': _sucursalId,
          'tpprId': _tipoId,
          'mrcaId': await _resolveMarcaId(),
          'prodNombre': values['name'],
          'prodDescripcion': values['description'],
          'prodTipoControl': 'INSUMO',
          'prodUnidadBase': values['unit'],
          'prodStockMinimo': 0,
        },
        (json) => ProductosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      final product = response.data;
      final id = product?.prodId;
      if (id == null) throw StateError('No se obtuvo el identificador del ingrediente');
      final cost = values['cost'] as double;
      if (cost > 0) {
        await client.post<PreciosResponseModel>(
          '/api/v1/precios',
          <String, dynamic>{
            'prodId': id,
            'sucuId': _sucursalId,
            'precEstado': 1,
            'precValorCompra': cost,
            'precValorVenta': 0,
            'precFechaInicia': DateTime.now().toIso8601String(),
            'precAplicaImpuesto': 0,
            'precPorcentajeImpuesto': 0,
            'precValorImpuesto': 0,
          },
          (json) => PreciosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      }
      if (!mounted) return;
      setState(() {
        _gastroIngredientes.removeWhere((item) => item.prodId == id);
        _gastroIngredientes.add(_GastroIngredientDraft(
          prodId: id,
          nombre: values['name'] as String,
          cantidad: values['quantity'] as double,
          unidad: values['unit'] as String,
          removible: values['removable'] as bool,
          precioCompra: cost,
        ));
      });
      await ref.read(productosProvider.notifier).load();
    } catch (error) {
      if (mounted) _showError('No fue posible crear el ingrediente: $error');
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      purchaseController.dispose();
      quantityController.dispose();
    }
  }

  Future<void> _addGastroAddition(List<ProductosResponseModel> productos) async {
    final candidates = productos
        .where((item) {
          final controlType =
              (item.prodTipoControl ?? '').trim().toUpperCase();
          return item.prodId != null &&
              item.prodId != _editingId &&
              item.sucuId == _sucursalId &&
              (controlType == 'INSUMO' || controlType == 'PREPARADO');
        })
        .toList()
      ..sort((a, b) => (a.prodNombre ?? '').toLowerCase().compareTo((b.prodNombre ?? '').toLowerCase()));

    if (candidates.isEmpty) {
      _showError(
        'No hay insumos ni productos preparados con receta disponibles en esta sucursal para usar como adición.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    int? selectedId;
    String unit = 'UND';
    String quantityValue = '1';
    String extraPriceValue = '';
    final result = await showDialog<_GastroAdditionDraft>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            scrollable: true,
            title: const Text('Agregar adición al pedido'),
            content: SizedBox(
              width: 540,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Insumo o producto preparado',
                        prefixIcon: Icon(Icons.add_circle_outline_rounded),
                      ),
                      items: candidates
                          .map((item) => DropdownMenuItem<int>(
                                value: item.prodId,
                                child: Text(
                                  '${item.prodNombre ?? 'Producto'} · costo ${_formatNumber(item.precioCompraVigente ?? 0)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedId = value),
                      validator: (value) => value == null ? 'Selecciona una adición' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '1',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 4),
                            decoration: const InputDecoration(labelText: 'Cantidad', prefixIcon: Icon(Icons.numbers_rounded)),
                            validator: _requiredPositive,
                            onChanged: (value) => quantityValue = value,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<String>(
                            value: unit,
                            decoration: const InputDecoration(labelText: 'Unidad'),
                            items: const ['UND', 'G', 'KG', 'ML', 'L']
                                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setDialogState(() => unit = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 15, fractionDigits: 2),
                      decoration: const InputDecoration(
                        labelText: 'Precio adicional al cliente',
                        helperText: 'Es independiente del costo de compra del ingrediente.',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                      validator: _requiredPositiveOrZero,
                      onChanged: (value) => extraPriceValue = value,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final product = candidates.firstWhere((item) => item.prodId == selectedId);
                  Navigator.pop(
                    dialogContext,
                    _GastroAdditionDraft(
                      prodId: selectedId!,
                      nombre: product.prodNombre ?? 'Producto $selectedId',
                      cantidad: _parseDouble(quantityValue) ?? 1,
                      unidad: unit,
                      precioAdicional: _parseDouble(extraPriceValue) ?? 0,
                      precioCompra: product.precioCompraVigente,
                    ),
                  );
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
        ),
      );

    if (result == null || !mounted) return;
    setState(() {
      _gastroAdiciones.removeWhere((item) => item.prodId == result.prodId);
      _gastroAdiciones.add(result);
    });
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (selected == null) return;
    setState(() {
      _fechaVencimiento = selected;
      _fechaVencimientoController.text = _formatDate(selected);
    });
  }

  void _goNext() {
    if (_currentStep == 0 && !_validateGeneral()) return;
    if (_currentStep == 1) {
      if (!(_priceFormKey.currentState?.validate() ?? false)) return;
      if (!_validatePriceRelationship()) return;
    }
    if (_currentStep == 2 && !(_inventoryFormKey.currentState?.validate() ?? false)) return;
    setState(() => _currentStep = math.min(3, _currentStep + 1));
  }

  bool _validateGeneral() {
    final validForm = _generalFormKey.currentState?.validate() ?? false;
    if (!validForm) return false;
    if (_sucursalId == null) {
      _showError('No se encontró la sucursal asignada al usuario.');
      return false;
    }
    if (_tipoId == null) {
      _showError('Selecciona un tipo de producto.');
      return false;
    }
    return true;
  }

  bool _validatePriceRelationship() {
    final purchasePrice = _parseDouble(_valorCompraController.text);
    final salePrice = _parseDouble(_valorVentaController.text);
    if (purchasePrice == null || salePrice == null) return false;

    final purchaseQuantity = _compraPorCantidad
        ? _parseDouble(_cantidadCompraController.text)
        : null;
    if (_compraPorCantidad &&
        (purchaseQuantity == null || purchaseQuantity <= 0)) {
      _showError('Indica cuántas unidades contiene la presentación de compra.');
      return false;
    }

    final unitPurchasePrice = _compraPorCantidad
        ? purchasePrice / purchaseQuantity!
        : purchasePrice;

    if (_tipoControl == 'INSUMO') {
      if (salePrice < 0) {
        _showError('El precio de venta del insumo no puede ser negativo.');
        return false;
      }
      return true;
    }

    if (salePrice < unitPurchasePrice) {
      _showError(
        'El precio de venta no puede ser menor que el costo unitario de compra.',
      );
      return false;
    }
    return true;
  }

  Future<void> _confirmAndSave(BuildContext context, AppPalette palette) async {
    if (!_validateGeneral()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!(_priceFormKey.currentState?.validate() ?? false) ||
        !_validatePriceRelationship()) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!(_inventoryFormKey.currentState?.validate() ?? false)) {
      setState(() => _currentStep = 2);
      return;
    }

    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final compra = _parseDouble(_valorCompraController.text)!;
      final venta = _parseDouble(_valorVentaController.text)!;
      final porcentaje = _aplicaImpuesto ? (_parseDouble(_porcentajeImpuestoController.text) ?? 0.0) : 0.0;
      final impuesto = _aplicaImpuesto ? (venta * porcentaje / 100) : 0.0;
      final marcaId = await _resolveMarcaId();
      final productBody = <String, dynamic>{
        if (_editingId != null) 'prodId': _editingId,
        'sucuId': _sucursalId,
        'tpprId': _tipoId,
        'mrcaId': marcaId,
        'prodNombre': _nombreController.text.trim(),
        'prodDescripcion': _descripcionController.text.trim(),
        'prodFoto': _fotoController.text.trim(),
        'prodFechaVencimiento': _toIsoDate(_fechaVencimiento),
        'prodCompraPorCantidad': _compraPorCantidad ? 1 : 0,
        'prodCantidadCompra': _compraPorCantidad ? _parseDouble(_cantidadCompraController.text) : null,
        'prodPresentacionCompra': _compraPorCantidad ? _presentacionCompraController.text.trim() : null,
        'prodStockMinimo': _parseDouble(_stockMinimoController.text) ?? 0,
        'prodStockMaximo': _stockMaximoSinLimite
            ? null
            : _parseDouble(_stockMaximoController.text),
        'prodTipoControl': _tipoControl,
        'prodUnidadBase': _unidadBase,
      };

      final productResponse = _editing
          ? await apiClient.put<ProductosResponseModel>(
              '/api/v1/productos/$_editingId',
              productBody,
              (json) => ProductosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
            )
          : await apiClient.post<ProductosResponseModel>(
              '/api/v1/productos',
              productBody,
              (json) => ProductosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
            );
      final savedProduct = productResponse.data;
      final savedProductId = savedProduct?.prodId ?? _editingId;
      final savedSucursalId = savedProduct?.sucuId ?? _sucursalId;

      if (savedProductId == null || savedSucursalId == null) {
        throw Exception('No fue posible obtener el producto guardado.');
      }

      final shouldCreatePrice = _shouldCreatePrice(
        compra: compra,
        venta: venta,
        aplicaImpuesto: _aplicaImpuesto,
        porcentaje: porcentaje,
      );

      if (shouldCreatePrice) {
        await apiClient.post<PreciosResponseModel>(
          '/api/v1/precios',
          <String, dynamic>{
            'prodId': savedProductId,
            'sucuId': savedSucursalId,
            'precEstado': 1,
            'precValorVenta': venta,
            'precValorCompra': compra,
            'precFechaInicia': DateTime.now().toIso8601String(),
            'precAplicaImpuesto': _aplicaImpuesto ? 1 : 0,
            'precPorcentajeImpuesto': porcentaje,
            'precValorImpuesto': impuesto,
          },
          (json) => PreciosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      }

      await apiClient.put<Map<String, dynamic>>(
        '/api/v1/productos/$savedProductId/gastro?sucursalId=$savedSucursalId',
        <String, dynamic>{
          'tipoControl': _tipoControl,
          'unidadBase': _unidadBase,
          'estacionPreparacion':
              _tipoControl == 'PREPARADO' ? _estacionPreparacion : null,
          'ingredientes': _tipoControl == 'PREPARADO'
              ? _gastroIngredientes.map((item) => item.toJson()).toList()
              : const <Map<String, dynamic>>[],
          'adiciones': _tipoControl == 'PREPARADO'
              ? _gastroAdiciones.map((item) => item.toJson()).toList()
              : const <Map<String, dynamic>>[],
        },
        (json) => Map<String, dynamic>.from(json as Map),
      );

      if (_registrarInventario) {
        final cantidad = _parseDouble(_inventarioCantidadController.text);
        if (cantidad != null && cantidad > 0) {
          await apiClient.post<InventarioResponseModel>(
            '/api/v1/inventario',
            <String, dynamic>{
              'prodId': savedProductId,
              'sucuId': savedSucursalId,
              'invtCantidad': cantidad,
              'invtFecha': DateTime.now().toIso8601String(),
            },
            (json) => InventarioResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        }
      }

      await Future.wait([
        ref.read(productosProvider.notifier).load(),
        ref.read(preciosProvider.notifier).load(),
        ref.read(inventarioProvider.notifier).load(),
      ]);

      // Si el producto se está registrando dentro de la puesta en marcha,
      // dejamos invalidado el estado del asistente para que al regresar se
      // reevalúe contra los datos recién guardados.
      if (ref.read(businessSetupGuidedModeProvider)) {
        ref.invalidate(businessSetupStatusProvider);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Producto modificado correctamente' : 'Producto creado correctamente')),
      );
      context.go('/productos/$savedProductId');
    } catch (error) {
      if (!mounted) return;
      _showError('No fue posible guardar el producto: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  bool _shouldCreatePrice({
    required double compra,
    required double venta,
    required bool aplicaImpuesto,
    required double porcentaje,
  }) {
    if (!_editing) return true;

    // Si el producto no tenía precio cargado, sí se debe crear uno.
    if (_originalValorCompra == null || _originalValorVenta == null || _originalAplicaImpuesto == null) {
      return true;
    }

    return !_sameNumber(_originalValorCompra, compra) ||
        !_sameNumber(_originalValorVenta, venta) ||
        _originalAplicaImpuesto != aplicaImpuesto ||
        !_sameNumber(_originalPorcentajeImpuesto ?? 0.0, aplicaImpuesto ? porcentaje : 0.0);
  }

  bool _sameNumber(num? a, num? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a.toDouble() - b.toDouble()).abs() < 0.0001;
  }

  Future<void> _createTipoProducto(AppPalette palette) async {
    final nombre = TextEditingController();
    final descripcion = TextEditingController();
    final created = await _showCatalogDialog(
      title: 'Nuevo tipo de producto',
      primaryLabel: 'Nombre',
      secondaryLabel: 'Descripción',
      primaryController: nombre,
      secondaryController: descripcion,
      palette: palette,
    );
    if (created != true) return;
    try {
      final response = await ref.read(apiClientProvider).post<TiposProductoResponseModel>(
            '/api/v1/tiposproducto',
            {'tpprNombre': nombre.text.trim(), 'tpprDescripcion': descripcion.text.trim()},
            (json) => TiposProductoResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
          );
      await ref.read(tiposproductoProvider.notifier).load();
      setState(() => _tipoId = response.data?.tpprId);
    } catch (error) {
      _showError('No fue posible crear el tipo de producto: $error');
    }
  }

  Future<int> _resolveMarcaId() async {
    if (_marcaId != null) return _marcaId!;
    final existing = _firstOrNull(ref.read(marcasProvider).items.where(
      (brand) => (brand.mrcaNombre ?? '').trim().toLowerCase() == 'ninguna' && brand.mrcaId != null,
    ));
    if (existing?.mrcaId != null) return existing!.mrcaId!;
    final result = await ref.read(apiClientProvider).post<MarcasResponseModel>(
      '/api/v1/marcas',
      <String, dynamic>{'mrcaNombre': 'Ninguna', 'mrcaIdentificacion': 'SIN_MARCA'},
      (json) => MarcasResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    final id = result.data?.mrcaId;
    if (id == null) throw StateError('No se pudo registrar la marca Ninguna.');
    await ref.read(marcasProvider.notifier).load();
    return id;
  }

  Future<void> _createMarca(AppPalette palette) async {
    final nombre = TextEditingController();
    final identificacion = TextEditingController();
    final created = await _showCatalogDialog(
      title: 'Nueva marca',
      primaryLabel: 'Nombre',
      secondaryLabel: 'Identificación o referencia',
      primaryController: nombre,
      secondaryController: identificacion,
      palette: palette,
      secondaryRequired: false,
    );
    if (created != true) return;
    try {
      final response = await ref.read(apiClientProvider).post<MarcasResponseModel>(
            '/api/v1/marcas',
            {
              'mrcaNombre': nombre.text.trim(),
              'mrcaIdentificacion': identificacion.text.trim().isEmpty ? nombre.text.trim() : identificacion.text.trim(),
            },
            (json) => MarcasResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
          );
      await ref.read(marcasProvider.notifier).load();
      setState(() => _marcaId = response.data?.mrcaId);
    } catch (error) {
      _showError('No fue posible crear la marca: $error');
    }
  }

  Future<bool?> _showCatalogDialog({
    required String title,
    required String primaryLabel,
    required String secondaryLabel,
    required TextEditingController primaryController,
    required TextEditingController secondaryController,
    required AppPalette palette,
    bool secondaryRequired = true,
  }) {
    final isBrand = title.toLowerCase().contains('marca');
    final primaryMaxLength = 30;
    final secondaryMaxLength = isBrand ? 50 : 300;
    final formKey = GlobalKey<FormState>();
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: primaryController,
                maxLength: primaryMaxLength,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(primaryMaxLength)],
                decoration: InputDecoration(labelText: primaryLabel),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: secondaryController,
                maxLength: secondaryMaxLength,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(secondaryMaxLength)],
                decoration: InputDecoration(labelText: secondaryLabel),
                validator: secondaryRequired ? _required : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, true);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Este campo es obligatorio' : null;

  String? _requiredPositive(String? value) {
    final number = _parseDouble(value ?? '');
    if (number == null || number <= 0) return 'Ingresa un valor mayor a cero';
    return null;
  }

  String? _requiredPositiveOrZero(String? value) {
    final number = _parseDouble(value ?? '');
    if (number == null || number < 0) return 'Ingresa un valor válido';
    return null;
  }

  String? _validateStockMaximo(String? value) {
    if (_stockMaximoSinLimite) return null;
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Ingresa el stock máximo';
    final maximo = _parseDouble(raw);
    final minimo = _parseDouble(_stockMinimoController.text) ?? 0;
    if (maximo == null || maximo < 0) return 'Ingresa un valor válido';
    if (maximo < minimo) return 'Debe ser mayor o igual al mínimo';
    return null;
  }
}

class _ProductDraftOverview extends StatelessWidget {
  const _ProductDraftOverview({
    required this.palette,
    required this.image,
    required this.name,
    required this.description,
    required this.typeName,
    required this.brandName,
    required this.branchName,
    required this.purchasePrice,
    required this.salePrice,
    required this.purchaseByQuantity,
    required this.purchaseQuantity,
    required this.currentInventory,
    required this.inventoryToAdd,
    required this.expirationDate,
    required this.currentStep,
  });

  final AppPalette palette;
  final String image;
  final String name;
  final String description;
  final String typeName;
  final String brandName;
  final String branchName;
  final double? purchasePrice;
  final double? salePrice;
  final bool purchaseByQuantity;
  final double? purchaseQuantity;
  final double currentInventory;
  final double? inventoryToAdd;
  final DateTime? expirationDate;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final productName = name.trim().isEmpty ? 'Nuevo producto' : name.trim();
    final productDescription = description.trim().isEmpty
        ? 'La descripción aparecerá aquí mientras completas el formulario.'
        : description.trim();
    final purchase = purchasePrice ?? 0;
    final sale = salePrice ?? 0;
    final quantity = purchaseQuantity ?? 0;
    final unitPurchaseCost = purchaseByQuantity && quantity > 0 ? purchase / quantity : purchase;
    final utility = sale - unitPurchaseCost;
    final margin = sale > 0 ? (utility / sale) * 100 : 0.0;
    final finalInventory = currentInventory + (inventoryToAdd ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
            palette.secondary.withOpacity(palette.darkBackground ? 0.10 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.preview_rounded, color: palette.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vista previa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                    Text('Paso ${currentStep + 1} de 4', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(height: 130, child: _ImagePreview(value: image, palette: palette, height: 130)),
          ),
          const SizedBox(height: 12),
          Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '$brandName · $typeName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            productDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 12),
          _DraftInfoRow(icon: Icons.storefront_rounded, label: branchName, palette: palette),
          const SizedBox(height: 8),
          _DraftInfoRow(
            icon: Icons.event_rounded,
            label: expirationDate == null ? 'Sin fecha de vencimiento' : 'Vence ${_formatDate(expirationDate)}',
            palette: palette,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _DraftMetric(
                  label: purchaseByQuantity && quantity > 0 ? 'Compra / unidad' : 'Compra',
                  value: _money(unitPurchaseCost),
                  color: palette.textPrimary,
                ),
                _DraftMetric(label: 'Venta', value: _money(sale), color: palette.secondary),
                _DraftMetric(label: 'Margen', value: '${_formatNumber(margin)}%', color: utility >= 0 ? Colors.greenAccent.shade400 : Colors.redAccent),
                _DraftMetric(label: 'Inventario', value: _formatNumber(finalInventory), color: palette.textPrimary),
              ];
              final columns = constraints.maxWidth >= 300 ? 2 : 1;
              const gap = 8.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final metric in metrics) SizedBox(width: width, child: _DraftMetricCard(metric: metric, palette: palette))],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DraftInfoRow extends StatelessWidget {
  const _DraftInfoRow({required this.icon, required this.label, required this.palette});
  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: palette.secondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DraftMetric {
  const _DraftMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
}

class _DraftMetricCard extends StatelessWidget {
  const _DraftMetricCard({required this.metric, required this.palette});
  final _DraftMetric metric;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.045) : palette.background.withOpacity(0.62),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10)),
          const SizedBox(height: 3),
          Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: metric.color, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.palette,
    required this.editing,
    required this.currentStep,
    required this.onBack,
  });

  final AppPalette palette;
  final bool editing;
  final int currentStep;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  editing ? 'Modificar producto' : 'Crear producto',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _WizardStepIndicator(currentStep: currentStep),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: (currentStep + 1) / 4,
              color: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardStepIndicator extends StatelessWidget {
  const _WizardStepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['Información', 'Precio', 'Inventario', 'Confirmación'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < steps.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: index == currentStep ? Colors.white : Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: index == currentStep ? const Color(0xFF0F172A) : Colors.white.withOpacity(0.2),
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[index],
                  style: TextStyle(
                    color: index == currentStep ? const Color(0xFF0F172A) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final AppPalette palette;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 17, color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProductImagePicker extends StatefulWidget {
  const _ProductImagePicker({required this.palette, required this.controller, this.onChanged});

  final AppPalette palette;
  final TextEditingController controller;
  final VoidCallback? onChanged;

  @override
  State<_ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<_ProductImagePicker> {
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length > InputConstraints.imageMaxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen no puede superar 2 MB.')),
      );
      return;
    }
    final ext = (file?.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    widget.controller.text = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.palette.darkBackground ? Colors.white.withOpacity(0.04) : widget.palette.background.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foto del producto', style: TextStyle(color: widget.palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _ImagePreview(value: value, palette: widget.palette, height: 138),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Cargar foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar foto',
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                    widget.onChanged?.call();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.value, required this.palette, this.height = 160});

  final String value;
  final AppPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: palette.darkBackground ? Colors.white.withOpacity(0.06) : palette.surface,
        alignment: Alignment.center,
        child: Icon(Icons.image_rounded, size: 54, color: palette.secondary),
      );
    }
    if (value.startsWith('data:image')) {
      final index = value.indexOf(',');
      if (index > -1) {
        try {
          return Image.memory(base64Decode(value.substring(index + 1)), height: height, width: double.infinity, fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Image.network(
      value,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        alignment: Alignment.center,
        color: palette.background,
        child: Text('No fue posible mostrar la foto', style: TextStyle(color: palette.textSecondary)),
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.palette,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLength: maxLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: inputFormatters ?? (maxLength == null ? null : <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength!)]),
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: palette.secondary, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        filled: true,
        fillColor: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.secondary, width: 1.4)),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.palette,
    required this.controller,
    required this.label,
    required this.onPick,
    this.onClear,
    this.validator,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: true,
      onTap: onPick,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Puedes dejarla vacía si el producto no tiene vencimiento.',
        prefixIcon: Icon(Icons.event_rounded, color: palette.secondary, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.trim().isNotEmpty && onClear != null)
              IconButton(
                tooltip: 'Quitar fecha',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            IconButton(
              tooltip: 'Seleccionar fecha',
              onPressed: onPick,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
        ),
        filled: true,
        fillColor: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.cardBorder)),
      ),
    );
  }
}

class _ReadOnlyInfoField extends StatelessWidget {
  const _ReadOnlyInfoField({required this.palette, required this.label, required this.value, required this.icon});

  final AppPalette palette;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupRow<T> extends StatelessWidget {
  const _LookupRow({
    required this.palette,
    required this.value,
    required this.label,
    required this.items,
    required this.itemId,
    required this.itemLabel,
    required this.onChanged,
    required this.onCreate,
    this.allowNone = false,
  });

  final AppPalette palette;
  final int? value;
  final String label;
  final List<T> items;
  final int? Function(T item) itemId;
  final String Function(T item) itemLabel;
  final ValueChanged<int?> onChanged;
  final VoidCallback onCreate;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: items.any((item) => itemId(item) == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(Icons.list_alt_rounded, color: palette.secondary, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.cardBorder)),
            ),
            items: [
              if (allowNone) const DropdownMenuItem<int>(value: null, child: Text('Ninguna')),
              for (final item in items.where((item) => !allowNone || itemLabel(item).trim().toLowerCase() != 'ninguna'))
                DropdownMenuItem<int>(value: itemId(item), child: Text(itemLabel(item), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Crear $label',
          child: SizedBox(
            height: 48,
            width: 48,
            child: FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.palette, required this.value, required this.title, required this.subtitle, required this.icon, required this.onChanged});

  final AppPalette palette;
  final bool value;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.secondary, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.25)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PricePreview extends StatelessWidget {
  const _PricePreview({
    required this.palette,
    required this.compra,
    required this.venta,
    required this.compraPorCantidad,
    required this.presentacionCompra,
    required this.cantidadCompra,
    required this.costoUnitarioCompra,
    required this.aplicaImpuesto,
    required this.porcentaje,
    required this.impuesto,
    required this.totalConImpuesto,
  });

  final AppPalette palette;
  final double compra;
  final double venta;
  final bool compraPorCantidad;
  final String presentacionCompra;
  final double cantidadCompra;
  final double costoUnitarioCompra;
  final bool aplicaImpuesto;
  final double porcentaje;
  final double impuesto;
  final double totalConImpuesto;

  @override
  Widget build(BuildContext context) {
    final utility = venta - costoUnitarioCompra;
    final margin = venta > 0 ? (utility / venta) * 100 : 0.0;
    return _SummaryPanel(
      palette: palette,
      rows: [
        _SummaryRow('Compra', _money(compra)),
        _SummaryRow(
          'Presentación',
          compraPorCantidad
              ? '${presentacionCompra.trim().isEmpty ? 'Presentación' : presentacionCompra.trim()} de ${_formatNumber(cantidadCompra)} unidades'
              : 'Compra por unidad',
        ),
        _SummaryRow('Costo unitario compra', _money(costoUnitarioCompra)),
        _SummaryRow('Venta', _money(venta)),
        _SummaryRow('Utilidad estimada', _money(utility)),
        _SummaryRow('Margen estimado', '${_formatNumber(margin)}%'),
        _SummaryRow('Impuesto', aplicaImpuesto ? '${_formatNumber(porcentaje)}% = ${_money(impuesto)}' : 'No aplica'),
        _SummaryRow('Venta + impuesto', aplicaImpuesto ? _money(totalConImpuesto) : _money(venta)),
      ],
    );
  }
}

class _InventoryHistoryPanel extends StatelessWidget {
  const _InventoryHistoryPanel({required this.palette, required this.items});

  final AppPalette palette;
  final List<InventarioResponseModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: palette.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este producto todavía no tiene historial de inventario.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return _SummaryPanel(
      palette: palette,
      rows: [
        for (final item in items.take(8))
          _SummaryRow(
            _shortDateTime(item.invtFecha),
            '${_formatNumber(item.invtCantidad ?? 0)} unidades',
          ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.palette, required this.rows});

  final AppPalette palette;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.darkBackground ? Colors.white.withOpacity(0.04) : palette.background.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 150, child: Text(rows[i].label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Text(rows[i].value.trim().isEmpty ? '-' : rows[i].value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
              ],
            ),
            if (i < rows.length - 1) Divider(height: 20, color: palette.cardBorder),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;
}

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.palette,
    required this.saving,
    required this.currentStep,
    required this.onPrevious,
    required this.onNext,
    required this.onSave,
  });

  final AppPalette palette;
  final bool saving;
  final int currentStep;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == 3;
    final isInventoryStep = currentStep == 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final previous = _WizardActionButton(
          palette: palette,
          outlined: true,
          enabled: !saving && onPrevious != null,
          icon: Icons.arrow_back_rounded,
          label: 'Anterior',
          onPressed: onPrevious,
        );
        final next = _WizardActionButton(
          palette: palette,
          outlined: false,
          enabled: !saving,
          icon: isLast
              ? Icons.check_circle_rounded
              : isInventoryStep
                  ? Icons.fact_check_rounded
                  : Icons.arrow_forward_rounded,
          label: isLast
              ? 'Confirmar y guardar'
              : isInventoryStep
                  ? 'Revisar y confirmar'
                  : 'Siguiente',
          loading: saving,
          onPressed: isLast ? onSave : onNext,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [next, const SizedBox(height: 10), previous],
          );
        }
        return Row(children: [Expanded(child: previous), const SizedBox(width: 12), Expanded(child: next)]);
      },
    );
  }
}

class _WizardActionButton extends StatelessWidget {
  const _WizardActionButton({
    required this.palette,
    required this.outlined,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final AppPalette palette;
  final bool outlined;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 19),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
          ),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    if (outlined) {
      return SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.primary,
            side: BorderSide(color: palette.cardBorder),
            shape: shape,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: shape,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GastroIngredientDraft {
  const _GastroIngredientDraft({
    required this.prodId,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.removible,
    this.precioCompra,
  });

  final int prodId;
  final String nombre;
  final double cantidad;
  final String unidad;
  final bool removible;
  final double? precioCompra;

  factory _GastroIngredientDraft.fromJson(Map<String, dynamic> json) =>
      _GastroIngredientDraft(
        prodId: (json['prodId'] as num).toInt(),
        nombre: json['nombre']?.toString() ?? 'Ingrediente',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1,
        unidad: json['unidad']?.toString() ?? 'UND',
        removible: json['removible'] != false,
        precioCompra: (json['precioCompra'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prodId': prodId,
        'cantidad': cantidad,
        'unidad': unidad,
        'removible': removible,
      };
}

class _GastroAdditionDraft {
  const _GastroAdditionDraft({
    required this.prodId,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.precioAdicional,
    this.precioCompra,
  });

  final int prodId;
  final String nombre;
  final double cantidad;
  final String unidad;
  final double precioAdicional;
  final double? precioCompra;

  factory _GastroAdditionDraft.fromJson(Map<String, dynamic> json) =>
      _GastroAdditionDraft(
        prodId: (json['prodId'] as num).toInt(),
        nombre: json['nombre']?.toString() ?? 'Adición',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1,
        unidad: json['unidad']?.toString() ?? 'UND',
        precioAdicional: (json['precioAdicional'] as num?)?.toDouble() ?? 0,
        precioCompra: (json['precioCompra'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prodId': prodId,
        'cantidad': cantidad,
        'unidad': unidad,
        'precioAdicional': precioAdicional,
      };
}

class _GastroControlSection extends StatelessWidget {
  const _GastroControlSection({
    required this.palette,
    required this.tipoControl,
    required this.unidadBase,
    required this.estacionPreparacion,
    required this.ingredientes,
    required this.adiciones,
    required this.onTipoChanged,
    required this.onUnidadChanged,
    required this.onEstacionChanged,
    required this.onAddIngredient,
    required this.onAddAddition,
    required this.onRemoveIngredient,
    required this.onRemoveAddition,
  });

  final AppPalette palette;
  final String tipoControl;
  final String unidadBase;
  final String estacionPreparacion;
  final List<_GastroIngredientDraft> ingredientes;
  final List<_GastroAdditionDraft> adiciones;
  final ValueChanged<String> onTipoChanged;
  final ValueChanged<String> onUnidadChanged;
  final ValueChanged<String> onEstacionChanged;
  final VoidCallback? onAddIngredient;
  final VoidCallback? onAddAddition;
  final ValueChanged<int> onRemoveIngredient;
  final ValueChanged<int> onRemoveAddition;

  @override
  Widget build(BuildContext context) {
    final prepared = tipoControl == 'PREPARADO';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, color: palette.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Configuración para gastrobar',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Define si el registro es un producto normal, un insumo o un plato/bebida preparada con receta.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 560;
              final typeField = DropdownButtonFormField<String>(
                // Flutter conserva el estado interno del FormField al reconstruir;
                // la clave permite reflejar la clasificación cargada al editar.
                key: ValueKey('tipo-control-$tipoControl'),
                value: tipoControl,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Control del producto',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'NORMAL', child: Text('Producto normal')),
                  DropdownMenuItem(value: 'INSUMO', child: Text('Ingrediente / insumo')),
                  DropdownMenuItem(value: 'PREPARADO', child: Text('Producto preparado / receta')),
                ],
                onChanged: (value) {
                  if (value != null) onTipoChanged(value);
                },
              );
              final unitField = DropdownButtonFormField<String>(
                key: ValueKey('unidad-base-$unidadBase'),
                value: unidadBase,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Unidad base de inventario',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                items: const ['UND', 'G', 'KG', 'ML', 'L']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onUnidadChanged(value);
                },
              );

              if (!horizontal) {
                return Column(
                  children: [typeField, const SizedBox(height: 10), unitField],
                );
              }
              return Row(
                children: [
                  Expanded(child: typeField),
                  const SizedBox(width: 10),
                  Expanded(child: unitField),
                ],
              );
            },
          ),
          if (prepared) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: estacionPreparacion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estación de preparación',
                prefixIcon: Icon(Icons.room_service_rounded),
                helperText: 'Define a qué tablero llegará este producto cuando se ordene.',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'COCINA',
                  child: Text('Cocina'),
                ),
                DropdownMenuItem(
                  value: 'BARRA',
                  child: Text('Barra'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onEstacionChanged(value);
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Receta base',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAddIngredient,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ingrediente'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ingredientes.isEmpty)
              Text(
                'Aún no hay ingredientes. Agrégalos para permitir pedidos como “sin cebolla”.',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              )
            else
              ...List.generate(ingredientes.length, (index) {
                final item = ingredientes[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: Text(item.nombre, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${_formatNumber(item.cantidad)} ${item.unidad} · costo ${_money(item.precioCompra)}'
                    '${item.removible ? ' · se puede quitar' : ' · obligatorio'}',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  trailing: IconButton(
                    tooltip: 'Quitar de la receta',
                    onPressed: () => onRemoveIngredient(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                );
              }),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Adiciones disponibles',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAddAddition,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Adición'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (adiciones.isEmpty)
              Text(
                'Puedes ofrecer queso extra, carne adicional, tocineta u otras opciones con precio propio.',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              )
            else
              ...List.generate(adiciones.length, (index) {
                final item = adiciones[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: Text(item.nombre, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${_formatNumber(item.cantidad)} ${item.unidad} · costo ${_money(item.precioCompra)} · cobra +${_money(item.precioAdicional)}',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  trailing: IconButton(
                    tooltip: 'Quitar adición',
                    onPressed: () => onRemoveAddition(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

String _titleForStep(int step) => switch (step) {
      0 => 'Información general',
      1 => 'Precio, compra e impuesto',
      2 => 'Inventario y reposición',
      _ => 'Revisión final',
    };

String _subtitleForStep(int step) => switch (step) {
      0 => 'Foto, nombre, descripción, vencimiento, tipo y marca.',
      1 => 'Valor de compra, compra por presentación/cantidad, venta e impuesto.',
      2 => 'Historial de inventario y carga opcional antes de confirmar.',
      _ => 'Resumen final. Aquí decides si guardar o volver a corregir.',
    };

DateTime? _tryParseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String? _toIsoDate(DateTime? value) {
  if (value == null) return null;
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

double? _parseDouble(String value) => double.tryParse(value.trim().replaceAll('.', '').replaceAll(',', '.'));

String _toFieldNumber(num? value) {
  if (value == null) return '';
  if (value % 1 == 0) return value.toInt().toString();
  return value.toString();
}

String _money(num? value) {
  if (value == null) return r'$ 0';
  final text = _formatNumber(value);
  return '\$ $text';
}

String _formatNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble % 1 == 0) return asDouble.toInt().toString();
  return asDouble.toStringAsFixed(2);
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}

String _shortDateTime(String? value) {
  if (value == null || value.trim().isEmpty) return 'Sin fecha';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}
