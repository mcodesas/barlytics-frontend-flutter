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
import 'widgets/menu_digital_palette.dart';

const _presets = menuDigitalPalettePresets;

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
  final _paletasKey = GlobalKey();
  String _filtroPaletas = 'TODAS';
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
  String? _customLogo;
  String? _backgroundPhoto;
  List<String> _gallery = [];
  String _coverMode = 'COMPLETA';
  bool _galleryOnTop = false;

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
      _customLogo = (admin['logoPersonalizado'] ?? '').toString().trim();
      _backgroundPhoto = (admin['fondoImagen'] ?? '').toString().trim();
      _gallery = (admin['galeria'] as List? ?? const [])
          .whereType<String>().toList();
      _coverMode = admin['portadaModo'] == 'DIVIDIDA' ? 'DIVIDIDA' : 'COMPLETA';
      _galleryOnTop = admin['galeriaArriba'] == true;
      for (final entry in _colorControllers.entries) {
        final fallback = switch (entry.key) {
          'primario' => _presets.first.primary,
          'fondo' => _presets.first.background,
          'texto' => _presets.first.text,
          _ => _presets.first.card,
        };
        entry.value.text = admin[entry.key]?.toString() ?? fallback;
      }
      final design = (admin['estilo'] ?? 'TIENDA').toString().toUpperCase();
      _layout = const <String>{
        'TIENDA', 'LIBRO', 'EDITORIAL', 'GALERIA', 'MINIMALISTA',
      }.contains(design) ? design : 'TIENDA';
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
    'logo': _customLogo ?? '',
    'fondoImagen': _backgroundPhoto ?? '',
    'galeria': List<String>.from(_gallery),
    'portadaModo': _coverMode,
    'galeriaArriba': _galleryOnTop,
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
    if (!_hasReadableColors) {
      _notify('El texto tiene poco contraste con el fondo o las tarjetas. '
          'Elige otra combinación para que todos puedan leer la carta.');
      return;
    }
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

  void _mostrarPaletas() {
    final target = _paletasKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.04,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  bool _paletaClara(MenuDigitalPalettePreset preset) =>
      MenuDigitalColors.parse(preset.background, '#FFFFFF')
          .computeLuminance() > 0.35;

  void _preset(MenuDigitalPalettePreset p) {
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

  ImageProvider? _visualImage(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      if (source.startsWith('data:image/') && source.contains(',')) {
        return MemoryImage(base64Decode(source.substring(source.indexOf(',') + 1)));
      }
      if (source.startsWith('https://')) return NetworkImage(source);
    } catch (_) {}
    return null;
  }

  Widget _visualPreview(String? source, {double width = 100, double height = 76}) {
    final image = _visualImage(source);
    return Container(
      width: width, height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _parseColor(_colorControllers['tarjeta']!.text) ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12)),
      child: image == null
          ? const Icon(Icons.add_photo_alternate_outlined)
          : Image(image: image, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
    );
  }

  Future<void> _pickVisual(String target) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final limit = target == 'logo' ? 900000 : 1500000;
      if (file.bytes == null || file.bytes!.isEmpty || file.bytes!.length > limit) {
        _notify('Imagen demasiado grande. Logo máximo 900 KB; fondo máximo 1,5 MB.');
        return;
      }
      final ext = file.extension?.toLowerCase() ?? '';
      final mime = ext == 'png' ? 'image/png' :
          ext == 'webp' ? 'image/webp' : 'image/jpeg';
      final encoded = 'data:$mime;base64,${base64Encode(file.bytes!)}';
      if (!mounted) return;
      setState(() {
        if (target == 'logo') {
          _customLogo = encoded;
        } else {
          _backgroundPhoto = encoded;
        }
        _dirty = true;
      });
    } catch (e) {
      _notify('No fue posible cargar la imagen: $e');
    }
  }

  Future<void> _pickGallery() async {
    if (_gallery.length >= 6) {
      _notify('La galería permite máximo 6 fotografías.'); return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final added = <String>[];
      for (final file in result.files) {
        if (_gallery.length + added.length >= 6) break;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty || bytes.length > 700000) {
          _notify('Algunas fotografías superan 700 KB y se omitieron.');
          continue;
        }
        final ext = file.extension?.toLowerCase() ?? '';
        final mime = ext == 'png' ? 'image/png' :
            ext == 'webp' ? 'image/webp' : 'image/jpeg';
        added.add('data:$mime;base64,${base64Encode(bytes)}');
      }
      if (mounted && added.isNotEmpty) {
        setState(() {
          _gallery = [..._gallery, ...added];
          _dirty = true;
        });
      }
    } catch (e) {
      _notify('No fue posible cargar la galería: $e');
    }
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
    final colors = MenuDigitalColors.fromMenu(_preview());
    final linkColor = MenuDigitalColors.contrast(colors.accent, colors.card) >= 4.5
        ? colors.accent : colors.text;
    final slug = (_saved?['slug'] ?? '').toString();
    final qrPreview = ref.read(menuDigitalApiProvider).server +
        '/api/v1/menu-digital/public/' + Uri.encodeComponent(slug) + '/qr';
    await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      scrollable: true,
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      title: Text('Comparte tu menú digital', style: TextStyle(color: colors.text)),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tus clientes podrán ver la carta sin iniciar sesión.',
            style: TextStyle(color: colors.text)),
          const SizedBox(height: 15),
          Center(child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16)),
            child: Image.network(qrPreview, width: 180, height: 180,
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 180, height: 180,
                child: Center(child: Text('Descarga el QR para verlo')))),
          )),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border)),
            child: SelectableText(link, style: TextStyle(
              color: MenuDigitalColors.contrast(linkColor, colors.canvas) >= 4.5
                  ? linkColor : colors.text, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Text('También puedes colocar el QR impreso en cada mesa.',
            style: TextStyle(color: colors.text)),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog),
          style: TextButton.styleFrom(foregroundColor: linkColor),
          child: const Text('Cerrar')),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: linkColor,
            side: BorderSide(color: colors.border)),
          onPressed: () async {
            final uri = Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(
              'Conoce nuestra carta digital:\n' + link));
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.send_outlined), label: const Text('WhatsApp')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: colors.accent,
            foregroundColor: colors.onAccent),
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

  /// Muestra la combinación de cuatro tonos y sus HEX, no solo un círculo.
  Widget _paletteChoice(MenuDigitalPalettePreset preset, AppPalette pal) {
    final selected =
        _colorControllers['primario']!.text.toUpperCase() == preset.primary &&
        _colorControllers['fondo']!.text.toUpperCase() == preset.background &&
        _colorControllers['texto']!.text.toUpperCase() == preset.text &&
        _colorControllers['tarjeta']!.text.toUpperCase() == preset.card;
    return InkWell(
      onTap: () => _preset(preset),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 162,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? pal.secondary.withOpacity(.13)
              : pal.textPrimary.withOpacity(.035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? pal.secondary : pal.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(preset.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w800))),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 16, color: pal.secondary),
          ]),
          const SizedBox(height: 8),
          Container(
            height: 58,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _parseColor(preset.background),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _parseColor(preset.text)!.withOpacity(.22)),
            ),
            child: Row(children: [
              Container(width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _parseColor(preset.primary),
                  borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 6),
              Text('Aa', style: TextStyle(
                color: _parseColor(preset.text),
                fontSize: 13, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: _parseColor(preset.card),
                  borderRadius: BorderRadius.circular(7)),
                child: Text('Carta', style: TextStyle(
                  color: _parseColor(preset.text),
                  fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final hex in <String>[
              preset.primary, preset.background, preset.text, preset.card,
            ]) ...[
              Expanded(child: Container(height: 13,
                decoration: BoxDecoration(
                  color: _parseColor(hex),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: pal.cardBorder),
                ),
              )),
              const SizedBox(width: 4),
            ],
          ]),
          const SizedBox(height: 5),
          Text(preset.primary + ' · ' + preset.background,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: pal.textSecondary, fontSize: 10)),
        ]),
      ),
    );
  }


  Widget _designThumbnail(MenuDigitalColors colors, String style) {
    final fg = colors.text;
    final ac = colors.accent;
    Widget line({double width = 40, double height = 5, Color? color}) =>
        Container(width: width, height: height, decoration: BoxDecoration(
          color: color ?? fg.withOpacity(.6),
          borderRadius: BorderRadius.circular(3)));
    Widget photo() => Container(
      decoration: BoxDecoration(color: colors.secondarySurface,
        borderRadius: BorderRadius.circular(6)),
      child: Center(child: Icon(Icons.image_outlined,
        color: fg.withOpacity(.65), size: 20)));
    Widget paper() => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: colors.card,
        borderRadius: BorderRadius.circular(7)),
      child: Column(children: [
        line(width: 52, height: 7, color: ac),
        const Spacer(),
        for (var i = 0; i < 3; i++) ...[
          Row(children: [
            Expanded(child: Container(height: 4,
              color: fg.withOpacity(.4))),
            const SizedBox(width: 6),
            line(width: 20, color: ac),
          ]),
          const SizedBox(height: 6),
        ],
        const Spacer(),
      ]),
    );
    switch (style) {
      case 'LIBRO':
        return Row(children: [
          Expanded(child: paper()),
          const SizedBox(width: 6),
          Expanded(child: paper()),
        ]);
      case 'EDITORIAL':
        return Container(
          padding: const EdgeInsets.all(12), color: colors.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            line(width: 110, height: 12, color: fg),
            const SizedBox(height: 8),
            Container(height: 1, color: ac),
            const Spacer(),
            for (var i = 0; i < 2; i++) ...[
              Row(children: [
                Expanded(child: Container(height: 5,
                  color: fg.withOpacity(.5))),
                const SizedBox(width: 12),
                line(width: 38, height: 7, color: ac),
              ]),
              const SizedBox(height: 8),
            ],
            const Spacer(),
          ]),
        );
      case 'GALERIA':
        return Row(children: [
          Expanded(flex: 3, child: photo()),
          const SizedBox(width: 7),
          Expanded(flex: 2, child: Column(children: [
            Expanded(child: photo()),
            const SizedBox(height: 7),
            Expanded(child: photo()),
          ])),
        ]);
      case 'MINIMALISTA':
        return Container(
          padding: const EdgeInsets.all(12), color: colors.card,
          child: Column(children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: Row(children: [
                Icon(Icons.circle, color: ac, size: 6),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 5,
                  color: fg.withOpacity(.55))),
                const SizedBox(width: 11),
                line(width: 35, height: 7, color: ac),
              ])),
          ]),
        );
      default:
        return Row(children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: colors.card,
                borderRadius: BorderRadius.circular(7)),
              child: Column(children: [
                Expanded(child: photo()),
                const SizedBox(height: 6),
                line(width: 64),
                const SizedBox(height: 5),
                line(width: 42, height: 8, color: ac),
              ]),
            )),
            if (i == 0) const SizedBox(width: 8),
          ],
        ]);
    }
  }

  Widget _designOption(AppPalette pal, MenuDigitalColors colors,
      String style, double width) {
    final selected = _layout == style;
    final title = switch (style) {
      'LIBRO' => 'Carta tipo libro',
      'EDITORIAL' => 'Editorial elegante',
      'GALERIA' => 'Galería fotográfica',
      'MINIMALISTA' => 'Minimalista',
      _ => 'Moderno',
    };
    final description = switch (style) {
      'LIBRO' => 'Hojas por categoría, como una carta impresa.',
      'EDITORIAL' => 'Tipografía protagonista y productos refinados.',
      'GALERIA' => 'Fotografías grandes para destacar tus productos.',
      'MINIMALISTA' => 'Lista limpia y fácil de explorar.',
      _ => 'Tarjetas modernas con fotos y precios.',
    };
    final icon = switch (style) {
      'LIBRO' => Icons.auto_stories_rounded,
      'EDITORIAL' => Icons.article_outlined,
      'GALERIA' => Icons.photo_library_outlined,
      'MINIMALISTA' => Icons.view_list_outlined,
      _ => Icons.dashboard_customize_rounded,
    };
    return Semantics(
      button: true, selected: selected, label: 'Elegir diseño $title',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() {
          _layout = style;
          _dirty = true;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? pal.secondary.withOpacity(.12) : pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected
                ? pal.secondary : pal.cardBorder, width: selected ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: pal.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(title,
                style: TextStyle(color: pal.textPrimary,
                  fontWeight: FontWeight.w900))),
              Icon(selected ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
                  color: selected ? pal.secondary : pal.textSecondary),
            ]),
            const SizedBox(height: 7),
            Text(description, maxLines: 3,
              style: TextStyle(color: pal.textSecondary,
                fontSize: 11.5, height: 1.3)),
            const SizedBox(height: 10),
            Container(
              height: 128,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: colors.canvas,
                borderRadius: BorderRadius.circular(12)),
              child: ClipRect(child: _designThumbnail(colors, style)),
            ),
            const SizedBox(height: 9),
            Text(selected ? 'DISEÑO SELECCIONADO' : 'Seleccionar este diseño',
              style: TextStyle(
                color: selected ? pal.secondary : pal.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

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
      'logo': (_customLogo?.isNotEmpty ?? false)
          ? _customLogo : _saved?['logoSucursal'],
      'fondoImagen': _backgroundPhoto ?? '',
      'galeria': List<String>.from(_gallery),
      'portadaModo': _coverMode,
      'galeriaArriba': _galleryOnTop,
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
        const SizedBox(height: 12),
        if ((_uploadedCover ?? _cover.text).isNotEmpty)
          _visualPreview(_uploadedCover ?? _cover.text, height: 145,
              width: double.infinity),
        const SizedBox(height: 16),
        Text('CÓMO MOSTRAR LA PORTADA',
          style: TextStyle(color: pal.secondary, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 9),
        Wrap(spacing: 9, runSpacing: 9, children: [
          ChoiceChip(
            label: const Text('Foto completa arriba'),
            avatar: const Icon(Icons.wallpaper_outlined, size: 19),
            selected: _coverMode == 'COMPLETA',
            onSelected: (_) => setState(() {
              _coverMode = 'COMPLETA'; _dirty = true;
            })),
          ChoiceChip(
            label: const Text('Encabezado dividido clásico'),
            avatar: const Icon(Icons.view_week_outlined, size: 19),
            selected: _coverMode == 'DIVIDIDA',
            onSelected: (_) => setState(() {
              _coverMode = 'DIVIDIDA';
              _galleryOnTop = false; // El carrusel requiere portada completa.
              _dirty = true;
            })),
        ]),
        const SizedBox(height: 7),
        Text('La foto completa evita recortes y deja el logo y los datos del negocio debajo. '
             'El encabezado dividido conserva la presentación anterior.',
          style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 22),
        Text('LOGO DEL NEGOCIO',
          style: TextStyle(color: pal.secondary, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        Text('Por defecto se utiliza el logo o fotografía configurada '
             'en la sucursal. Puedes reemplazarlo solo en esta carta.',
          style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 9),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12, runSpacing: 10, children: [
          _visualPreview((_customLogo?.isNotEmpty ?? false)
              ? _customLogo : _saved?['logoSucursal']?.toString(),
              width: 94, height: 90),
          OutlinedButton.icon(
            onPressed: () => _pickVisual('logo'),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Cambiar logo')),
          if (_customLogo?.isNotEmpty == true)
            TextButton.icon(
              onPressed: () => setState(() {
                _customLogo = '';
                _dirty = true;
              }),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Usar logo de sucursal')),
        ]),
        const SizedBox(height: 22),
        Text('FOTOGRAFÍA DE FONDO',
          style: TextStyle(color: pal.secondary, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        Text('Opcional. Aparece suavemente detrás del contenido de la carta '
             'y se combina con los colores de la paleta para facilitar la lectura.',
          style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 9),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12, runSpacing: 10, children: [
          _visualPreview(_backgroundPhoto, width: 140, height: 90),
          OutlinedButton.icon(
            onPressed: () => _pickVisual('fondo'),
            icon: const Icon(Icons.wallpaper_outlined),
            label: const Text('Subir imagen de fondo')),
          if (_backgroundPhoto?.isNotEmpty == true)
            TextButton.icon(
              onPressed: () => setState(() {
                _backgroundPhoto = '';
                _dirty = true;
              }),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar fondo')),
        ]),
        const SizedBox(height: 22),
        Text('GALERÍA DEL NEGOCIO',
          style: TextStyle(color: pal.secondary, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        Text('Hasta 6 fotografías adicionales. Los clientes podrán abrirlas '
             'en tamaño completo y hacer zoom. Máximo 700 KB por foto.',
          style: TextStyle(color: pal.textSecondary, fontSize: 12)),
        const SizedBox(height: 9),
        CheckboxListTile(
          value: _galleryOnTop,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Mostrar estas fotos también arriba'),
          subtitle: const Text('Crea un carrusel en la portada con la foto '
              'principal y las fotos de la galería, sin recortar imágenes.'),
          onChanged: (enabled) => setState(() {
            _galleryOnTop = enabled ?? false;
            if (_galleryOnTop) _coverMode = 'COMPLETA';
            _dirty = true;
          }),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 9, runSpacing: 9, children: [
          for (var index = 0; index < _gallery.length; index++)
            Stack(children: [
              _visualPreview(_gallery[index], width: 114, height: 99),
              Positioned(
                right: 1, top: 1,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Eliminar fotografía ${index + 1}',
                  icon: const Icon(Icons.close_rounded, size: 17),
                  onPressed: () => setState(() {
                    _gallery.removeAt(index);
                    _dirty = true;
                  }),
                )),
            ]),
          if (_gallery.length < 6)
            OutlinedButton.icon(
              onPressed: _pickGallery,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Agregar fotos (${_gallery.length}/6)')),
        ]),
      ])),
      const SizedBox(height: 13),
      _panel(pal, Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.style_rounded, color: pal.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text('¿Qué diseño quieres para tu carta?',
                style: TextStyle(color: pal.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 7),
          Text('Elige entre cinco diseños. Tus productos, precios y '
              'paletas de colores se conservan al cambiar de diseño.',
              style: TextStyle(color: pal.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, limits) {
            final width = limits.maxWidth < 470
                ? limits.maxWidth : (limits.maxWidth - 12) / 2;
            final colors = MenuDigitalColors.fromMenu(_preview());
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final style in const <String>[
                'TIENDA', 'LIBRO', 'EDITORIAL', 'GALERIA', 'MINIMALISTA',
              ])
                _designOption(pal, colors, style, width),
            ]);
          }),
          const SizedBox(height: 8),
          Text('La vista previa se actualiza inmediatamente. Guarda los '
              'cambios para reflejarlos en tu enlace y código QR.',
              style: TextStyle(color: pal.textSecondary, fontSize: 11)),
        ])),
      const SizedBox(height: 13),
      KeyedSubtree(
        key: _paletasKey,
        child: _panel(pal, Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.palette_rounded, color: pal.secondary, size: 27),
              const SizedBox(width: 10),
              Expanded(child: Text('Diseña los colores de tu carta',
                style: TextStyle(color: pal.textPrimary,
                  fontSize: 19, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: pal.secondary.withOpacity(.15),
                  borderRadius: BorderRadius.circular(14)),
                child: Text('${_presets.length} paletas',
                  style: TextStyle(color: pal.secondary,
                    fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 7),
            Text('Selecciona una combinación completa y comprueba el resultado '
                'en la vista previa. También puedes personalizar cada código HEX.',
              style: TextStyle(color: pal.textSecondary, fontSize: 12)),
            const SizedBox(height: 13),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final filter in const <(String, String)>[
                ('TODAS', 'Todas (32)'),
                ('CLARAS', 'Claras'),
                ('OSCURAS', 'Oscuras'),
              ])
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: _filtroPaletas == filter.$1,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filtroPaletas = filter.$1),
                  selectedColor: pal.secondary,
                  labelStyle: TextStyle(
                    color: _filtroPaletas == filter.$1
                        ? MenuDigitalColors.readableOn(pal.secondary)
                        : pal.textPrimary,
                    fontWeight: FontWeight.w700),
                  side: BorderSide(color: pal.cardBorder),
                ),
            ]),
            const SizedBox(height: 13),
            // Mostrar todas las paletas directamente: antes 26 estaban
            // ocultas dentro de un ExpansionTile y pasaban desapercibidas.
            Wrap(spacing: 9, runSpacing: 9, children: [
              for (final preset in _presets)
                if (_filtroPaletas == 'TODAS' ||
                    (_filtroPaletas == 'CLARAS' && _paletaClara(preset)) ||
                    (_filtroPaletas == 'OSCURAS' && !_paletaClara(preset)))
                  _paletteChoice(preset, pal),
            ]),
        const SizedBox(height: 10),
        if (!_hasReadableColors)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(children: [
              Icon(Icons.contrast_rounded, size: 20, color: pal.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'El texto se confunde con el fondo o las tarjetas. Ajusta los colores.',
                style: TextStyle(color: pal.warning, fontSize: 12))),
            ]),
          ),
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
        ),
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

  double _contrast(Color left, Color right) {
    final a = left.computeLuminance(), b = right.computeLuminance();
    final highest = a > b ? a : b;
    final lowest = a > b ? b : a;
    return (highest + 0.05) / (lowest + 0.05);
  }

  bool get _hasReadableColors {
    final text = _parseColor(_colorControllers['texto']!.text);
    final background = _parseColor(_colorControllers['fondo']!.text);
    final card = _parseColor(_colorControllers['tarjeta']!.text);
    if (text == null || background == null || card == null) return false;
    return _contrast(text, background) >= 4.5 && _contrast(text, card) >= 4.5;
  }

  Color? _parseColor(String value) {
    if (!RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value.trim())) return null;
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final menuColors = MenuDigitalColors.fromMenu(_preview());
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
                      onPressed: _mostrarPaletas,
                      icon: const Icon(Icons.palette_rounded),
                      label: const Text('32 paletas de colores')),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _publish(_saved?['publicado'] != true),
                      icon: Icon(_saved?['publicado'] == true
                          ? Icons.visibility_off_outlined : Icons.public_rounded),
                      label: Text(_saved?['publicado'] == true ? 'Ocultar carta' : 'Publicar carta')),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: menuColors.accent,
                        foregroundColor: menuColors.onAccent,
                        disabledBackgroundColor: palette.cardBorder,
                        disabledForegroundColor: palette.textSecondary,
                        side: BorderSide(color: menuColors.accent),
                      ),
                      onPressed: _saved?['publicado'] == true ? _share : null,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir')),
                    FilledButton.tonalIcon(onPressed: _saved?['publicado'] == true ? _downloadQrPng : null,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Descargar QR PNG')),
                    OutlinedButton.icon(onPressed: _saved?['publicado'] == true ? _downloadQr : null,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Descargar QR PDF')),
                    if (_saved?['publicado'] == true)
                      Container(
                        decoration: BoxDecoration(
                          color: menuColors.card,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: menuColors.border)),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: menuColors.text),
                          onPressed: () => context.go('/carta/' +
                            (_saved?['slug'] ?? '').toString()),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Ver como cliente')),
                      ),
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
