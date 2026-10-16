import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/master_catalog_repository.dart';

class MasterCatalogPage extends ConsumerStatefulWidget {
  const MasterCatalogPage({super.key});
  @override
  ConsumerState<MasterCatalogPage> createState() => _MasterCatalogPageState();
}

class _MasterCatalogPageState extends ConsumerState<MasterCatalogPage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _status = 'activos';
  String _category = 'Todas';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await ref.read(masterCatalogRepositoryProvider).list();
      if (mounted) setState(() { _products = rows; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MasterCatalogEditor(product: product),
    );
    if (saved == true) await _load();
  }

  Future<void> _changeStatus(Map<String, dynamic> product) async {
    final active = product['activo'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Inactivar producto' : 'Activar producto'),
        content: Text('El cambio afecta solo el catálogo para nuevas empresas. '
            'No altera productos ya importados. ¿Continuar con ' +
            (product['nombre']?.toString() ?? 'el producto') + '?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(active ? 'Inactivar' : 'Activar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(masterCatalogRepositoryProvider)
          .setActive((product['catalogId'] as num).toInt(), !active);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final categories = _products
        .map((p) => p['tipoProducto']?.toString() ?? '')
        .where((v) => v.isNotEmpty).toSet().toList()..sort();
    final query = _search.toLowerCase().trim();
    final filtered = _products.where((p) {
      if (_status == 'activos' && p['activo'] != true) return false;
      if (_status == 'inactivos' && p['activo'] == true) return false;
      if (_category != 'Todas' && p['tipoProducto'] != _category) return false;
      if (query.isEmpty) return true;
      return [p['nombre'], p['codigo'], p['marca'], p['descripcion'], p['tipoProducto']]
          .join(' ').toLowerCase().contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: palette.panelDecoration(baseRadius: 22, tint: palette.secondary),
            child: Wrap(
              spacing: 16, runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 580 ? 270 : 510,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Catálogo maestro de productos', style: TextStyle(
                      color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                    const SizedBox(height: 5),
                    Text('Configuración exclusiva del administrador del aplicativo. '
                      'Estos son productos de referencia para la puesta en marcha, sin inventario.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  ]),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo producto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: MediaQuery.sizeOf(context).width < 480
                ? MediaQuery.sizeOf(context).width - 28 : 310,
              child: TextField(
                decoration: const InputDecoration(labelText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (text) => setState(() => _search = text),
              )),
            SizedBox(width: 155,
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Estado', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'activos', child: Text('Activos')),
                  DropdownMenuItem(value: 'inactivos', child: Text('Inactivos')),
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'activos'),
              )),
            SizedBox(width: 190,
              child: DropdownButtonFormField<String>(
                value: categories.contains(_category) ? _category : 'Todas',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
                items: [
                  const DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                  for (final category in categories)
                    DropdownMenuItem(value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'Todas'),
              )),
            IconButton(onPressed: _loading ? null : _load, tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 10),
          Text(filtered.length.toString() + ' visibles · ' +
              _products.where((p) => p['activo'] == true).length.toString() + ' activos',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (_loading) const Padding(
            padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null) Column(children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ])
          else if (filtered.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(36),
              child: Text('No hay productos con esos filtros.')))
          else LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100 ? 3
                : constraints.maxWidth >= 690 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final product in filtered)
                SizedBox(width: width,
                  child: _ProductCard(product: product, palette: palette,
                    onEdit: () => _edit(product),
                    onStatus: () => _changeStatus(product))),
            ]);
          }),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.palette,
    required this.onEdit, required this.onStatus});
  final Map<String, dynamic> product;
  final AppPalette palette;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final active = product['activo'] == true;
    final money = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);
    String amount(Object? value) => money.format(num.tryParse(value?.toString() ?? '') ?? 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 19, tint: palette.secondary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ProductPhoto(photo: product['foto']?.toString(), size: 72),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product['nombre']?.toString() ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(product['codigo']?.toString() ?? '', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 11)),
            const SizedBox(height: 6),
            Text(active ? 'Activo' : 'Inactivo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: active ? palette.success : palette.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 10),
        Text((product['tipoProducto']?.toString() ?? '-') + ' · ' +
            (product['marca']?.toString() ?? '-'), maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 7),
        Wrap(spacing: 20, runSpacing: 6, children: [
          _PriceInfo(label: 'Compra', value: amount(product['precioCompra']), palette: palette),
          _PriceInfo(label: 'Venta', value: amount(product['precioVenta']), palette: palette),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Editar'))),
          const SizedBox(width: 6),
          Expanded(child: TextButton.icon(
            onPressed: onStatus,
            icon: Icon(active ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17),
            label: Text(active ? 'Inactivar' : 'Activar'))),
        ]),
      ]),
    );
  }
}

