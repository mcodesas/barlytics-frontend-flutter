import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'menu_digital_ordering.dart';

/// Exporta TODA la carta a un PDF imprimible, manteniendo el estilo gráfico
/// seleccionado: portada, logo, paleta, categorías, fotos, precios y orden.
/// El PDF es una adaptación a páginas A4 del diseño público responsivo,
/// no una captura recortada de la vista previa de seis productos.
class MenuDigitalPdfExport {
  MenuDigitalPdfExport._();

  static final _money = NumberFormat.currency(
    locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  static String _value(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static bool _png(Uint8List data) => data.length >= 8 &&
      data[0] == 0x89 && data[1] == 0x50 &&
      data[2] == 0x4E && data[3] == 0x47;

  static bool _jpg(Uint8List data) => data.length >= 3 &&
      data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF;

  /// JPEG/PNG son admitidos directamente por pdf; WEBP se convierte a PNG
  /// mediante los códecs de Flutter (funciona también en CanvasKit).
  static Future<Uint8List?> _pdfImage(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 2500000) return null;
    if (_jpg(bytes) || _png(bytes)) return bytes;
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final converted = await image.toByteData(format: ui.ImageByteFormat.png);
      if (converted == null) return null;
      return Uint8List.fromList(converted.buffer.asUint8List(
        converted.offsetInBytes, converted.lengthInBytes));
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static Future<Uint8List?> _load(String source) async {
    try {
      if (source.startsWith('data:image/') && source.contains(',')) {
        final comma = source.indexOf(',');
        if (source.length > 3400000) return null;
        return base64Decode(source.substring(comma + 1));
      }
      if (source.startsWith('https://')) {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 6),
          maxRedirects: 2,
        ));
        final response = await dio.get<List<int>>(
          source, options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data == null || data.length > 2500000) return null;
        return Uint8List.fromList(data);
      }
    } catch (_) {
      // Una URL de imagen caída no debe impedir descargar toda la carta.
    }
    return null;
  }

  /// loadImage permite pruebas sin red y también inyectar imágenes ya
  /// almacenadas. Las imágenes remotas que no carguen se omiten sin perder
  /// los productos ni sus precios.
  static Future<Uint8List> create({
    required Map<String, dynamic> menu,
    Future<Uint8List?> Function(String)? loadImage,
  }) async {
    final raw = menu['productos'];
    final products = MenuDigitalOrdering.arrange(
      raw is List
          ? raw.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[],
      categoryOrder: (menu['ordenTipos'] as List? ?? const [])
          .whereType<String>().toList(),
    );
    if (products.isEmpty) {
      throw StateError('Selecciona productos antes de exportar la carta.');
    }
    final categories = MenuDigitalOrdering.categories(
        products, (menu['ordenTipos'] as List? ?? const [])
            .whereType<String>().toList());
    final visual = _MenuPdfVisual(_value(menu['estilo'], 'TIENDA'), menu);
    final images = <String, pw.MemoryImage?>{};
    final sources = <String>{};
    for (final field in ['portada', 'logo', 'fondoImagen']) {
      final source = _value(menu[field]);
      if (source.isNotEmpty) sources.add(source);
    }
    // Las fotos son opcionales y el documento puede contener miles de filas.
    // Se acota la precarga de fotos, NO la cantidad de productos exportados.
    for (final product in products) {
      final source = _value(product['imagen']);
      if (source.isNotEmpty && sources.length < 162) sources.add(source);
    }
    final list = sources.toList();
    final loader = loadImage ?? _load;
    for (var i = 0; i < list.length; i += 6) {
      final batch = list.skip(i).take(6);
      await Future.wait(batch.map((source) async {
        try {
          final data = await loader(source);
          final compatible = data == null ? null : await _pdfImage(data);
          images[source] = compatible == null ? null : pw.MemoryImage(compatible);
        } catch (_) {
          images[source] = null;
        }
      }));
    }
    pw.MemoryImage? photo(dynamic source) => images[_value(source)];
    // La foto de fondo se imprime detrás del contenido en todas las hojas.
    final coverPhoto = photo(menu['portada']);
    final wallpaper = photo(menu['fondoImagen']) ??
        (visual.elegant ? coverPhoto : null);
    final title = _value(menu['titulo'], 'Nuestra carta');
    final branch = _value(menu['sucursal']);
    final description = _value(menu['descripcion']);
    final link = _value(menu['url'], _value(menu['enlaceCompartir']));
    final serif = visual.serif ? pw.Font.times() : pw.Font.helvetica();
    final bold = visual.serif ? pw.Font.timesBold() : pw.Font.helveticaBold();
    final document = pw.Document(
      title: title + ' - Carta completa',
      author: branch.isEmpty ? 'BarLytics' : branch,
      creator: 'BarLytics - Menú digital',
    );
    const format = PdfPageFormat.a4;

    if (!visual.elegant) document.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Container(
        color: visual.background,
        width: format.width,
        height: format.height,
        child: pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(46, 43, 46, 40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(children: [
                if (photo(menu['logo']) != null) ...[
                  pw.Container(width: 55, height: 55,
                    child: pw.Image(photo(menu['logo'])!, fit: pw.BoxFit.contain)),
                  pw.SizedBox(width: 15),
                ],
                pw.Expanded(child: pw.Text(
                  branch.isEmpty ? 'CARTA DIGITAL' : branch,
                  style: pw.TextStyle(
                    color: visual.ink, font: bold, fontSize: 18))),
              ]),
              pw.SizedBox(height: 23),
              pw.Container(height: 4, color: visual.accent),
              pw.SizedBox(height: 20),
              if (coverPhoto != null)
                pw.Container(height: 305,
                  child: pw.Image(coverPhoto, fit: pw.BoxFit.cover))
              else
                pw.Container(height: 305,
                  color: visual.card,
                  child: pw.Center(child: pw.Text('NUESTRA SELECCIÓN',
                    style: pw.TextStyle(color: visual.accent, font: bold,
                      fontSize: 23, letterSpacing: 2)))),
              pw.SizedBox(height: 36),
              pw.Text(title, textAlign: pw.TextAlign.center, maxLines: 4,
                style: pw.TextStyle(color: visual.ink, font: bold,
                  fontSize: 34, lineSpacing: 4)),
              pw.SizedBox(height: 18),
              if (description.isNotEmpty)
                pw.Text(
                  description.length > 180
                      ? description.substring(0, 180) + '…' : description,
                  textAlign: pw.TextAlign.center, maxLines: 4,
                  style: pw.TextStyle(color: visual.ink, font: serif,
                    fontSize: 12, lineSpacing: 4)),
              pw.Spacer(),
              pw.Container(height: 2, color: visual.accent),
              pw.SizedBox(height: 14),
              pw.Text('DISEÑO ' + visual.name.toUpperCase() +
                  '  ·  ' + products.length.toString() + ' PRODUCTOS',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(color: visual.ink, font: bold,
                  fontSize: 10, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    ));

    final content = <pw.Widget>[];
    // Elegante comparte la portada, descripción y categorías en el mismo
    // lienzo, igual que el catálogo web: evita una portada PDF adicional.
    if (visual.elegant) {
      content.add(_elegantIntro(
        title: title, branch: branch, description: description,
        visual: visual, logo: photo(menu['logo']),
        regular: serif, bold: bold,
      ));
      content.add(pw.SizedBox(height: 24));
    }
    if (!visual.elegant && description.length > 180) {
      content.add(pw.Padding(padding: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Text(description,
          style: pw.TextStyle(color: visual.ink, font: serif,
            fontSize: 11, lineSpacing: 4))));
    }
    for (final category in categories) {
      final entries = products.where(
        (item) => MenuDigitalOrdering.category(item) == category).toList();
      if (visual.elegant) {
        content.add(pw.SizedBox(height: 18));
        content.add(pw.Inseparable(child: pw.Column(children: [
          _elegantCategoryHeader(category, visual, bold),
          _elegantProduct(entries.first, visual, serif, bold),
        ])));
        for (final product in entries.skip(1)) {
          content.add(_elegantProduct(product, visual, serif, bold));
        }
        content.add(_elegantCategoryFooter(visual));
        continue;
      }
      content.add(pw.SizedBox(height: 20));
      content.add(pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: visual.section,
          borderRadius: pw.BorderRadius.circular(7)),
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(category,
            style: pw.TextStyle(font: bold, fontSize: 18,
                color: visual.sectionInk))),
          pw.Text(entries.length.toString(),
            style: pw.TextStyle(font: bold, fontSize: 11,
                color: visual.sectionInk)),
        ]),
      ));
      content.add(pw.SizedBox(height: 12));
      final grid = visual.grid;
      for (var i = 0; i < entries.length; i += grid ? 2 : 1) {
        if (grid) {
          content.add(pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < 2; j++) ...[
                pw.Expanded(child: i + j < entries.length
                  ? _productCard(entries[i + j], visual, bold, serif,
                      photo(entries[i + j]['imagen']), true)
                  : pw.SizedBox()),
                if (j == 0) pw.SizedBox(width: 12),
              ],
            ],
          ));
        } else {
          content.add(_productCard(entries[i], visual, bold, serif,
              photo(entries[i]['imagen']), false));
        }
        content.add(pw.SizedBox(height: 11));
      }
    }
    if (link.startsWith('https://')) {
      content.add(pw.SizedBox(height: 22));
      content.add(pw.Center(child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(), data: link,
            width: 100, height: 100, drawText: false),
          pw.SizedBox(height: 9),
          pw.Text('Escanea para consultar la carta actualizada',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(color: visual.ink, font: serif,
              fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.UrlLink(destination: link, child: pw.Text(link,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(color: visual.accent,
              fontSize: 8))),
        ],
      )));
    }
    document.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(36, 42, 36, 47),
        buildBackground: (_) => _pageBackground(visual, wallpaper),
      ),
      maxPages: 250,
      header: (_) => pw.Row(children: [
        pw.Expanded(child: pw.Text(branch.isEmpty ? title : branch,
          style: pw.TextStyle(color: visual.ink, font: bold,
            fontSize: 11))),
        pw.Text('CARTA DIGITAL',
          style: pw.TextStyle(color: visual.accent, font: bold,
            fontSize: 9)),
      ]),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(border: pw.Border(
          top: pw.BorderSide(color: visual.accent, width: 0.6))),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(title,
            style: pw.TextStyle(color: visual.ink, fontSize: 9))),
          pw.Text('Página ' + ctx.pageNumber.toString() +
              ' de ' + ctx.pagesCount.toString(),
            style: pw.TextStyle(color: visual.ink, fontSize: 9)),
        ]),
      ),
      build: (_) => content,
    ));
    return document.save();
  }

  static pw.Widget _productCard(
    Map<String, dynamic> product,
    _MenuPdfVisual visual,
    pw.Font bold,
    pw.Font serif,
    pw.MemoryImage? image,
    bool grid,
  ) {
    final name = _value(product['nombre'], 'Producto');
    final description = _value(product['descripcion']);
    final price = num.tryParse(_value(product['precio'], '0')) ?? 0;
    final priceLabel = _money.format(price);
    final photo = image == null ? null :
        pw.Image(image, fit: pw.BoxFit.cover);
    final texts = <pw.Widget>[
      pw.Text(name, maxLines: 3,
        style: pw.TextStyle(font: bold,
          color: visual.ink, fontSize: grid ? 12 : 13)),
      if (description.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(description, maxLines: grid ? 4 : 8,
          style: pw.TextStyle(font: serif,
            color: visual.ink, fontSize: 9, lineSpacing: 2)),
      ],
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: visual.card,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: visual.border, width: 0.6)),
      padding: const pw.EdgeInsets.all(11),
      child: grid
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (photo != null) ...[
                  pw.Container(height: 105, width: double.infinity, child: photo),
                  pw.SizedBox(height: 10),
                ],
                ...texts,
                pw.SizedBox(height: 9),
                pw.Text(priceLabel, style: pw.TextStyle(
                  font: bold, color: visual.accent, fontSize: 13)),
              ],
            )
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (photo != null && visual.showRowImages) ...[
                  pw.Container(width: 72, height: 72, child: photo),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: texts)),
                pw.SizedBox(width: 12),
                pw.Text(priceLabel, style: pw.TextStyle(
                    font: bold, color: visual.accent, fontSize: 12)),
              ],
            ),
    );
  }
}

