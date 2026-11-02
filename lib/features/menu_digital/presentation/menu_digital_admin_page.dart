import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../../core/utils/file_download_helper.dart';
import '../data/menu_digital_api.dart';
import 'widgets/menu_digital_catalog.dart';

class _MenuPalette {
  const _MenuPalette(this.name, this.primary, this.background, this.text, this.card);
  final String name, primary, background, text, card;
}

const _presets = <_MenuPalette>[
  _MenuPalette('Océano', '#20C8C4', '#081B27', '#F8FAFC', '#112D3B'),
  _MenuPalette('Marfil', '#9B6B3F', '#FFF9EE', '#352819', '#F2E7D5'),
  _MenuPalette('Vino', '#E5B46B', '#29111D', '#FFF7ED', '#431E30'),
  _MenuPalette('Bosque', '#D6B979', '#10251D', '#F7F4E9', '#1C382D'),
  _MenuPalette('Lavanda', '#7451BB', '#F8F4FF', '#291F3E', '#EAE0F7'),
  _MenuPalette('Terracota', '#F8A875', '#291C1B', '#FFF4E9', '#45302B'),
];

class MenuDigitalAdminPage extends ConsumerStatefulWidget {
  const MenuDigitalAdminPage({super.key});
  @override
  ConsumerState<MenuDigitalAdminPage> createState() => _MenuDigitalAdminPageState();
}