class _PriceInfo extends StatelessWidget {
  const _PriceInfo({required this.label, required this.value, required this.palette});
  final String label;
  final String value;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13,
        color: palette.textPrimary)),
    ]);
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.photo, this.size = 72});
  final String? photo;
  final double size;
  @override
  Widget build(BuildContext context) {
    final value = photo?.trim() ?? '';
    Widget child = const Icon(Icons.inventory_2_outlined, size: 30);
    if (value.startsWith('data:image/') && value.contains(',')) {
      try {
        child = Image.memory(base64Decode(value.substring(value.indexOf(',') + 1)),
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
      } catch (_) {
        child = const Icon(Icons.broken_image_outlined);
      }
    } else if (value.startsWith('https://')) {
      child = Image.network(value, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(13),
      child: SizedBox(width: size, height: size,
        child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(child: child))));
  }
}

class _MasterCatalogEditor extends ConsumerStatefulWidget {
  const _MasterCatalogEditor({this.product});
  final Map<String, dynamic>? product;
  @override
  ConsumerState<_MasterCatalogEditor> createState() => _MasterCatalogEditorState();
}

class _MasterCatalogEditorState extends ConsumerState<_MasterCatalogEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _values;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.product ?? {});
    _values.putIfAbsent('tipoControl', () => 'NORMAL');
    _values.putIfAbsent('unidadBase', () => 'UND');
    _values.putIfAbsent('activo', () => true);
    _values.putIfAbsent('compraPorCantidad', () => false);
    _values.putIfAbsent('aplicaImpuesto', () => false);
  }

  Widget _field(String key, String label, {bool isRequired = false,
      bool numeric = false, int lines = 1, int? maxLength}) {
    return TextFormField(
      initialValue: _values[key]?.toString() ?? '',
      maxLines: lines, maxLength: maxLength,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1 ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: (value) {
        final text = (value ?? '').trim();
        if (isRequired && text.isEmpty) return 'Obligatorio';
        if (numeric && text.isNotEmpty &&
            num.tryParse(text.replaceAll(',', '.')) == null) return 'Número inválido';
        return null;
      },
      onChanged: (value) => _values[key] = value,
    );
  }

  Widget _select(String key, String label, List<String> options) {
    return DropdownButtonFormField<String>(
      value: options.contains(_values[key]) ? _values[key] as String : options.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [for (final option in options)
        DropdownMenuItem(value: option, child: Text(option))],
      onChanged: (value) => setState(() => _values[key] = value),
    );
  }

  Future<void> _image() async {
    final files = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (files == null || files.files.isEmpty) return;
    final file = files.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      setState(() => _error = 'Imagen inválida o mayor a 2 MB.');
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final mime = extension == 'jpg' || extension == 'jpeg'
        ? 'jpeg' : extension == 'webp' ? 'webp' : 'png';
    setState(() {
      _values['foto'] = 'data:image/$mime;base64,' + base64Encode(bytes);
      _error = null;
    });
  }

  num? _num(String key) {
    final raw = _values[key]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return num.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = (_values['nombre']?.toString() ?? '').trim();
    var code = (_values['codigo']?.toString() ?? '').trim().toUpperCase();
    if (code.isEmpty) {
      code = 'CAT_' + name.toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
    }
    final purchase = _num('precioCompra');
    final sale = _num('precioVenta');
    final minimum = _num('stockMinimo') ?? 0;
    final maximum = _num('stockMaximo');
    final quantity = _num('cantidadCompra');
    final tax = _num('porcentajeImpuesto');
    final type = _values['tipoControl']?.toString() ?? 'NORMAL';
    if (!RegExp(r'^[A-Z0-9_-]{2,60}$').hasMatch(code)) {
      setState(() => _error = 'Código inválido. Usa letras, números y guiones (máximo 60).');
      return;
    }
    if (purchase == null || sale == null || purchase < 0 || sale < 0 ||
        (type != 'INSUMO' && sale <= 0) || minimum < 0 ||
        (maximum != null && maximum < minimum) ||
        (_values['compraPorCantidad'] == true && (quantity == null || quantity <= 0)) ||
        (_values['aplicaImpuesto'] == true && (tax == null || tax < 0 || tax > 100))) {
      setState(() => _error = 'Verifica precios, cantidades, inventario e impuestos.');
      return;
    }
    final payload = <String, dynamic>{
      'codigo': code,
      'nombre': name,
      'descripcion': (_values['descripcion']?.toString() ?? '').trim(),
      'tipoProducto': (_values['tipoProducto']?.toString() ?? '').trim(),
      'marca': (_values['marca']?.toString() ?? '').trim(),
      'foto': _values['foto'],
      'precioCompra': purchase,
      'precioVenta': sale,
      'stockMinimo': minimum,
      'stockMaximo': maximum,
      'compraPorCantidad': _values['compraPorCantidad'] == true,
      'cantidadCompra': _values['compraPorCantidad'] == true ? quantity : null,
      'presentacionCompra': _values['compraPorCantidad'] == true
          ? (_values['presentacionCompra']?.toString() ?? '').trim() : null,
      'tipoControl': type,
      'unidadBase': _values['unidadBase'],
      'aplicaImpuesto': _values['aplicaImpuesto'] == true,
      'porcentajeImpuesto': _values['aplicaImpuesto'] == true ? tax : null,
      'orden': _num('orden')?.toInt() ?? 100,
      'activo': _values['activo'] == true,
    };
    setState(() { _saving = true; _error = null; });
    try {
      final repo = ref.read(masterCatalogRepositoryProvider);
      final id = widget.product?['catalogId'];
      if (id is num) {
        await repo.update(id.toInt(), payload);
      } else {
        await repo.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * .88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              Icon(Icons.inventory_2_outlined, color: palette.secondary),
              const SizedBox(width: 9),
              Expanded(child: Text(widget.product == null
                  ? 'Nuevo producto maestro' : 'Editar producto maestro',
                  style: TextStyle(color: palette.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close), tooltip: 'Cerrar'),
            ]),
          ),
          const Divider(height: 1),
          Flexible(child: Form(
            key: _formKey,
            child: ListView(shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                ],
                _field('nombre', 'Nombre del producto', isRequired: true, maxLength: 120),
                const SizedBox(height: 10),
                _field('codigo', 'Código (automático si queda vacío)', maxLength: 60),
                const SizedBox(height: 10),
                _field('descripcion', 'Descripción', lines: 2, maxLength: 400),
                const SizedBox(height: 10),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: 285, child: _field('tipoProducto', 'Categoría', isRequired: true, maxLength: 30)),
                  SizedBox(width: 285, child: _field('marca', 'Marca', isRequired: true, maxLength: 30)),
                  SizedBox(width: 285, child: _select('tipoControl', 'Tipo de control',
                    const ['NORMAL','INSUMO','PREPARADO'])),
                  SizedBox(width: 285, child: _select('unidadBase', 'Unidad base',
                    const ['UND','G','KG','ML','L'])),
                  SizedBox(width: 285, child: _field('precioCompra', 'Precio de compra', numeric: true, isRequired: true)),
                  SizedBox(width: 285, child: _field('precioVenta', 'Precio de venta', numeric: true, isRequired: true)),
                  SizedBox(width: 285, child: _field('stockMinimo', 'Stock mínimo sugerido', numeric: true)),
                  SizedBox(width: 285, child: _field('stockMaximo', 'Stock máximo sugerido', numeric: true)),
                ]),
                SwitchListTile.adaptive(
                  title: const Text('Compra por caja, canasta o paquete'),
                  value: _values['compraPorCantidad'] == true,
                  onChanged: (v) => setState(() => _values['compraPorCantidad'] = v),
                ),
                if (_values['compraPorCantidad'] == true)
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(width: 285, child: _field('cantidadCompra', 'Unidades por compra',
                      numeric: true, isRequired: true)),
                    SizedBox(width: 285, child: _field('presentacionCompra', 'Presentación')),
                  ]),
                SwitchListTile.adaptive(
                  title: const Text('Aplica impuesto'),
                  value: _values['aplicaImpuesto'] == true,
                  onChanged: (v) => setState(() => _values['aplicaImpuesto'] = v),
                ),
                if (_values['aplicaImpuesto'] == true)
                  _field('porcentajeImpuesto', 'Porcentaje de impuesto', numeric: true, isRequired: true),
                const SizedBox(height: 10),
                Text('Fotografía del producto', style: TextStyle(
                  color: palette.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [
                  _ProductPhoto(photo: _values['foto']?.toString(), size: 90),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    OutlinedButton.icon(onPressed: _saving ? null : _image,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Subir imagen')),
                    TextButton(onPressed: _saving ? null
                      : () => setState(() => _values['foto'] = null),
                      child: const Text('Quitar imagen')),
                    Text('PNG/JPG/WebP · máximo 2 MB',
                      style: TextStyle(color: palette.textSecondary, fontSize: 11)),
                  ])),
                ]),
                const SizedBox(height: 10),
                _field('orden', 'Orden de catálogo', numeric: true),
                SwitchListTile.adaptive(
                  title: const Text('Visible en nuevas puestas en marcha'),
                  value: _values['activo'] == true,
                  onChanged: (v) => setState(() => _values['activo'] = v),
                ),
              ],
            ),
          )),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando...' : 'Guardar'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