class _MenuPdfVisual {
  _MenuPdfVisual(String raw, Map<String, dynamic> menu)
      : name = raw.toUpperCase(),
        background = _color(_background(raw, menu)),
        card = _color(_card(raw, menu)),
        ink = _color(_ink(raw, menu)),
        accent = _color(_accent(raw, menu)),
        section = _color(_section(raw, menu)),
        sectionInk = _color(_sectionInk(raw, menu)),
        border = _color(_border(raw, menu));

  final String name;
  final PdfColor background, card, ink, accent, section, sectionInk, border;
  bool get elegant => name == 'ELEGANTE';
  PdfColor get muted => PdfColor.fromHex('#B5B2AB');

  bool get serif => <String>{
    'LIBRO', 'DOCUMENTO', 'BISTRO', 'EDITORIAL'
  }.contains(name);

  bool get grid => <String>{
    'TIENDA', 'TIENDA_WEB', 'GALERIA', 'NOCTURNO'
  }.contains(name);

  bool get showRowImages => name == 'BISTRO' ||
      name == 'EDITORIAL';

  static PdfColor _color(String hex) => PdfColor.fromHex(hex);

  static String _user(Map<String, dynamic> m, String k, String otherwise) {
    final value = (m[k] ?? '').toString();
    return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
        ? value : otherwise;
  }