class _MenuDigitalAdminPageState extends ConsumerState<MenuDigitalAdminPage> {
  final _title = TextEditingController(text: 'Nuestra carta');
  final _description = TextEditingController();
  final _cover = TextEditingController();
  final _search = TextEditingController();
  final _colorControllers = <String, TextEditingController>{
    'primario': TextEditingController(text: _presets.first.primary),
    'fondo': TextEditingController(text: _presets.first.background),
    'texto': TextEditingController(text: _presets.first.text),
    'tarjeta': TextEditingController(text: _presets.first.card),
  };
  List<Map<String, dynamic>> _catalog = [];
  Set<int> _selected = {};
  Map<String, dynamic>? _saved;
  String _layout = 'TIENDA';
  bool _loading = true, _saving = false, _dirty = false;
  String? _error;
  int? _loadedBranch;
  int _generation = 0;
  String _filter = '';
  String? _uploadedCover;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cover.dispose();
    _search.dispose();
    for (final input in _colorControllers.values) { input.dispose(); }
    super.dispose();
  }

  int? _id(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  void _changed() {
    if (mounted) setState(() => _dirty = true);
  }

  void _notify(String text) {
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    final branch = ref.read(branchScopeProvider).activeBranchId;
    final seq = ++_generation;
    if (branch == null) {
      setState(() { _loading = false; _loadedBranch = null;
        _catalog = []; _saved = null; _selected = {};
        _error = 'Selecciona una sucursal para administrar su menú.'; });
      return;
    }
    setState(() {
      _loading = true;
      _loadedBranch = branch;
      _error = null;
      _saved = null;
      _catalog = [];
      _selected = {};
      _dirty = false;
    });
    try {
      final api = ref.read(menuDigitalApiProvider);
      final results = await Future.wait<dynamic>([api.admin(), api.catalogo()]);
      if (!mounted || seq != _generation ||
          branch != ref.read(branchScopeProvider).activeBranchId) return;
      final admin = Map<String, dynamic>.from(results[0] as Map);
      final catalog = (results[1] as List).whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r)).toList();
      _title.text = admin['titulo']?.toString() ?? 'Nuestra carta';
      _description.text = admin['descripcion']?.toString() ?? '';
      _cover.text = (admin['portada'] ?? '').toString().startsWith('data:image/')
          ? '' : admin['portada']?.toString() ?? '';
      _uploadedCover = (admin['portada'] ?? '').toString().startsWith('data:image/')
          ? admin['portada'].toString() : null;
      for (final entry in _colorControllers.entries) {
        final fallback = switch (entry.key) {
          'primario' => _presets.first.primary,
          'fondo' => _presets.first.background,
          'texto' => _presets.first.text,
          _ => _presets.first.card,
        };
        entry.value.text = admin[entry.key]?.toString() ?? fallback;
      }
      _layout = admin['estilo']?.toString() ?? 'TIENDA';
      _saved = admin;
      _catalog = catalog;
      _selected = <int>{
        for (final value in (admin['productos'] as List? ?? []))
          if (_id(value) != null) _id(value)!,
      };
      setState(() { _dirty = false; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted || seq != _generation ||
          branch != ref.read(branchScopeProvider).activeBranchId) return;
      setState(() { _loading = false;
        _error = 'No se pudo cargar el menú. Comprueba el backend y los permisos.'; });
    }
  }

  Map<String, dynamic> _payload() => {
    'sucursalId': ref.read(branchScopeProvider).activeBranchId,
    'titulo': _title.text.trim(),
    'descripcion': _description.text.trim(),
    'portada': _uploadedCover ?? _cover.text.trim(),
    'estilo': _layout,
    for (final entry in _colorControllers.entries)
      entry.key: entry.value.text.trim(),
    'productos': [
      for (final item in _catalog)
        if (_selected.contains(_id(item['id']))) _id(item['id']),
    ],
  };

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _notify('Escribe el nombre de tu carta.'); return;
    }
    if (_selected.isEmpty) {
      _notify('Selecciona por lo menos un producto para la carta.'); return;
    }
    final values = _payload();
    final badColor = _colorControllers.values.any(
      (c) => !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(c.text.trim()));
    if (badColor) { _notify('Utiliza colores HEX como #14B8A6.'); return; }
    setState(() => _saving = true);
    try {
      final result = await ref.read(menuDigitalApiProvider).guardar(values);
      if (!mounted) return;
      setState(() {
        _saved = result;
        _dirty = false;
      });
      _notify('Menú digital guardado correctamente.');
    } catch (e) {
      _notify('No se pudo guardar el menú: ' + e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish(bool enabled) async {
    if (_dirty || _saved?['existe'] != true) {
      _notify('Guarda primero los cambios del menú.'); return;
    }
    if (enabled && _selected.isEmpty) {
      _notify('Selecciona productos antes de publicar.'); return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(menuDigitalApiProvider).publicar(enabled);
      if (!mounted) return;
      setState(() => _saved = saved);
      _notify(enabled ? 'Tu carta ya está publicada para tus clientes.'
          : 'Carta oculta: el enlace público ya no es accesible.');
    } catch (e) {
      _notify('No se pudo cambiar la publicación: ' + e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preset(_MenuPalette p) {
    _colorControllers['primario']!.text = p.primary;
    _colorControllers['fondo']!.text = p.background;
    _colorControllers['texto']!.text = p.text;
    _colorControllers['tarjeta']!.text = p.card;
    _changed();
  }

  Future<void> _pickCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 1500000) {
        _notify('Usa una imagen de hasta 1,5 MB.'); return;
      }
      final extension = file.extension?.toLowerCase() ?? '';
      final mime = extension == 'png' ? 'image/png'
          : extension == 'webp' ? 'image/webp' : 'image/jpeg';
      setState(() {
        _uploadedCover = 'data:' + mime + ';base64,' + base64Encode(bytes);
        _cover.clear();
        _dirty = true;
      });
      _notify('Portada seleccionada. Guarda para publicarla.');
    } catch (e) { _notify('No se pudo seleccionar la imagen: ' + e.toString()); }
  }

  void _removeCover() {
    setState(() { _uploadedCover = null; _cover.clear(); _dirty = true; });
  }

  Future<void> _share() async {
    if (_dirty || _saved?['publicado'] != true) {
      _notify('Guarda y publica la carta antes de compartirla.'); return;
    }
    final link = (_saved?['enlaceCompartir'] ?? '').toString();
    if (!link.startsWith('https://')) {
      _notify('Aún no existe un enlace público.'); return;
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      scrollable: true,
      title: const Text('Comparte tu menú digital'),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tus clientes podrán ver la carta sin iniciar sesión.'),
          const SizedBox(height: 13),
          SelectableText(link),
          const SizedBox(height: 12),
          const Text('También puedes colocar el QR impreso en cada mesa.'),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cerrar')),
        OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(
              'Conoce nuestra carta digital:\n' + link));
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.send_outlined), label: const Text('WhatsApp')),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (dialog.mounted) Navigator.pop(dialog);
            _notify('Enlace copiado.');
          },
          icon: const Icon(Icons.copy_rounded), label: const Text('Copiar enlace')),
      ],
    ));
  }

  Future<void> _downloadQrPng() async {
    if (_dirty || _saved?['publicado'] != true) {
      _notify('Guarda y publica el menú antes de descargar el QR.'); return;
    }
    final slug = (_saved?['slug'] ?? '').toString();
    if (slug.isEmpty) return;
    try {
      final response = await ref.read(menuDigitalApiProvider).dio.get<List<int>>(
        '/api/v1/menu-digital/public/' + Uri.encodeComponent(slug) + '/qr',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) throw StateError('El QR no contiene datos.');
      final ok = await downloadBytesFile(
        fileName: 'menu-digital-qr.png', bytes: Uint8List.fromList(bytes),
        mimeType: 'image/png');
      if (ok) _notify('QR descargado en PNG. Puedes imprimirlo en las mesas.');
    } catch (e) { _notify('No fue posible descargar el PNG: ' + e.toString()); }
  }

  Future<void> _downloadQr() async {
    if (_dirty || _saved?['publicado'] != true) {
      _notify('Guarda y publica el menú antes de descargar su QR.'); return;
    }
    final link = (_saved?['enlaceCompartir'] ?? '').toString();
    if (!link.startsWith('https://')) return;
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Center(child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text('MENU DIGITAL', style: pw.TextStyle(fontSize: 21,
              fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Text(_title.text.trim(), textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 17)),
          pw.SizedBox(height: 23),
          pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: link,
              width: 240, height: 240, drawText: false),
          pw.SizedBox(height: 20),
          pw.Text('Escanea el QR para conocer nuestra carta.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Text(link, textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 20),
          pw.Text('Creado con BarLytics', style: const pw.TextStyle(fontSize: 9)),
        ])),
      ));
      final ok = await downloadBytesFile(
        fileName: 'menu-digital-qr.pdf',
        bytes: await pdf.save(),
        mimeType: 'application/pdf',
      );
      if (ok) _notify('Código QR descargado. Ya puedes imprimirlo o compartirlo.');
    } catch (e) {
      _notify('No se pudo descargar el QR: ' + e.toString());
    }
  }

  Widget _panel(AppPalette pal, Widget child) => Container(
    padding: pal.panelPadding(18),
    decoration: pal.panelDecoration(baseRadius: 22),
    child: child,
  );

  Widget _fieldColor(AppPalette pal, String name, String key) {
    final controller = _colorControllers[key]!;
    final color = _parseColor(controller.text);
    return Row(children: [
      Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 9),
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: color ?? pal.secondary, border: Border.all(color: pal.cardBorder, width: 2))),
      Expanded(child: TextField(
        controller: controller, maxLength: 7,
        decoration: InputDecoration(labelText: name, counterText: '',
          hintText: '#14B8A6', isDense: true),
        onChanged: (_) => _changed(),
      )),
    ]);
  }

  Map<String, dynamic> _preview() {
    final selectedProducts = <Map<String, dynamic>>[
      for (final item in _catalog)
        if (_selected.contains(_id(item['id']))) item,
    ].take(6).toList();
    return {
      'titulo': _title.text.trim().isEmpty ? 'Nuestra carta' : _title.text.trim(),
      'descripcion': _description.text,
      'portada': _uploadedCover ?? _cover.text.trim(),
      'estilo': _layout,
      'sucursal': ref.read(branchScopeProvider).activeBranch?.sucuNombre ?? '',
      for (final entry in _colorControllers.entries) entry.key: entry.value.text.trim(),
      'productos': selectedProducts,
    };
  }

  Widget _editor(AppPalette pal) {
    final visible = _catalog.where((p) =>
        (p['nombre'] ?? '').toString().toLowerCase()
            .contains(_filter.trim().toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _panel(pal, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.edit_note_rounded, color: pal.secondary),
          const SizedBox(width: 9),
          Expanded(child: Text('Identidad de tu carta',
              style: TextStyle(color: pal.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _title, maxLength: 120,
          decoration: const InputDecoration(labelText: 'Nombre del menú *',
              prefixIcon: Icon(Icons.restaurant_menu_rounded)),
          onChanged: (_) => _changed()),
        const SizedBox(height: 10),
        TextField(controller: _description, maxLength: 1000, maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Descripción', alignLabelWithHint: true),
          onChanged: (_) => _changed()),
        const SizedBox(height: 15),
        Text('PORTADA', style: TextStyle(color: pal.secondary,
            fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Subir imagen')),
          if (_uploadedCover != null || _cover.text.isNotEmpty)
            TextButton.icon(onPressed: _removeCover,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Quitar portada')),
        ]),
        const SizedBox(height: 7),
        if (_uploadedCover == null)
          TextField(controller: _cover, maxLines: 1,
            decoration: const InputDecoration(
              labelText: 'O pega una URL HTTPS de imagen',
              prefixIcon: Icon(Icons.link_rounded)),
            onChanged: (_) => _changed()),
        const SizedBox(height: 7),
        Text('JPG, PNG o WEBP hasta 1,5 MB. La portada aparece también al compartir.',
            style: TextStyle(color: pal.textSecondary, fontSize: 12)),
      ])),
      const SizedBox(height: 13),
      _panel(pal, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Presentación', style: TextStyle(
            color: pal.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Elige cómo verán tus clientes los productos.',
            style: TextStyle(color: pal.textSecondary)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'TIENDA', label: Text('Tienda'),
                icon: Icon(Icons.storefront_outlined)),
            ButtonSegment(value: 'LIBRO', label: Text('Libro'),
                icon: Icon(Icons.auto_stories_rounded)),
          ],
          selected: {_layout},
          onSelectionChanged: (values) {
            setState(() { _layout = values.first; _dirty = true; });
          }),
      ])),
      const SizedBox(height: 13),
      _panel(pal, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Paleta de colores', style: TextStyle(
            color: pal.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text('Selecciona un estilo o combina tus propios colores HEX.',
            style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 13),
        Wrap(spacing: 8, runSpacing: 9, children: [
          for (final p in _presets)
            ActionChip(
              avatar: CircleAvatar(backgroundColor: _parseColor(p.primary) ?? pal.secondary,
                radius: 12),
              label: Text(p.name), onPressed: () => _preset(p)),
        ]),
        const SizedBox(height: 16),
        for (final row in <(String, String)>[
          ('Color principal', 'primario'),
          ('Fondo', 'fondo'),
          ('Texto', 'texto'),
          ('Tarjetas', 'tarjeta'),
        ]) ...[
          _fieldColor(pal, row.$1, row.$2),
          const SizedBox(height: 9),
        ],
      ])),
      const SizedBox(height: 13),
      _panel(pal, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Productos de la carta',
            style: TextStyle(color: pal.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w900))),
          Text(_selected.length.toString() + ' seleccionados',
            style: TextStyle(color: pal.secondary, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        Text('Usa productos activos del catálogo real de esta sucursal.',
            style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 13),
        TextField(controller: _search,
          decoration: const InputDecoration(
            labelText: 'Buscar productos', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (value) => setState(() => _filter = value)),
        const SizedBox(height: 11),
        Wrap(spacing: 8, children: [
          TextButton.icon(
            onPressed: () {
              final ids = visible.map((p) => _id(p['id'])).whereType<int>();
              if ({..._selected, ...ids}.length > 200) {
                _notify('La carta permite máximo 200 productos. Ajusta los filtros.');
                return;
              }
              setState(() { _selected.addAll(ids); _dirty = true; });
            },
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Seleccionar visibles')),
          TextButton.icon(
            onPressed: () => setState(() { _selected.clear(); _dirty = true; }),
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Limpiar')),
        ]),
        if (_catalog.isEmpty)
          Padding(padding: const EdgeInsets.all(14),
            child: Text('No hay productos con precio vigente. Agrégalos desde Productos.',
              style: TextStyle(color: pal.textSecondary))),
        SizedBox(height: 330, child: ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final item = visible[index];
            final id = _id(item['id']);
            return CheckboxListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              value: id != null && _selected.contains(id),
              onChanged: (checked) {
                if (id == null) return;
                if (checked == true && !_selected.contains(id) && _selected.length >= 200) {
                  _notify('La carta permite máximo 200 productos.'); return;
                }
                setState(() {
                  if (checked == true) { _selected.add(id); } else { _selected.remove(id); }
                  _dirty = true;
                });
              },
              title: Text((item['nombre'] ?? '').toString(),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text((item['tipo'] ?? 'Sin categoría').toString()),
              secondary: Icon(Icons.local_dining_outlined, color: pal.secondary),
            );
          },
        )),
      ])),
    ]);
  }

  Color? _parseColor(String value) {
    if (!RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value.trim())) return null;
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branch = ref.watch(branchScopeProvider).activeBranchId;
    ref.listen<int?>(
      branchScopeProvider.select((state) => state.activeBranchId),
      (previous, next) {
        if (previous != next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load();
          });
        }
      },
    );
    if (branch != _loadedBranch && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    return Scaffold(backgroundColor: Colors.transparent,
      body: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < 900;
        return RefreshIndicator(onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
            children: [
              Container(
                padding: EdgeInsets.all(mobile ? 18 : 26),
                decoration: BoxDecoration(
                  gradient: palette.mainGradient,
                  borderRadius: BorderRadius.circular(palette.radius(24))),
                child: Row(children: [
                  Icon(Icons.menu_book_rounded, size: 37, color: palette.onPrimary),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TU CARTA, TU ESTILO', style: TextStyle(
                      color: palette.onPrimary.withOpacity(0.82),
                      fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Menú digital',
                        style: TextStyle(color: palette.onPrimary,
                          fontSize: mobile ? 24 : 30, fontWeight: FontWeight.w900)),
                    Text('Diseña, publica y comparte tu carta con tus clientes.',
                        style: TextStyle(color: palette.onPrimary)),
                  ])),
                ]),
              ),
              const SizedBox(height: 15),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                _panel(palette, Row(children: [
                  Icon(Icons.error_outline_rounded, color: palette.danger),
                  const SizedBox(width: 11),
                  Expanded(child: Text(_error!)),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ])),
              if (!_loading && _error == null) ...[
                _panel(palette, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton.icon(onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Guardando...' : 'Guardar cambios')),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _publish(_saved?['publicado'] != true),
                      icon: Icon(_saved?['publicado'] == true
                          ? Icons.visibility_off_outlined : Icons.public_rounded),
                      label: Text(_saved?['publicado'] == true ? 'Ocultar carta' : 'Publicar carta')),
                    OutlinedButton.icon(onPressed: _saved?['publicado'] == true ? _share : null,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir')),
                    FilledButton.tonalIcon(onPressed: _saved?['publicado'] == true ? _downloadQrPng : null,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Descargar QR PNG')),
                    OutlinedButton.icon(onPressed: _saved?['publicado'] == true ? _downloadQr : null,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Descargar QR PDF')),
                    if (_saved?['publicado'] == true)
                      TextButton.icon(
                        onPressed: () => context.go('/carta/' + (_saved?['slug'] ?? '').toString()),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Ver como cliente')),
                  ]),
                  const SizedBox(height: 9),
                  Text(_dirty
                    ? 'Tienes cambios sin guardar. Guarda antes de compartir o publicar.'
                    : _saved?['publicado'] == true
                      ? 'Publicada: los clientes pueden escanear su QR o abrir el enlace.'
                      : 'En borrador: nadie puede consultar el enlace público.',
                    style: TextStyle(color: _dirty ? palette.warning
                        : palette.textSecondary, fontSize: 12)),
                ])),
                const SizedBox(height: 15),
                if (mobile) ...[
                  _editor(palette),
                  const SizedBox(height: 18),
                  Text('Vista previa en tiempo real', style: TextStyle(
                    color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  MenuDigitalCatalog(menu: _preview(), preview: true),
                ] else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 6, child: _editor(palette)),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Vista previa en tiempo real', style: TextStyle(
                          color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        MenuDigitalCatalog(menu: _preview(), preview: true),
                      ])),
                  ]),
              ],
            ],
          ),
        );
      }),
    );
  }
}
