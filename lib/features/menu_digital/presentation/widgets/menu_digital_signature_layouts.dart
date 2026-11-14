import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'menu_digital_extra_layouts.dart';
import 'menu_digital_palette.dart';

/// Cinco cartas de autor que no son variaciones de una misma cuadrícula.
/// No introducen compras ni modifican inventario: las acciones abren detalles.
class MenuDigitalSignatureLayouts {
  MenuDigitalSignatureLayouts._();

  static const styles = <String>{
    'DOCUMENTO', 'ELEGANTE', 'TIENDA_WEB', 'BISTRO', 'NOCTURNO',
  };

  static bool supports(String style) => styles.contains(style);

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_CO', symbol: r'$', decimalDigits: 0,
  );

  static String name(Map<String, dynamic> item) =>
      (item['nombre'] ?? 'Producto').toString();

  static String description(Map<String, dynamic> item) =>
      (item['descripcion'] ?? '').toString().trim();

  static String price(Map<String, dynamic> item) {
    final value = num.tryParse((item['precio'] ?? '').toString());
    return value == null ? '' : _currency.format(value);
  }

  static Color _readableAccent(Color accent, Color background, Color fallback) =>
      MenuDigitalColors.contrast(accent, background) >= 4.5
          ? accent : fallback;

  static Widget section({
    required String style,
    required String category,
    required List<Map<String, dynamic>> products,
    required MenuDigitalColors colors,
    required MenuProductPhoto image,
    required MenuProductDetail onDetails,
  }) {
    switch (style) {
      case 'DOCUMENTO':
        return _document(category, products, colors, onDetails);
      case 'ELEGANTE':
        return _elegant(category, products, colors, onDetails);
      case 'TIENDA_WEB':
        return _shop(category, products, colors, image, onDetails);
      case 'BISTRO':
        return _bistro(category, products, colors, image, onDetails);
      case 'NOCTURNO':
        return _night(category, products, colors, image, onDetails);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Apariencia de carta impresa/PDF: página de papel, márgenes anchos,
  /// precios a la derecha y líneas sutiles. No es una descarga de PDF.
  static Widget _document(
    String category,
    List<Map<String, dynamic>> products,
    MenuDigitalColors colors,
    MenuProductDetail onDetails,
  ) {
    const paper = Color(0xFFFFFCF6);
    const ink = Color(0xFF26322E);
    const muted = Color(0xFF65716C);
    final accent = _readableAccent(colors.accent, paper, ink);
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 27),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFFE7E1D4)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('CARTA  /  MENÚ',
              style: TextStyle(color: accent, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 2)),
            const Icon(Icons.restaurant_menu_rounded, color: muted, size: 18),
          ]),
          const SizedBox(height: 16),
          Text(category, textAlign: TextAlign.center,
            style: const TextStyle(color: ink, fontFamily: 'Georgia',
              fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFD9D3C7)),
          const SizedBox(height: 10),
          for (final p in products) ...[
            Semantics(
              button: true,
              label: 'Consultar ' + name(p),
              child: InkWell(
                onTap: () => onDetails(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(name(p), maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink,
                            fontFamily: 'Georgia', fontSize: 16,
                            fontWeight: FontWeight.w600))),
                        if (price(p).isNotEmpty) ...[
                          const SizedBox(width: 14),
                          Text(price(p), style: const TextStyle(
                            color: ink, fontSize: 14,
                            fontWeight: FontWeight.w800)),
                        ],
                      ]),
                      if (description(p).isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(description(p), maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted,
                            fontSize: 12, height: 1.5)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAE5DC)),
          ],
          const SizedBox(height: 17),
          Text('UNA SELECCIÓN PREPARADA PARA TI',
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ]),
      ),
    ));
  }

  /// Carta de autor para restaurantes finos: fondo tinta, títulos centrados,
  /// oro discreto y jerarquía tipográfica. Sin tarjetas ni fotos.
  static Widget _elegant(
    String category,
    List<Map<String, dynamic>> products,
    MenuDigitalColors colors,
    MenuProductDetail onDetails,
  ) {
    const dark = Color(0xFF171C20);
    const ivory = Color(0xFFF8F1E6);
    const secondary = Color(0xFFB5B2AB);
    final gold = _readableAccent(colors.accent, dark,
        const Color(0xFFE3C48B));
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withOpacity(.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.diamond_outlined, color: gold, size: 21),
        const SizedBox(height: 10),
        Text('LA CARTA', textAlign: TextAlign.center,
          style: TextStyle(color: gold, fontSize: 10,
            letterSpacing: 3, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(category, textAlign: TextAlign.center,
          style: const TextStyle(color: ivory, fontSize: 29,
            fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        const SizedBox(height: 13),
        Center(child: SizedBox(width: 85,
          child: Divider(color: gold.withOpacity(.7), height: 1))),
        const SizedBox(height: 10),
        for (final p in products) ...[
          InkWell(
            onTap: () => onDetails(p),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Column(children: [
                Text(name(p), textAlign: TextAlign.center,
                  style: const TextStyle(color: ivory,
                    fontFamily: 'Georgia', fontSize: 19,
                    fontWeight: FontWeight.w600)),
                if (description(p).isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(description(p), textAlign: TextAlign.center,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: secondary,
                      fontSize: 12, height: 1.6)),
                ],
                if (price(p).isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(price(p), style: TextStyle(color: gold,
                    fontSize: 15, letterSpacing: .4,
                    fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
          Center(child: SizedBox(width: 26,
            child: Divider(color: gold.withOpacity(.45), height: 1))),
        ],
      ]),
    );
  }

  /// Catálogo de e-commerce sin checkout: tarjetas con imagen, valor y CTA
  /// real para consultar el producto. Ideal para mostrar productos en móvil.
  static Widget _shop(
    String category,
    List<Map<String, dynamic>> products,
    MenuDigitalColors colors,
    MenuProductPhoto image,
    MenuProductDetail onDetails,
  ) {
    final accent = colors.accent;
    final fg = colors.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.shopping_bag_outlined, color: fg, size: 21),
        const SizedBox(width: 9),
        Expanded(child: Text(category, style: TextStyle(
          color: fg, fontWeight: FontWeight.w900, fontSize: 23))),
        Text('${products.length} opciones', style: TextStyle(
          color: fg.withOpacity(.7), fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, limits) {
        const gap = 13.0;
        final columns = limits.maxWidth >= 820 ? 3
            : limits.maxWidth >= 520 ? 2 : 1;
        final width = (limits.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final p in products)
            SizedBox(
              width: width,
              child: Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(17),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onDetails(p),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(17)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        image(p, double.infinity, 170),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name(p), maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: fg, fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                              if (description(p).isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(description(p), maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: fg.withOpacity(.72),
                                    height: 1.4, fontSize: 12)),
                              ],
                              const SizedBox(height: 12),
                              if (price(p).isNotEmpty)
                                Text(price(p), style: TextStyle(
                                  color: fg, fontSize: 19,
                                  fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Ver detalles', style: TextStyle(
                                      color: colors.onAccent,
                                      fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded,
                                      color: colors.onAccent, size: 17),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }

  /// Bistro/café: editorial cálido, con fotografía lateral alternada
  /// y numeración suave. Diferente del listado minimalista.
  static Widget _bistro(
    String category,
    List<Map<String, dynamic>> products,
    MenuDigitalColors colors,
    MenuProductPhoto image,
    MenuProductDetail onDetails,
  ) {
    const paper = Color(0xFFFAF6EE);
    const ink = Color(0xFF2E2923);
    const muted = Color(0xFF736B60);
    final accent = _readableAccent(colors.accent, paper,
        const Color(0xFF85512E));
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 25, 17, 24),
      decoration: BoxDecoration(
        color: paper, borderRadius: BorderRadius.circular(21)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.local_cafe_outlined, color: accent, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(category,
            style: const TextStyle(color: ink,
              fontFamily: 'Georgia', fontSize: 26,
              fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 7),
        Text('HECHO PARA DISFRUTAR',
          style: TextStyle(color: accent, letterSpacing: 1.8,
            fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 13),
        Container(height: 1.5, color: ink.withOpacity(.18)),
        for (var i = 0; i < products.length; i++) ...[
          InkWell(
            onTap: () => onDetails(products[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: LayoutBuilder(builder: (context, limits) {
                final compact = limits.maxWidth < 370;
                final photoSize = compact ? 67.0 : 92.0;
                final p = products[i];
                return Row(crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (i.isEven) ...[
                      image(p, photoSize, photoSize),
                      const SizedBox(width: 13),
                    ],
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('N.º ${(i + 1).toString().padLeft(2, '0')}',
                          style: TextStyle(color: accent,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(name(p), maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink,
                            fontFamily: 'Georgia', fontSize: 17,
                            fontWeight: FontWeight.bold)),
                        if (description(p).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(description(p), maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted,
                              fontSize: 11.5, height: 1.4)),
                        ],
                        if (price(p).isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(price(p), style: TextStyle(color: accent,
                            fontSize: 15, fontWeight: FontWeight.w900)),
                        ],
                      ],
                    )),
                    if (i.isOdd) ...[
                      const SizedBox(width: 13),
                      image(p, photoSize, photoSize),
                    ],
                  ],
                );
              }),
            ),
          ),
          if (i < products.length - 1)
            Divider(color: ink.withOpacity(.13), height: 1),
        ],
      ]),
    );
  }

  /// Estética nocturna para bar/cócteles: alto contraste, superficies
  /// oscuras y brillo de acento controlado; nunca sacrifica legibilidad.
  static Widget _night(
    String category,
    List<Map<String, dynamic>> products,
    MenuDigitalColors colors,
    MenuProductPhoto image,
    MenuProductDetail onDetails,
  ) {
    const dark = Color(0xFF101820);
    const card = Color(0xFF1B2830);
    const light = Color(0xFFF1F6F5);
    const muted = Color(0xFFC0CAC9);
    final accent = _readableAccent(colors.accent, card,
        const Color(0xFF71E4DA));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      decoration: BoxDecoration(color: dark,
        borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.nightlife_rounded, color: accent, size: 23),
          const SizedBox(width: 10),
          Expanded(child: Text(category.toUpperCase(),
            style: const TextStyle(color: light, fontSize: 21,
              fontWeight: FontWeight.w900, letterSpacing: .7))),
        ]),
        const SizedBox(height: 6),
        Text('DESCUBRE NUESTROS FAVORITOS',
          style: TextStyle(color: accent, fontWeight: FontWeight.w700,
            fontSize: 10, letterSpacing: 1.4)),
        const SizedBox(height: 17),
        for (final p in products) ...[
          Material(
            color: card,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onDetails(p),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(.26))),
                padding: const EdgeInsets.all(10),
                child: LayoutBuilder(builder: (context, limits) {
                  final compact = limits.maxWidth < 390;
                  return Row(children: [
                    image(p, compact ? 72 : 100, compact ? 80 : 96),
                    const SizedBox(width: 13),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name(p), maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: light,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                        if (description(p).isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(description(p), maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11,
                              height: 1.3)),
                        ],
                        if (price(p).isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(price(p), style: TextStyle(
                            color: accent, fontSize: 16,
                            fontWeight: FontWeight.w900)),
                        ],
                      ],
                    )),
                    Icon(Icons.arrow_forward_ios_rounded,
                      color: accent, size: 14),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