  static String _background(String s, Map<String, dynamic> m) => switch (s) {
    'ELEGANTE' => '#171C20',
    'NOCTURNO' => '#101820',
    'DOCUMENTO' => '#FFFDF8',
    'BISTRO' => '#FAF6EE',
    'LIBRO' => '#FFF9EF',
    'EDITORIAL' || 'MINIMALISTA' || 'TIENDA_WEB' || 'GALERIA' => '#FFFFFF',
    _ => _user(m, 'fondo', '#10251D'),
  };

  static String _card(String s, Map<String, dynamic> m) => switch (s) {
    'ELEGANTE' => '#171C20',
    'NOCTURNO' => '#1B2830',
    'DOCUMENTO' => '#FFFFFF',
    'BISTRO' => '#F4EBDC',
    'LIBRO' => '#F4E9D7',
    'EDITORIAL' || 'MINIMALISTA' || 'TIENDA_WEB' || 'GALERIA' => '#F7F9FA',
    _ => _user(m, 'tarjeta', '#1C382D'),
  };

  static String _ink(String s, Map<String, dynamic> m) => switch (s) {
    'ELEGANTE' => '#F8F1E6',
    'NOCTURNO' => '#E8F8F7',
    'DOCUMENTO' || 'MINIMALISTA' || 'EDITORIAL' => '#293632',
    'BISTRO' || 'LIBRO' => '#2E2923',
    'TIENDA_WEB' || 'GALERIA' => '#182C32',
    _ => _user(m, 'texto', '#F7F4E9'),
  };

