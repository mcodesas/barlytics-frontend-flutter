import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  Widget _storeItem(Map<String, dynamic> p, double width) {
    final accent = _color('primario', '#14B8A6');
    final fg = _color('texto', '#F8FAFC');
    final bg = _color('tarjeta', '#112D3B');
    final name = (p['nombre'] ?? 'Producto').toString();
    final price = num.tryParse((p['precio'] ?? '').toString());
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.11),
            blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _photo(p['imagen'], height: 145, width: double.infinity, radius: 19),
        Padding(padding: const EdgeInsets.all(15), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((p['tipo'] ?? 'Especialidades').toString().toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: accent, fontSize: 10,
                    fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            const SizedBox(height: 5),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 5),
            Text((p['descripcion'] ?? '').toString(),
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg.withOpacity(0.71), fontSize: 12, height: 1.35)),
            if (price != null) ...[
              const SizedBox(height: 11),
              Text(_money.format(price), style: TextStyle(
                  color: accent, fontWeight: FontWeight.w900, fontSize: 19)),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _bookSection(String category, List<Map<String, dynamic>> products) {
    final fg = _color('texto', '#F8FAFC');
    final accent = _color('primario', '#14B8A6');
    final bg = _color('tarjeta', '#112D3B');
    return Container(
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.19)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 25, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Icon(Icons.auto_stories_rounded, color: accent, size: 29)),
        const SizedBox(height: 10),
        Text(category.toUpperCase(), textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w900,
            letterSpacing: 1.8)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 15),
          child: Divider(color: accent.withOpacity(0.36), thickness: 1.2)),
        for (var i = 0; i < products.length; i++) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_image(products[i]['imagen']) != null) ...[
              _photo(products[i]['imagen'], width: 74, height: 82, radius: 12),
              const SizedBox(width: 13),
            ],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((products[i]['nombre'] ?? '').toString(),
                style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text((products[i]['descripcion'] ?? '').toString(),
                style: TextStyle(color: fg.withOpacity(0.73), fontSize: 12, height: 1.4)),
            ])),
            const SizedBox(width: 8),
            if (products[i]['precio'] != null)
              Text(_money.format(num.tryParse(products[i]['precio'].toString()) ?? 0),
                style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13)),
          ]),
          if (i < products.length - 1)
            Padding(padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: fg.withOpacity(0.12))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = _color('fondo', '#081B27');
    final fg = _color('texto', '#F8FAFC');
    final accent = _color('primario', '#14B8A6');
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
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26),
                    color: _color('tarjeta', '#112D3B')),
                child: Stack(children: [
                  if (_image(widget.menu['portada']) != null)
                    Positioned.fill(child: _photo(widget.menu['portada'],
                        width: double.infinity, radius: 26)),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 225),
                    padding: EdgeInsets.all(mobile ? 23 : 36),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [canvas.withOpacity(0.94), canvas.withOpacity(0.67)],
                      )),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_image(widget.menu['logo']) != null) ...[
                          _photo(widget.menu['logo'],
                              height: 48, width: 48, radius: 12),
                          const SizedBox(width: 12),
                        ],
                        Flexible(child: Text(
                          (widget.menu['sucursal'] ?? '').toString().toUpperCase(),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: accent, fontSize: 12,
                              fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        )),
                      ]),
                      const SizedBox(height: 11),
                      Text((widget.menu['titulo'] ?? 'Nuestra carta').toString(),
                        style: TextStyle(color: fg,
                          fontSize: mobile ? 29 : 39, fontWeight: FontWeight.w900, height: 1.08)),
                      const SizedBox(height: 12),
                      Text((widget.menu['descripcion'] ?? 'Descubre nuestros sabores').toString(),
                        style: TextStyle(color: fg.withOpacity(0.83), fontSize: 14, height: 1.45)),
                      const SizedBox(height: 17),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
                        child: Text(book ? 'CARTA TIPO LIBRO' : 'CATÁLOGO TIPO TIENDA',
                          style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900))),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              if (!widget.preview) ...[
                TextField(
                  onChanged: (value) => setState(() => _search = value),
                  style: TextStyle(color: fg),
                  decoration: InputDecoration(
                    hintText: 'Buscar en nuestra carta',
                    hintStyle: TextStyle(color: fg.withOpacity(0.58)),
                    prefixIcon: Icon(Icons.search_rounded, color: accent),
                    filled: true, fillColor: _color('tarjeta', '#112D3B'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
                      borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 13),
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final cat in cats) ...[
                      Padding(padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat), selected: _category == cat,
                          onSelected: (_) => setState(() => _category = cat),
                          selectedColor: accent,
                          backgroundColor: _color('tarjeta', '#112D3B'),
                          labelStyle: TextStyle(color: _category == cat
                              ? (ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                                  ? Colors.white : Colors.black)
                              : fg, fontWeight: FontWeight.w700),
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
                  style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 21))),
                Text(filtered.length.toString(), style: TextStyle(color: accent,
                  fontWeight: FontWeight.w900)),
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
