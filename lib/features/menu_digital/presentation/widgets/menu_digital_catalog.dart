import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'menu_digital_palette.dart';

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
    return raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
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
    final accent = colors.accent;
    final fg = colors.text;
    final bg = colors.card;
    final name = (p['nombre'] ?? 'Producto').toString();
    final price = num.tryParse((p['precio'] ?? '').toString());
    final description = (p['descripcion'] ?? '').toString();
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.09),
              blurRadius: 20, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _productPhoto(p, width: double.infinity, height: 164, radius: 17),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((p['tipo'] ?? 'Especialidades').toString().toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: MenuDigitalColors.contrast(accent, bg) >= 4.5
                  ? accent : fg, fontSize: 10, letterSpacing: 1.1,
                  fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold, fontSize: 19, height: 1.17)),
            const SizedBox(height: 7),
            Text(description.isEmpty ? 'Conoce más sobre este producto' : description,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withOpacity(.77), fontSize: 12,
                  height: 1.45)),
            const SizedBox(height: 14),
            Row(children: [
              if (price != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: accent,
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(_money.format(price), style: TextStyle(
                    color: colors.onAccent, fontWeight: FontWeight.w900,
                    fontSize: 15)),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Ver foto y descripción',
                onPressed: () => _showProductDetails(p),
                icon: Icon(Icons.zoom_in_rounded, color: fg),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _bookSection(String category, List<Map<String, dynamic>> products) {
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final fg = colors.text;
    final accent = colors.accent;
    final bg = colors.card;
    final headingAccent = MenuDigitalColors.contrast(accent, bg) >= 4.5
        ? accent : fg;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 22, 15, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, colors.secondarySurface],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.075),
          blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: accent,
            shape: BoxShape.circle),
          child: Icon(Icons.auto_stories_rounded, color: colors.onAccent, size: 24),
        )),
        const SizedBox(height: 13),
        Text(category.toUpperCase(), textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 23, fontFamily: 'Georgia',
              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 7),
        Text('SELECCIÓN · ' + products.length.toString() + ' PRODUCTOS',
          textAlign: TextAlign.center,
          style: TextStyle(color: headingAccent, letterSpacing: 1.3,
            fontWeight: FontWeight.w800, fontSize: 10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 19),
          child: Divider(height: 1, color: colors.border),
        ),
        for (var i = 0; i < products.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withOpacity(.8)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
                blurRadius: 9, offset: const Offset(0, 4))],
            ),
            child: LayoutBuilder(builder: (context, limits) {
              final compact = limits.maxWidth < 340;
              final product = products[i];
              final price = num.tryParse((product['precio'] ?? '').toString());
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _productPhoto(product,
                  width: compact ? 52 : 72,
                  height: compact ? 62 : 76,
                  radius: 11),
                SizedBox(width: compact ? 9 : 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((product['nombre'] ?? 'Producto').toString(),
                      style: TextStyle(color: fg, fontSize: compact ? 14 : 17,
                          fontFamily: 'Georgia', fontWeight: FontWeight.bold,
                          height: 1.22)),
                    const SizedBox(height: 5),
                    Text((product['descripcion'] ?? '').toString(),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.withOpacity(.76),
                        fontSize: 11, height: 1.35)),
                  ],
                )),
                const SizedBox(width: 7),
                if (price != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(_money.format(price),
                      style: TextStyle(color: colors.onAccent,
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w900)),
                  ),
              ]);
            }),
          ),
          if (i < products.length - 1) const SizedBox(height: 10),
        ],
      ]),
    );
  }

  IconData _iconForCategory(String category) {
    final name = category.toUpperCase();
    if (name == 'TODOS') return Icons.check_circle_outline_rounded;
    if (name.contains('CERVEZA')) return Icons.sports_bar_rounded;
    if (name.contains('COCTEL') || name.contains('CÓCTEL')) {
      return Icons.local_bar_rounded;
    }
    if (name.contains('COMIDA') || name.contains('PASABOCAS')) {
      return Icons.tapas_rounded;
    }
    if (name.contains('BEBIDA') || name.contains('JUGO')) {
      return Icons.local_drink_rounded;
    }
    if (name.contains('WHISKY') || name.contains('LICOR') ||
        name.contains('AGUARDIENTE') || name.contains('RON')) {
      return Icons.wine_bar_rounded;
    }
    if (name.contains('CIGARRILLO')) return Icons.smoking_rooms_rounded;
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _color('fondo', '#081B27');
    final fg = _color('texto', '#F8FAFC');
    final accent = _color('primario', '#14B8A6');
    final colors = MenuDigitalColors.fromMenu(widget.menu);
    final coverHasImage = _image(widget.menu['portada']) != null;
    final book = widget.menu['estilo'] == 'LIBRO';
    final items = _products;
    final cats = <String>['Todos', ...items.map((p) =>
        (p['tipo'] ?? 'Especialidades').toString()).toSet()];
    final filtered = items.where((p) {
      final category = (p['tipo'] ?? 'Especialidades').toString();
      final matchesSearch = _search.isEmpty ||
          (p['nombre']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false) ||
          (p['descripcion']?.toString().toLowerCase().contains(_search.toLowerCase()) ?? false);
      return matchesSearch && (_category == 'Todos' || category == _category);
    }).toList();
    final bookCategories = <String>{
      for (final p in filtered) (p['tipo'] ?? 'Especialidades').toString(),
    }.toList();
    final currentBookPage = bookCategories.isEmpty
        ? 0 : _bookPage.clamp(0, bookCategories.length - 1).toInt();

    return Container(
      color: canvas,
      child: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < 640;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(260.0, 1120.0) : 1120.0;
        final columns = book ? (mobile ? 1 : 2)
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
                Text('VISTA PREVIA · ' + (book ? 'LIBRO' : 'TIENDA'),
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
                    color: Colors.black.withOpacity(.12),
                    blurRadius: 24, offset: const Offset(0, 10),
                  )],
                ),
                child: Stack(children: [
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
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(24)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(book ? Icons.menu_book_rounded
                                  : Icons.storefront_outlined,
                                  color: colors.onAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(book ? 'CARTA TIPO LIBRO' : 'CATÁLOGO TIPO TIENDA',
                                  style: TextStyle(color: colors.onAccent,
                                    fontSize: 11, fontWeight: FontWeight.w900,
                                    letterSpacing: .6)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
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
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final cat in cats) ...[
                      Padding(padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat), selected: _category == cat,
                          showCheckmark: false,
                          avatar: Icon(_iconForCategory(cat), size: 17,
                            color: _category == cat ? colors.onAccent : fg),
                          onSelected: (_) => setState(() {
                            _category = cat;
                            _bookPage = 0;
                          }),
                          selectedColor: accent,
                          backgroundColor: colors.card,
                          side: BorderSide(color: _category == cat
                              ? accent : colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                          labelStyle: TextStyle(
                            color: _category == cat ? colors.onAccent : fg,
                            fontWeight: FontWeight.w700),
                        )),
                    ],
                  ]),
                ),
                const SizedBox(height: 22),
              ],
              Row(children: [
                Icon(book ? Icons.auto_stories_rounded : Icons.grid_view_rounded,
                  color: accent),
                const SizedBox(width: 9),
                Expanded(child: Text(book ? 'Explora nuestra carta' : 'Nuestros productos',
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
                    (p['tipo'] ?? 'Especialidades') == bookCategories[currentBookPage]).toList()),
                const SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton.filledTonal(
                    tooltip: 'Página anterior',
                    style: IconButton.styleFrom(backgroundColor: accent,
                      foregroundColor: colors.onAccent,
                      disabledBackgroundColor: colors.secondarySurface,
                      disabledForegroundColor: fg.withOpacity(.45)),
                    onPressed: currentBookPage == 0 ? null
                        : () => setState(() => _bookPage = currentBookPage - 1),
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
                        : () => setState(() => _bookPage = currentBookPage + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ]),
              ] else
                Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final p in filtered)
                    _storeItem(p, itemWidth),
                ]),
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