  static String _accent(String s, Map<String, dynamic> m) => switch (s) {
    'ELEGANTE' => '#E3C48B',
    'NOCTURNO' => '#71E4DA',
    'DOCUMENTO' => '#917B55',
    'BISTRO' => '#85512E',
    'LIBRO' => '#915B45',
    'EDITORIAL' => '#A86A4D',
    'MINIMALISTA' => '#297C78',
    'TIENDA_WEB' => '#147D88',
    'GALERIA' => '#167A86',
    _ => _user(m, 'primario', '#14B8A6'),
  };

  static String _section(String s, Map<String, dynamic> m) =>
      s == 'DOCUMENTO' ? '#EDE6DA' :
      s == 'BISTRO' ? '#E8D7C1' :
      s == 'ELEGANTE' ? '#333636' :
      s == 'NOCTURNO' ? '#203842' :
      s == 'LIBRO' ? '#E7D6C2' : _accent(s, m);

  static String _sectionInk(String s, Map<String, dynamic> m) =>
      <String>{'DOCUMENTO', 'BISTRO', 'LIBRO'}.contains(s)
          ? '#2E2923' :
      <String>{'ELEGANTE', 'NOCTURNO'}.contains(s)
          ? '#FFFFFF' : '#FFFFFF';

  static String _border(String s, Map<String, dynamic> m) =>
      <String>{'ELEGANTE', 'NOCTURNO'}.contains(s)
          ? '#5A5040' : '#D8DEDF';
}
