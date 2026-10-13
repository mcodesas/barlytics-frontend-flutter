import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
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
                        'Selecciona productos de otra sucursal o carga los que faltan usando la plantilla Excel de BarLytics.',
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
                OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar plantilla Excel'),
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

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(productosSetupRemoteDataSourceProvider).downloadTemplate();
      await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar plantilla de productos',
        fileName: 'plantilla_productos_barlytics.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      if (!mounted) return;
      _message('Plantilla generada. Complétala y luego usa “Subir productos desde Excel”.');
    } catch (error) {
      if (mounted) _message('No fue posible descargar la plantilla: $error', error: true);
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
