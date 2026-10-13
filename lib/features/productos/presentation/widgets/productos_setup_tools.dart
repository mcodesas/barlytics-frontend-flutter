import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_download.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/producto_catalogo_base_model.dart';
import '../../data/models/productos_response_model.dart';
import '../providers/productos_provider.dart';

class ProductosSetupTools extends ConsumerStatefulWidget {
  const ProductosSetupTools({
    super.key,
    required this.palette,
    required this.branches,
    required this.activeBranchId,
    required this.onCompleted,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<ProductosSetupTools> createState() => _ProductosSetupToolsState();
}

class _ProductosSetupToolsState extends ConsumerState<ProductosSetupTools> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: palette.panelDecoration(
          baseRadius: 22,
          tint: palette.secondary,
          elevated: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.upload_file_rounded, color: palette.secondary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carga inicial y migración de productos',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selecciona productos del catálogo maestro de BarLytics, cópialos desde otra sucursal o carga los que faltan usando Excel.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _selectFromBaseCatalog,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Catálogo BarLytics'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar plantilla Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadProductList,
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text('Descargar lista'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _importExcel,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Subir productos desde Excel'),
                ),
                if (widget.branches.length > 1)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _copyFromBranch,
                    icon: const Icon(Icons.content_copy_rounded),
                    label: const Text('Seleccionar de otra sucursal'),
                  ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectFromBaseCatalog() async {
    final branchId = widget.activeBranchId;
    if (branchId == null) {
      _message(
        'Selecciona primero la sucursal donde agregarás los productos.',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    List<ProductoCatalogoBaseModel> products;
    try {
      products = await ref
          .read(productosSetupRemoteDataSourceProvider)
          .baseCatalog(branchId);
    } catch (error) {
      if (mounted) {
        _message('No fue posible consultar el catálogo BarLytics: $error',
            error: true);
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (products.isEmpty) {
      _message('El catálogo maestro todavía no tiene productos disponibles.');
      return;
    }

    final decision = await showDialog<_BaseCatalogDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _BaseCatalogDialog(
        palette: widget.palette,
        products: products,
      ),
    );
    if (decision == null || decision.items.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(productosSetupRemoteDataSourceProvider)
          .importBaseCatalog(
            sucursalId: branchId,
            items: decision.items,
          );
      if (!mounted) return;
      await widget.onCompleted();
      if (!mounted) return;
      await _showResult(
        title: 'Productos agregados desde el catálogo BarLytics',
        result: result,
      );
    } catch (error) {
      if (mounted) {
        _message('No fue posible importar el catálogo: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(productosSetupRemoteDataSourceProvider).downloadTemplate();
      await saveDownloadedFile(
        bytes: bytes,
        dialogTitle: 'Guardar plantilla de productos',
        fileName: 'plantilla_productos_barlytics.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        allowedExtensions: const ['xlsx'],
      );
      if (!mounted) return;
      _message('Plantilla generada. Complétala y luego usa “Subir productos desde Excel”.');
    } catch (error) {
      if (mounted) _message('No fue posible descargar la plantilla: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadProductList() async {
    final branchId = widget.activeBranchId;
    if (branchId == null) {
      _message('Selecciona primero la sucursal que deseas descargar.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(productosSetupRemoteDataSourceProvider)
          .downloadProductList(branchId);
      await saveDownloadedFile(
        bytes: bytes,
        dialogTitle: 'Guardar lista de productos',
        fileName: 'productos_barlytics_sucursal_$branchId.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        allowedExtensions: const ['xlsx'],
      );
      if (!mounted) return;
      _message(
        'Lista descargada con producto, cantidad, unidad, precio de compra y precio de venta.',
      );
    } catch (error) {
      if (mounted) {
        _message('No fue posible descargar la lista de productos: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExcel() async {
    final branchId = widget.activeBranchId;
    if (branchId == null) {
      _message('Selecciona primero la sucursal donde cargarás los productos.', error: true);
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      allowMultiple: false,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(productosSetupRemoteDataSourceProvider).importExcel(
            sucursalId: branchId,
            fileName: file.name,
            bytes: bytes,
          );
      if (!mounted) return;
      await widget.onCompleted();
      if (!mounted) return;
      await _showResult(
        title: 'Carga de productos finalizada',
        result: result,
      );
    } catch (error) {
      if (mounted) _message('No fue posible importar el Excel: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyFromBranch() async {
    final targetId = widget.activeBranchId;
    if (targetId == null) {
      _message('Selecciona primero la sucursal destino.', error: true);
      return;
    }

    final sources = widget.branches
        .where((branch) => branch.sucuId != null && branch.sucuId != targetId)
        .toList(growable: false);
    if (sources.isEmpty) {
      _message('No hay otra sucursal disponible para copiar productos.');
      return;
    }

    final sourceId = sources.first.sucuId!;
    setState(() => _busy = true);
    try {
      final products =
          await ref.read(productosSetupRemoteDataSourceProvider).branchProducts(sourceId);
      if (!mounted) return;

      final decision = await showDialog<_CopyDecision>(
        context: context,
        builder: (dialogContext) => _CopyProductsDialog(
          palette: widget.palette,
          sources: sources,
          initialSourceId: sourceId,
          initialProducts: products,
          loadProducts: (id) =>
              ref.read(productosSetupRemoteDataSourceProvider).branchProducts(id),
        ),
      );
      if (decision == null || decision.items.isEmpty) return;

      final result = await ref.read(productosSetupRemoteDataSourceProvider).copySelected(
            sourceSucursalId: decision.sourceSucursalId,
            targetSucursalId: targetId,
            items: decision.items,
          );
      if (!mounted) return;
      await widget.onCompleted();
      if (!mounted) return;
      await _showResult(title: 'Migración de productos finalizada', result: result);
    } catch (error) {
      if (mounted) _message('No fue posible migrar los productos: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult({
    required String title,
    required Map<String, dynamic> result,
  }) async {
    final warnings = (result['warnings'] as List? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Procesados: ${result['processed'] ?? 0} · '
                  'creados: ${result['created'] ?? 0} · '
                  'actualizados: ${result['updated'] ?? 0} · '
                  'omitidos: ${result['skipped'] ?? 0}',
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Observaciones',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  ...warnings.take(20).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $item'),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _BaseCatalogDecision {
  const _BaseCatalogDecision({required this.items});

  final List<Map<String, dynamic>> items;
}

class _BaseCatalogDialog extends StatefulWidget {
  const _BaseCatalogDialog({
    required this.palette,
    required this.products,
  });

  final AppPalette palette;
  final List<ProductoCatalogoBaseModel> products;

  @override
  State<_BaseCatalogDialog> createState() => _BaseCatalogDialogState();
}

class _BaseCatalogDialogState extends State<_BaseCatalogDialog> {
  final Set<int> _selected = <int>{};
  final Map<int, TextEditingController> _purchaseControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _saleControllers =
      <int, TextEditingController>{};

  String _query = '';
  String _type = 'Todos';
  String _brand = 'Todas';
  String? _error;

  @override
  void dispose() {
    for (final controller in _purchaseControllers.values) {
      controller.dispose();
    }
    for (final controller in _saleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _types {
    final values = widget.products
        .map((item) => item.tipoProducto.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _brands {
    final values = widget.products
        .map((item) => item.marca.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<ProductoCatalogoBaseModel> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    return widget.products.where((item) {
      if (_type != 'Todos' && item.tipoProducto != _type) return false;
      if (_brand != 'Todas' && item.marca != _brand) return false;
      if (query.isEmpty) return true;
      final text = [
        item.nombre,
        item.descripcion,
        item.tipoProducto,
        item.marca,
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList(growable: false);
  }

  void _setSelected(ProductoCatalogoBaseModel product, bool selected) {
    if (product.alreadyInBranch) return;
    setState(() {
      _error = null;
      if (selected) {
        _selected.add(product.catalogId);
        _purchaseControllers.putIfAbsent(
          product.catalogId,
          () => TextEditingController(
            text: _priceText(product.precioCompra),
          ),
        );
        _saleControllers.putIfAbsent(
          product.catalogId,
          () => TextEditingController(
            text: _priceText(product.precioVenta),
          ),
        );
      } else {
        _selected.remove(product.catalogId);
      }
    });
  }

  void _toggleVisible() {
    final selectable =
        _visibleProducts.where((item) => !item.alreadyInBranch).toList();
    if (selectable.isEmpty) return;
    final allSelected =
        selectable.every((item) => _selected.contains(item.catalogId));

    setState(() {
      _error = null;
      for (final item in selectable) {
        if (allSelected) {
          _selected.remove(item.catalogId);
        } else {
          _selected.add(item.catalogId);
          _purchaseControllers.putIfAbsent(
            item.catalogId,
            () => TextEditingController(
              text: _priceText(item.precioCompra),
            ),
          );
          _saleControllers.putIfAbsent(
            item.catalogId,
            () => TextEditingController(
              text: _priceText(item.precioVenta),
            ),
          );
        }
      }
    });
  }

  void _submit() {
    if (_selected.isEmpty) {
      setState(() => _error = 'Selecciona al menos un producto.');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final id in _selected) {
      final purchase = _parsePrice(_purchaseControllers[id]?.text);
      final sale = _parsePrice(_saleControllers[id]?.text);
      if (purchase == null || purchase < 0 || sale == null || sale <= 0) {
        setState(() {
          _error =
              'Revisa los precios: compra debe ser 0 o mayor y venta debe ser mayor que 0.';
        });
        return;
      }
      items.add(<String, dynamic>{
        'catalogId': id,
        'purchasePrice': purchase,
        'salePrice': sale,
      });
    }

    Navigator.of(context).pop(_BaseCatalogDecision(items: items));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final visible = _visibleProducts;
    final selectable = visible.where((item) => !item.alreadyInBranch).toList();
    final allVisibleSelected = selectable.isNotEmpty &&
        selectable.every((item) => _selected.contains(item.catalogId));

    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: palette.secondary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catálogo BarLytics',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Selecciona productos y ajusta sus precios antes de agregarlos.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 940,
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto',
                    hintText: 'Nombre, descripción, tipo o marca',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                );
                final type = DropdownButtonFormField<String>(
                  value: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'Todos',
                      child: Text('Todos'),
                    ),
                    ..._types.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? 'Todos'),
                );
                final brand = DropdownButtonFormField<String>(
                  value: _brand,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'Todas',
                      child: Text('Todas'),
                    ),
                    ..._brands.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _brand = value ?? 'Todas'),
                );

                if (constraints.maxWidth < 700) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: type),
                          const SizedBox(width: 8),
                          Expanded(child: brand),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 8),
                    Expanded(child: type),
                    const SizedBox(width: 8),
                    Expanded(child: brand),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selected.length} seleccionado(s) · '
                    '${visible.length} visible(s)',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: selectable.isEmpty ? null : _toggleVisible,
                  icon: Icon(
                    allVisibleSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                  ),
                  label: Text(
                    allVisibleSelected
                        ? 'Quitar visibles'
                        : 'Seleccionar visibles',
                  ),
                ),
              ],
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.danger.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: palette.danger.withOpacity(.25)),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No hay productos con estos filtros.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final product = visible[index];
                        return _BaseCatalogProductTile(
                          palette: palette,
                          product: product,
                          selected:
                              _selected.contains(product.catalogId),
                          purchaseController:
                              _purchaseControllers[product.catalogId],
                          saleController:
                              _saleControllers[product.catalogId],
                          onSelected: (value) =>
                              _setSelected(product, value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty ? null : _submit,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text('Agregar ${_selected.length} producto(s)'),
        ),
      ],
    );
  }

  double? _parsePrice(String? value) {
    if (value == null) return null;
    final normalized = value
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized);
  }

  String _priceText(double value) => value.round().toString();
}

class _BaseCatalogProductTile extends StatelessWidget {
  const _BaseCatalogProductTile({
    required this.palette,
    required this.product,
    required this.selected,
    required this.purchaseController,
    required this.saleController,
    required this.onSelected,
  });

  final AppPalette palette;
  final ProductoCatalogoBaseModel product;
  final bool selected;
  final TextEditingController? purchaseController;
  final TextEditingController? saleController;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final locked = product.alreadyInBranch;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? palette.secondary.withOpacity(.10)
            : palette.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? palette.secondary : palette.cardBorder,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: locked ? true : selected,
                onChanged: locked
                    ? null
                    : (value) => onSelected(value == true),
              ),
              _CatalogProductImage(
                value: product.foto,
                palette: palette,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.nombre,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.success.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: palette.success.withOpacity(.30),
                              ),
                            ),
                            child: Text(
                              'Ya agregado',
                              style: TextStyle(
                                color: palette.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _CatalogChip(
                          text: product.tipoProducto,
                          palette: palette,
                        ),
                        _CatalogChip(
                          text: product.marca,
                          palette: palette,
                        ),
                        _CatalogChip(
                          text:
                              'Compra ${_money(product.precioCompra)}',
                          palette: palette,
                        ),
                        _CatalogChip(
                          text:
                              'Venta ${_money(product.precioVenta)}',
                          palette: palette,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          if (!selected || locked) return info;

          final priceEditors = Padding(
            padding: EdgeInsets.only(
              left: compact ? 0 : 124,
              top: 9,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: purchaseController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio compra',
                      prefixText: r'$ ',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: saleController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio venta',
                      prefixText: r'$ ',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          );

          return Column(
            children: [
              info,
              priceEditors,
            ],
          );
        },
      ),
    );
  }

  static String _money(double value) {
    return r'
  const _CopyDecision({
    required this.sourceSucursalId,
    required this.items,
  });

  final int sourceSucursalId;
  final List<Map<String, dynamic>> items;
}

class _CopyProductsDialog extends StatefulWidget {
  const _CopyProductsDialog({
    required this.palette,
    required this.sources,
    required this.initialSourceId,
    required this.initialProducts,
    required this.loadProducts,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> sources;
  final int initialSourceId;
  final List<ProductosResponseModel> initialProducts;
  final Future<List<ProductosResponseModel>> Function(int sourceSucursalId) loadProducts;

  @override
  State<_CopyProductsDialog> createState() => _CopyProductsDialogState();
}

class _CopyProductsDialogState extends State<_CopyProductsDialog> {
  late int _sourceId;
  late List<ProductosResponseModel> _products;
  final Map<int, _CopyProductSelection> _selection = <int, _CopyProductSelection>{};
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sourceId = widget.initialSourceId;
    _products = widget.initialProducts;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final visible = _products.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (item.prodNombre ?? '').toLowerCase().contains(q) ||
          (item.prodDescripcion ?? '').toLowerCase().contains(q);
    }).toList(growable: false);

    return AlertDialog(
      title: const Text('Seleccionar productos para la nueva sucursal'),
      content: SizedBox(
        width: 760,
        height: 580,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Sucursal origen',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              items: widget.sources
                  .where((item) => item.sucuId != null)
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.sucuId!,
                      child: Text(item.label()),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null && value != _sourceId) _changeSource(value);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selection.length} producto(s) seleccionado(s)',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() {
                            final allSelected = visible
                                .where((e) => e.prodId != null)
                                .every((e) => _selection.containsKey(e.prodId));
                            if (allSelected) {
                              for (final item in visible) {
                                if (item.prodId != null) _selection.remove(item.prodId);
                              }
                            } else {
                              for (final item in visible) {
                                final id = item.prodId;
                                if (id != null) {
                                  _selection.putIfAbsent(
                                    id,
                                    () => const _CopyProductSelection(
                                      purchase: true,
                                      sale: true,
                                    ),
                                  );
                                }
                              }
                            }
                          }),
                  child: const Text('Seleccionar visibles'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? const Center(child: Text('No hay productos disponibles.'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            final id = item.prodId;
                            if (id == null) return const SizedBox.shrink();
                            final selected = _selection[id];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: selected != null,
                                      title: Text(
                                        item.prodNombre ?? 'Producto $id',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: Text(
                                        'Compra: ${_money(item.precioCompraVigente)} · '
                                        'Venta: ${_money(item.precioVentaVigente)}',
                                      ),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selection[id] = const _CopyProductSelection(
                                              purchase: true,
                                              sale: true,
                                            );
                                          } else {
                                            _selection.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                    if (selected != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 34, bottom: 4),
                                        child: Wrap(
                                          spacing: 16,
                                          children: [
                                            FilterChip(
                                              selected: selected.purchase,
                                              label: const Text('Migrar precio compra'),
                                              onSelected: (value) => setState(() {
                                                _selection[id] = selected.copyWith(purchase: value);
                                              }),
                                            ),
                                            FilterChip(
                                              selected: selected.sale,
                                              label: const Text('Migrar precio venta'),
                                              onSelected: (value) => setState(() {
                                                _selection[id] = selected.copyWith(sale: value);
                                              }),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _selection.isEmpty
              ? null
              : () {
                  final items = _selection.entries
                      .map(
                        (entry) => <String, dynamic>{
                          'prodId': entry.key,
                          'migratePurchasePrice': entry.value.purchase,
                          'migrateSalePrice': entry.value.sale,
                        },
                      )
                      .toList(growable: false);
                  Navigator.pop(
                    context,
                    _CopyDecision(sourceSucursalId: _sourceId, items: items),
                  );
                },
          icon: const Icon(Icons.move_down_rounded),
          label: const Text('Migrar seleccionados'),
        ),
      ],
    );
  }

  Future<void> _changeSource(int value) async {
    setState(() {
      _sourceId = value;
      _selection.clear();
      _loading = true;
    });
    try {
      final products = await widget.loadProducts(value);
      if (!mounted) return;
      setState(() => _products = products);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double? value) {
    if (value == null) return 'sin precio';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _CopyProductSelection {
  const _CopyProductSelection({
    required this.purchase,
    required this.sale,
  });

  final bool purchase;
  final bool sale;

  _CopyProductSelection copyWith({
    bool? purchase,
    bool? sale,
  }) {
    return _CopyProductSelection(
      purchase: purchase ?? this.purchase,
      sale: sale ?? this.sale,
    );
  }
}
 + value.round().toString();
  }
}

class _CatalogChip extends StatelessWidget {
  const _CatalogChip({
    required this.text,
    required this.palette,
  });

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.80),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CatalogProductImage extends StatelessWidget {
  const _CatalogProductImage({
    required this.value,
    required this.palette,
  });

  final String? value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: palette.secondary,
          ),
        );

    final source = value?.trim() ?? '';
    if (source.isEmpty) return fallback();

    if (source.startsWith('data:image/') && source.contains(',')) {
      try {
        final encoded = source.substring(source.indexOf(',') + 1);
        final bytes = base64Decode(encoded);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          source,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    return fallback();
  }
}

class _CopyDecision {
  const _CopyDecision({
    required this.sourceSucursalId,
    required this.items,
  });

  final int sourceSucursalId;
  final List<Map<String, dynamic>> items;
}

class _CopyProductsDialog extends StatefulWidget {
  const _CopyProductsDialog({
    required this.palette,
    required this.sources,
    required this.initialSourceId,
    required this.initialProducts,
    required this.loadProducts,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> sources;
  final int initialSourceId;
  final List<ProductosResponseModel> initialProducts;
  final Future<List<ProductosResponseModel>> Function(int sourceSucursalId) loadProducts;

  @override
  State<_CopyProductsDialog> createState() => _CopyProductsDialogState();
}

class _CopyProductsDialogState extends State<_CopyProductsDialog> {
  late int _sourceId;
  late List<ProductosResponseModel> _products;
  final Map<int, _CopyProductSelection> _selection = <int, _CopyProductSelection>{};
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sourceId = widget.initialSourceId;
    _products = widget.initialProducts;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final visible = _products.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (item.prodNombre ?? '').toLowerCase().contains(q) ||
          (item.prodDescripcion ?? '').toLowerCase().contains(q);
    }).toList(growable: false);

    return AlertDialog(
      title: const Text('Seleccionar productos para la nueva sucursal'),
      content: SizedBox(
        width: 760,
        height: 580,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _sourceId,
              decoration: const InputDecoration(
                labelText: 'Sucursal origen',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              items: widget.sources
                  .where((item) => item.sucuId != null)
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.sucuId!,
                      child: Text(item.label()),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null && value != _sourceId) _changeSource(value);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selection.length} producto(s) seleccionado(s)',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() {
                            final allSelected = visible
                                .where((e) => e.prodId != null)
                                .every((e) => _selection.containsKey(e.prodId));
                            if (allSelected) {
                              for (final item in visible) {
                                if (item.prodId != null) _selection.remove(item.prodId);
                              }
                            } else {
                              for (final item in visible) {
                                final id = item.prodId;
                                if (id != null) {
                                  _selection.putIfAbsent(
                                    id,
                                    () => const _CopyProductSelection(
                                      purchase: true,
                                      sale: true,
                                    ),
                                  );
                                }
                              }
                            }
                          }),
                  child: const Text('Seleccionar visibles'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? const Center(child: Text('No hay productos disponibles.'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            final id = item.prodId;
                            if (id == null) return const SizedBox.shrink();
                            final selected = _selection[id];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: selected != null,
                                      title: Text(
                                        item.prodNombre ?? 'Producto $id',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: Text(
                                        'Compra: ${_money(item.precioCompraVigente)} · '
                                        'Venta: ${_money(item.precioVentaVigente)}',
                                      ),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selection[id] = const _CopyProductSelection(
                                              purchase: true,
                                              sale: true,
                                            );
                                          } else {
                                            _selection.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                    if (selected != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 34, bottom: 4),
                                        child: Wrap(
                                          spacing: 16,
                                          children: [
                                            FilterChip(
                                              selected: selected.purchase,
                                              label: const Text('Migrar precio compra'),
                                              onSelected: (value) => setState(() {
                                                _selection[id] = selected.copyWith(purchase: value);
                                              }),
                                            ),
                                            FilterChip(
                                              selected: selected.sale,
                                              label: const Text('Migrar precio venta'),
                                              onSelected: (value) => setState(() {
                                                _selection[id] = selected.copyWith(sale: value);
                                              }),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _selection.isEmpty
              ? null
              : () {
                  final items = _selection.entries
                      .map(
                        (entry) => <String, dynamic>{
                          'prodId': entry.key,
                          'migratePurchasePrice': entry.value.purchase,
                          'migrateSalePrice': entry.value.sale,
                        },
                      )
                      .toList(growable: false);
                  Navigator.pop(
                    context,
                    _CopyDecision(sourceSucursalId: _sourceId, items: items),
                  );
                },
          icon: const Icon(Icons.move_down_rounded),
          label: const Text('Migrar seleccionados'),
        ),
      ],
    );
  }

  Future<void> _changeSource(int value) async {
    setState(() {
      _sourceId = value;
      _selection.clear();
      _loading = true;
    });
    try {
      final products = await widget.loadProducts(value);
      if (!mounted) return;
      setState(() => _products = products);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double? value) {
    if (value == null) return 'sin precio';
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _CopyProductSelection {
  const _CopyProductSelection({
    required this.purchase,
    required this.sale,
  });

  final bool purchase;
  final bool sale;

  _CopyProductSelection copyWith({
    bool? purchase,
    bool? sale,
  }) {
    return _CopyProductSelection(
      purchase: purchase ?? this.purchase,
      sale: sale ?? this.sale,
    );
  }
}
