import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'menu_digital_palette.dart';
import '../../domain/menu_digital_ordering.dart';
import 'menu_digital_extra_layouts.dart';

/// Render compartido: la vista previa en el editor utiliza exactamente la
/// misma composición que la página pública del cliente.
class MenuDigitalCatalog extends StatefulWidget {
  const MenuDigitalCatalog({super.key, required this.menu, this.preview = false});

  final Map<String, dynamic> menu;
  final bool preview;

  @override
  State<MenuDigitalCatalog> createState() => _MenuDigitalCatalogState();
}

class _MenuDigitalCatalogState extends State<MenuDigitalCatalog> {
  String _category = 'Todos';
  String _search = '';
  int _bookPage = 0;
  int _heroPage = 0;
  final _money = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  Color _color(String key, String fallback) {
    final raw = (widget.menu[key] ?? fallback).toString().replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
      return Color(int.parse(fallback.replaceAll('#', ''), radix: 16) | 0xFF000000);
    }
    return Color(int.parse(raw, radix: 16) | 0xFF000000);
  }

  List<Map<String, dynamic>> get _products {
    final raw = widget.menu['productos'];
    if (raw is! List) return [];

    final products = raw.whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r)).toList();
    final order = (widget.menu['ordenTipos'] as List? ?? const [])
        .whereType<String>().toList();
    return MenuDigitalOrdering.arrange(products, categoryOrder: order);
  }

  ImageProvider? _image(dynamic value) {
    final raw = value?.toString() ?? '';
    try {
      if (raw.startsWith('data:image/') && raw.contains(',')) {
        final Uint8List bytes = base64Decode(raw.substring(raw.indexOf(',') + 1));
        return MemoryImage(bytes);
      }
      if (raw.startsWith('https://')) return NetworkImage(raw);
    } catch (_) {
      return null;
    }
    return null;
  }

  Widget _photo(dynamic value, {double? height, double? width, double radius = 18}) {
    final img = _image(value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        width: width,
        color: _color('primario', '#14B8A6').withOpacity(0.14),
        child: img == null
            ? Center(child: Icon(Icons.restaurant_menu_rounded,
                size: 39, color: _color('primario', '#14B8A6')))
            : Image(image: img, fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Center(child: Icon(Icons.restaurant_rounded,
                        size: 39, color: _color('primario', '#14B8A6')))),
      ),
    );
  }


  /// Las fotos abren un visor con zoom y datos del producto.
  /// También permite consultar los detalles cuando no hay imagen cargada.
  Widget _productPhoto(Map<String, dynamic> product, {
    required double width,
    required double height,
    double radius = 16,
  }) {
    final name = (product['nombre'] ?? 'Producto').toString();
    final hasImage = _image(product['imagen']) != null;
    return Semantics(
      button: true,
      label: 'Ampliar imagen y descripción de ' + name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showProductDetails(product),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              _photo(product['imagen'], width: width, height: height, radius: radius),
              if (hasImage)
                Positioned(
                  right: 6, bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.66),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.zoom_in_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final name = (product['nombre'] ?? 'Producto').toString();
    final description = (product['descripcion'] ?? '').toString().trim();
    final category = (product['tipo'] ?? 'Especialidades').toString();
    final price = num.tryParse((product['precio'] ?? '').toString());
    final provider = _image(product['imagen']);
    final detailAccent = MenuDigitalColors.contrast(colors.accent, colors.card) >= 4.5
        ? colors.accent : colors.text;

    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.restaurant_menu_rounded, color: detailAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('DETALLES DEL PRODUCTO',
                    style: TextStyle(color: detailAccent, fontSize: 11,
                        fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(dialog).pop(),
                    color: colors.text,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: (MediaQuery.sizeOf(dialog).height * .44).clamp(170.0, 410.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      color: colors.secondarySurface,
                      child: provider == null
                          ? Center(child: Icon(Icons.restaurant_menu_rounded,
                              color: detailAccent, size: 70))
                          : InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              child: Image(
                                image: provider,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                  Center(child: Icon(Icons.broken_image_outlined,
                                    color: detailAccent, size: 60)),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (provider != null)
                  Center(child: Text('Pellizca o amplía la imagen para ver los detalles',
                    style: TextStyle(color: colors.mutedText, fontSize: 11))),
                const SizedBox(height: 16),
                Text(category.toUpperCase(),
                  style: TextStyle(color: detailAccent, fontSize: 11,
                      letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(name,
                  style: TextStyle(color: colors.text, fontSize: 24, height: 1.15,
                      fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(description.isEmpty ? 'Sin descripción adicional.' : description,
                  style: TextStyle(color: colors.text.withOpacity(.84),
                      fontSize: 14, height: 1.5)),
                if (price != null) ...[
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(_money.format(price),
                      style: TextStyle(color: colors.onAccent,
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: detailAccent),
                    onPressed: () => Navigator.of(dialog).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeItem(Map<String, dynamic> p, double width) {
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final fg = colors.text;
    final accent = MenuDigitalColors.contrast(colors.accent, colors.card) >= 4.5
        ? colors.accent : fg;
    final name = (p['nombre'] ?? 'Producto').toString();
    final price = num.tryParse((p['precio'] ?? '').toString());
    final description = (p['descripcion'] ?? '').toString().trim();
    return SizedBox(
      width: width,
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showProductDetails(p),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _productPhoto(p, width: double.infinity, height: 152, radius: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 17),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 18,
                          fontWeight: FontWeight.w800, height: 1.2)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withOpacity(.72),
                          fontSize: 12, height: 1.45)),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      if (price != null)
                        Expanded(child: Text(_money.format(price),
                          style: TextStyle(color: accent, fontSize: 17,
                            fontWeight: FontWeight.w900))),
                      Icon(Icons.arrow_outward_rounded,
                        color: fg.withOpacity(.65), size: 19),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bookSection(String category, List<Map<String, dynamic>> products) {
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final fg = colors.text;
    final accent = MenuDigitalColors.contrast(colors.accent, colors.card) >= 4.5
        ? colors.accent : fg;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('NUESTRA SELECCIÓN',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(category, textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 28,
            fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Divider(color: colors.border, height: 1),
        for (final p in products) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showProductDetails(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _productPhoto(p, width: 72, height: 75, radius: 10),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((p['nombre'] ?? 'Producto').toString(),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 16,
                        fontWeight: FontWeight.w800)),
                    if ((p['descripcion'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p['descripcion'].toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withOpacity(.7),
                          fontSize: 12, height: 1.4)),
                    ],
                    if (num.tryParse((p['precio'] ?? '').toString()) != null) ...[
                      const SizedBox(height: 7),
                      Text(_money.format(num.parse(p['precio'].toString())),
                        style: TextStyle(color: accent, fontSize: 15,
                          fontWeight: FontWeight.w900)),
                    ],
                  ],
                )),
              ]),
            ),
          ),
          Divider(color: colors.border, height: 1),
        ],
      ]),
    );
  }

  Widget _categoryTitle(String category, int count,
      MenuDigitalColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 4, height: 38,
          decoration: BoxDecoration(
            color: colors.accent, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(child: Text(category,
          style: TextStyle(color: colors.text, fontSize: 23,
            fontFamily: 'Georgia', fontWeight: FontWeight.bold))),
        const SizedBox(width: 6),
        Text('${count} opciones',
          style: TextStyle(color: colors.text.withOpacity(.66),
            fontSize: 11)),
      ]),
    );
  }

  Widget _productsForStyle(
    String style, List<Map<String, dynamic>> products,
    MenuDigitalColors colors, double itemWidth, double gap,
  ) {
    if (style == 'EDITORIAL') {
      return MenuDigitalExtraLayouts.editorial(
        products: products, colors: colors,
        image: (p, w, h) => _productPhoto(p,
          width: w, height: h, radius: 10),
        onDetails: _showProductDetails,
      );
    }
    if (style == 'MINIMALISTA') {
      return MenuDigitalExtraLayouts.minimalist(
        products: products, colors: colors,
        image: (p, w, h) => _productPhoto(p,
          width: w, height: h, radius: 8),
        onDetails: _showProductDetails,
      );
    }
    return Wrap(spacing: gap, runSpacing: gap, children: [
      for (final p in products)
        if (style == 'GALERIA')
          MenuDigitalExtraLayouts.galleryItem(
            product: p, width: itemWidth, colors: colors,
            image: (product, w, h) => _productPhoto(
              product, width: w, height: h, radius: 12),
            onDetails: _showProductDetails,
          )
        else
          _storeItem(p, itemWidth),
    ]);
  }

  void _selectBookPage(int page, List<String> categories) {
    if (categories.isEmpty || page < 0 || page >= categories.length) return;
    setState(() {
      _bookPage = page;
      _category = categories[page];
    });
  }

  Future<void> _openVenuePhoto(List<String> photos, int first) async {
    if (photos.isEmpty) return;
    var current = first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = MenuDigitalColors.fromMenu(widget.menu);
          final photo = _image(photos[current]);
          return Dialog(
            backgroundColor: colors.canvas,
            insetPadding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 940,
                maxHeight: MediaQuery.sizeOf(context).height * .90),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 5),
                  child: Row(children: [
                    Expanded(child: Text('Fotografía ${current + 1} de ${photos.length}',
                      style: TextStyle(color: colors.text, fontSize: 16,
                        fontWeight: FontWeight.w800))),
                    IconButton(
                      tooltip: 'Cerrar fotografía',
                      color: colors.text,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded)),
                  ]),
                ),
                Flexible(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: photo == null
                      ? const SizedBox(height: 220,
                          child: Center(child: Icon(Icons.broken_image_outlined)))
                      : InteractiveViewer(
                          minScale: 1, maxScale: 5,
                          child: Center(child: Image(
                            image: photo,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined))),
                        ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: current == 0 ? null
                            : () => setDialogState(() => current--),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      Text('${current + 1} / ${photos.length}',
                        style: TextStyle(color: colors.text)),
                      TextButton.icon(
                        onPressed: current == photos.length - 1 ? null
                            : () => setDialogState(() => current++),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Siguiente'),
                      ),
                    ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _fullCoverHeader(
      MenuDigitalColors colors, Color canvas, Color fg, Color accent,
      bool mobile) {
    final slideshow = <String>[
      if (_image(widget.menu['portada']) != null)
        widget.menu['portada'].toString(),
      if (widget.menu['galeriaArriba'] == true)
        for (final photo in (widget.menu['galeria'] as List? ?? const []))
          if (photo is String && _image(photo) != null) photo,
    ];
    final page = slideshow.isEmpty ? 0 : _heroPage % slideshow.length;
    final cover = slideshow.isEmpty ? null : _image(slideshow[page]);
    final logo = _image(widget.menu['logo']);
    final branch = (widget.menu['sucursal'] ?? '').toString();
    final description = (widget.menu['descripcion'] ?? '').toString();
    final title = (widget.menu['titulo'] ?? 'Nuestra carta').toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cover != null)
        Container(
          height: mobile ? 225 : 350,
          width: double.infinity,
          color: colors.secondarySurface,
          child: InkWell(
            onTap: () => _openVenuePhoto(slideshow, page),
            child: Stack(fit: StackFit.expand, children: [
              // Ambientación a pantalla completa detrás del afiche para
              // no dejar bandas vacías, sin recortar la fotografía principal.
              Image(image: cover, fit: BoxFit.cover,
                color: colors.canvas.withOpacity(.55),
                colorBlendMode: BlendMode.srcOver,
                errorBuilder: (_, __, ___) =>
                    Container(color: colors.secondarySurface)),
              // Esta segunda capa garantiza la fotografía íntegra.
              Image(image: cover, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Center(child: Icon(Icons.image_outlined, size: 55,
                      color: colors.text))),
              if (slideshow.length > 1) ...[
                Positioned(left: 10, top: 0, bottom: 0,
                  child: Center(child: IconButton.filledTonal(
                    tooltip: 'Foto anterior de portada',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() {
                      _heroPage = (page - 1 + slideshow.length) %
                          slideshow.length;
                    }),
                  ))),
                Positioned(right: 10, top: 0, bottom: 0,
                  child: Center(child: IconButton.filledTonal(
                    tooltip: 'Siguiente foto de portada',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() {
                      _heroPage = (page + 1) % slideshow.length;
                    }),
                  ))),
                Positioned(left: 12, bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.canvas.withOpacity(.92),
                      borderRadius: BorderRadius.circular(14)),
                    child: Text('${page + 1} / ${slideshow.length}',
                      style: TextStyle(color: colors.text,
                        fontSize: 12, fontWeight: FontWeight.bold)),
                  )),
              ],
              Positioned(right: 14, bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.canvas.withOpacity(.90),
                    borderRadius: BorderRadius.circular(15)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.zoom_in_rounded,
                      color: colors.text, size: 17),
                    const SizedBox(width: 6),
                    Text('Ver foto completa',
                      style: TextStyle(color: colors.text,
                        fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                )),
            ]),
          ),
        ),
      Container(
        padding: EdgeInsets.fromLTRB(
            mobile ? 20 : 34, mobile ? 20 : 27,
            mobile ? 20 : 34, mobile ? 22 : 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            canvas, colors.card.withOpacity(.98)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (logo != null) ...[
              Container(
                height: mobile ? 70 : 88, width: mobile ? 70 : 88,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image(image: logo, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                      const Icon(Icons.storefront_rounded))),
              ),
              const SizedBox(width: 15),
            ] else ...[
              Container(
                height: 56, width: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.13),
                  borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.storefront_rounded, color: accent)),
              const SizedBox(width: 13),
            ],
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(branch.toUpperCase(), maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MenuDigitalColors.contrast(accent, canvas) >= 4.5
                        ? accent : fg,
                    fontSize: 12, fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
                const SizedBox(height: 5),
                Text(title, maxLines: 3,
                  style: TextStyle(color: fg, fontFamily: 'Georgia',
                    fontSize: mobile ? 28 : 39,
                    height: 1.12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(description, maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withOpacity(.85),
                fontSize: 13, height: 1.5)),
          ],

        ]),
      ),
    ]);
  }

  Widget _venueGallery(MenuDigitalColors colors, bool mobile) {
    final photos = (widget.menu['galeria'] as List? ?? const [])
        .whereType<String>()
        .where((raw) => _image(raw) != null)
        .toList();
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.photo_library_outlined, color: colors.accent, size: 25),
        const SizedBox(width: 9),
        Expanded(child: Text('Conoce nuestro lugar',
          style: TextStyle(color: colors.text,
              fontSize: mobile ? 19 : 24, fontWeight: FontWeight.w900))),
        Text('${photos.length} fotos',
          style: TextStyle(color: colors.text.withOpacity(.7))),
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, limits) {
        const spacing = 10.0;
        final columns = limits.maxWidth < 490 ? 2
            : limits.maxWidth < 850 ? 3 : 4;
        final width = (limits.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (var i = 0; i < photos.length; i++)
            SizedBox(
              width: width, height: mobile ? 118 : 155,
              child: Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openVenuePhoto(photos, i),
                  child: Stack(fit: StackFit.expand, children: [
                    Image(image: _image(photos[i])!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.broken_image_outlined,
                            color: colors.text)),
                    Positioned(right: 6, bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colors.canvas.withOpacity(.85),
                          shape: BoxShape.circle),
                        child: Icon(Icons.zoom_in_rounded,
                          color: colors.text, size: 20))),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _color('fondo', '#081B27');
    final fg = _color('texto', '#F8FAFC');
    final accent = _color('primario', '#14B8A6');
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final coverHasImage = _image(widget.menu['portada']) != null;
    final fullCover = widget.menu['portadaModo'] != 'DIVIDIDA';
    final backgroundPhoto = _image(widget.menu['fondoImagen']);
    final style = (widget.menu['estilo'] ?? 'TIENDA').toString().toUpperCase();
    final book = style == 'LIBRO';
    final items = _products;
    final preferredCategories = (widget.menu['ordenTipos'] as List? ?? const [])
        .whereType<String>().toList();
    final cats = <String>['Todos',
      ...MenuDigitalOrdering.categories(items, preferredCategories)];
    final selectedCategory = cats.contains(_category) ? _category : 'Todos';
    final searched = items.where((p) =>
        _search.isEmpty ||
        (p['nombre']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false) ||
        (p['descripcion']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false)
    ).toList();
    // No filtrar las hojas por el chip activo: las otras categorías
    // deben seguir existiendo para poder navegar hacia ellas.
    final bookCategories =
        MenuDigitalOrdering.categories(searched, preferredCategories);
    final currentBookPage = bookCategories.isEmpty
        ? 0 : _bookPage.clamp(0, bookCategories.length - 1).toInt();
    final activeBookCategory = bookCategories.isEmpty
        ? '' : bookCategories[currentBookPage];
    final filtered = book ? searched : searched.where((p) =>
        selectedCategory == 'Todos' ||
        MenuDigitalOrdering.category(p) == selectedCategory).toList();
    final visibleCategories =
        MenuDigitalOrdering.categories(filtered, preferredCategories);

    return Container(
      decoration: BoxDecoration(
        color: canvas,
        image: backgroundPhoto == null ? null : DecorationImage(
          image: backgroundPhoto,
          fit: BoxFit.cover,
          opacity: .17,
          colorFilter: ColorFilter.mode(
            canvas.withOpacity(.35), BlendMode.srcOver)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < 640;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(260.0, 1120.0) : 1120.0;
        final columns = book ? 1 : style == 'GALERIA'
            ? (maxWidth < 720 ? 1 : 2)
            : maxWidth < 500 ? 1 : maxWidth < 860 ? 2 : 3;
        const gap = 15.0;
        final itemWidth = (maxWidth - (mobile ? 32.0 : 48.0) -
            (columns - 1) * gap) / columns;
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            shrinkWrap: widget.preview,
            physics: widget.preview ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(mobile ? 16 : 24, 24, mobile ? 16 : 24, 55),
            children: [
              if (widget.preview) ...[
                Text('VISTA PREVIA · ' + (style == 'TIENDA' ? 'MODERNO' : style),
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
              ],
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: colors.border),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 18, offset: const Offset(0, 5),
                  )],
                ),
                child: fullCover
                    ? _fullCoverHeader(colors, canvas, fg, accent, mobile)
                    : Stack(children: [
                  if (coverHasImage)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.secondarySurface,
                        child: Image(
                          image: _image(widget.menu['portada'])!,
                          // En pantallas web anchas BoxFit.cover recortaba la
                          // parte superior e inferior de la portada (logos,
                          // nombres de negocio y texto del afiche).
                          // Contain mantiene visible el afiche completo.
                          fit: mobile ? BoxFit.cover : BoxFit.contain,
                          alignment: Alignment.centerRight,
                          errorBuilder: (context, error, stack) =>
                            Container(color: colors.secondarySurface),
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: mobile ? 232 : 250),
                    padding: EdgeInsets.all(mobile ? 23 : 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: coverHasImage
                          ? [canvas.withOpacity(.98), canvas.withOpacity(.85),
                              canvas.withOpacity(mobile ? .66 : .28)]
                          : [canvas.withOpacity(.98), canvas.withOpacity(.86)],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: mobile ? double.infinity : 550),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              if (_image(widget.menu['logo']) != null) ...[
                                _photo(widget.menu['logo'],
                                    height: 48, width: 48, radius: 12),
                                const SizedBox(width: 12),
                              ],
                              Flexible(child: Text(
                                (widget.menu['sucursal'] ?? '').toString().toUpperCase(),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color:
                                  MenuDigitalColors.contrast(accent, canvas) >= 4.5
                                    ? accent : fg,
                                  fontSize: 12, fontWeight: FontWeight.w900,
                                  letterSpacing: 1.7),
                              )),
                            ]),
                            const SizedBox(height: 13),
                            Text((widget.menu['titulo'] ?? 'Nuestra carta').toString(),
                              style: TextStyle(color: fg, fontFamily: 'Georgia',
                                fontSize: mobile ? 31 : 44,
                                fontWeight: FontWeight.bold, height: 1.1)),
                            const SizedBox(height: 10),
                            if ((widget.menu['descripcion'] ?? '').toString().isNotEmpty)
                              Text(widget.menu['descripcion'].toString(),
                                maxLines: 3, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: fg.withOpacity(.84),
                                  fontSize: 14, height: 1.5)),

                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              if (!widget.preview) ...[
                TextField(
                  onChanged: (value) => setState(() {
                    _search = value;
                    _bookPage = 0;
                  }),
                  cursorColor: accent,
                  style: TextStyle(color: fg, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar en nuestra carta',
                    hintStyle: TextStyle(color: fg.withOpacity(.62)),
                    prefixIcon: Icon(Icons.search_rounded, color: fg),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 17),
                    filled: true, fillColor: colors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(19),
                      borderSide: BorderSide(color: colors.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(19),
                      borderSide: BorderSide(color: colors.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(19),
                      borderSide: BorderSide(color: accent, width: 2)),
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Encuentra lo que te gusta',
                        style: TextStyle(color: fg, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(book
                          ? 'Elige un capítulo o pasa de página.'
                          : 'Explora todas las secciones o elige una en particular.',
                        style: TextStyle(
                          color: fg.withOpacity(.7), fontSize: 12)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: book
                            ? (bookCategories.isEmpty ? null : activeBookCategory)
                            : selectedCategory,
                        isExpanded: true,
                        dropdownColor: colors.card,
                        icon: Icon(Icons.expand_more_rounded, color: fg),
                        style: TextStyle(color: fg, fontSize: 14,
                          fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: book ? 'Capítulo' : 'Ver sección',
                          labelStyle: TextStyle(color: fg.withOpacity(.72)),
                          prefixIcon: Icon(Icons.menu_book_outlined, color: fg),
                          filled: true,
                          fillColor: colors.canvas.withOpacity(.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border)),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 12),
                        ),
                        items: [
                          for (final cat in (book ? bookCategories : cats))
                            DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat == 'Todos'
                                  ? 'Toda nuestra carta' : cat,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (cat) {
                          if (cat == null) return;
                          if (book) {
                            _selectBookPage(bookCategories.indexOf(cat),
                                bookCategories);
                          } else {
                            setState(() {
                              _category = cat;
                              _bookPage = 0;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
              Row(children: [
                Icon(book ? Icons.auto_stories_rounded : Icons.grid_view_rounded,
                  color: accent),
                const SizedBox(width: 9),
                Expanded(child: Text(book ? 'Explora nuestra carta' : 'Nuestra selección',
                  style: TextStyle(color: fg, fontFamily: 'Georgia',
                    fontWeight: FontWeight.bold, fontSize: 23))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: accent,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(filtered.length.toString(),
                    style: TextStyle(color: colors.onAccent,
                      fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 15),
              if (filtered.isEmpty)
                Padding(padding: const EdgeInsets.all(25),
                  child: Text('Por ahora no hay productos para mostrar.',
                    textAlign: TextAlign.center, style: TextStyle(color: fg.withOpacity(0.77))))
              else if (book) ...[
                // Cada categoría es una hoja del libro, con navegación real,
                // no un catálogo de tarjetas disfrazado de libro.
                _bookSection(bookCategories[currentBookPage],
                  filtered.where((p) =>
                    MenuDigitalOrdering.category(p) == bookCategories[currentBookPage]).toList()),
                const SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton.filledTonal(
                    tooltip: 'Página anterior',
                    style: IconButton.styleFrom(backgroundColor: accent,
                      foregroundColor: colors.onAccent,
                      disabledBackgroundColor: colors.secondarySurface,
                      disabledForegroundColor: fg.withOpacity(.45)),
                    onPressed: currentBookPage == 0 ? null
                        : () => _selectBookPage(currentBookPage - 1, bookCategories),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(child: Column(children: [
                    Text('PÁGINA ' + (currentBookPage + 1).toString() +
                        ' DE ' + bookCategories.length.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: accent,
                          fontWeight: FontWeight.w900, fontSize: 11)),
                    Text(bookCategories[currentBookPage],
                      textAlign: TextAlign.center,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.withOpacity(0.77), fontSize: 12)),
                  ])),
                  IconButton.filledTonal(
                    tooltip: 'Página siguiente',
                    style: IconButton.styleFrom(backgroundColor: accent,
                      foregroundColor: colors.onAccent,
                      disabledBackgroundColor: colors.secondarySurface,
                      disabledForegroundColor: fg.withOpacity(.45)),
                    onPressed: currentBookPage >= bookCategories.length - 1 ? null
                        : () => _selectBookPage(currentBookPage + 1, bookCategories),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ]),
              ] else ...[
                for (final category in visibleCategories) ...[
                  _categoryTitle(category,
                    filtered.where((p) =>
                      MenuDigitalOrdering.category(p) == category).length,
                    colors),
                  _productsForStyle(
                    style,
                    filtered.where((p) =>
                      MenuDigitalOrdering.category(p) == category).toList(),
                    colors, itemWidth, gap,
                  ),
                  const SizedBox(height: 13),
                ],
              ],
              if ((widget.menu['galeria'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: 30),
                _venueGallery(colors, mobile),
                const SizedBox(height: 10),
              ],
              if (!widget.preview) ...[
                const SizedBox(height: 35),
                Divider(color: fg.withOpacity(0.16)),
                const SizedBox(height: 15),
                Text('Los precios y productos están sujetos a disponibilidad en el establecimiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg.withOpacity(0.68), fontSize: 12)),
                if ((widget.menu['direccion'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 7),
                    child: Text(widget.menu['direccion'].toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fg.withOpacity(0.75), fontSize: 12))),
                const SizedBox(height: 10),
                Text('Menú digital · BarLytics',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ],
          ),
        ));
      }),
    );
  }
}
