import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'menu_digital_palette.dart';

typedef MenuProductPhoto = Widget Function(
    Map<String, dynamic> product, double width, double height);
typedef MenuProductDetail = void Function(Map<String, dynamic> product);

/// Tres composiciones adicionales a Tienda/Libro que comparten
/// productos, imágenes ampliables y las cuatro tonalidades de la carta.
class MenuDigitalExtraLayouts {
  MenuDigitalExtraLayouts._();

  static final _money = NumberFormat.currency(
      locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  static String name(Map<String, dynamic> item) =>
      (item['nombre'] ?? 'Producto').toString();

  static String description(Map<String, dynamic> item) =>
      (item['descripcion'] ?? '').toString().trim();

  static String price(Map<String, dynamic> item) {
    final value = num.tryParse((item['precio'] ?? '').toString());
    return value == null ? '' : _money.format(value);
  }

  /// Editorial: categorías y nombres grandes, divisores finos, precio a la derecha.
  static Widget editorial({
    required List<Map<String, dynamic>> products,
    required MenuDigitalColors colors,
    required MenuProductPhoto image,
    required MenuProductDetail onDetails,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // La cabecera de cada categoría se dibuja fuera de la lista.
        // Aquí solo se muestra cada producto, sin adornos repetidos.
        for (final p in products) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onDetails(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: LayoutBuilder(builder: (context, limits) {
                final compact = limits.maxWidth < 360;
                return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  image(p, compact ? 58 : 76, compact ? 64 : 74),
                  const SizedBox(width: 13),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
 
                      Text(name(p), style: TextStyle(color: colors.text,
                        fontSize: compact ? 15 : 18, fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold)),
                      if (description(p).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description(p), maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.text.withOpacity(.76),
                            fontSize: 11.5, height: 1.35)),
                      ],
                      if (compact && price(p).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(price(p), style: TextStyle(color: colors.text,
                          fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  )),
                  if (!compact && price(p).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(price(p), style: TextStyle(color: colors.text,
                      fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ]);
              }),
            ),
          ),
          Divider(color: colors.border, height: 15),
        ],
      ]),
    );
  }

  /// Galería: fotografías grandes, composición similar a una exposición.
  static Widget galleryItem({
    required Map<String, dynamic> product,
    required double width,
    required MenuDigitalColors colors,
    required MenuProductPhoto image,
    required MenuProductDetail onDetails,
  }) {
    final photoHeight = width < 260 ? 155.0 : 195.0;
    return SizedBox(
      width: width,
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onDetails(product),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            image(product, width, photoHeight),
            Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
 
                  Text(name(product), style: TextStyle(color: colors.text,
                    fontSize: 19, fontFamily: 'Georgia',
                    fontWeight: FontWeight.bold)),
                  if (description(product).isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(description(product), maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.text.withOpacity(.78),
                        fontSize: 12, height: 1.35)),
                  ],
                  if (price(product).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Text(price(product),
                        style: TextStyle(color: colors.text,
                          fontWeight: FontWeight.w900, fontSize: 16))),
                      Icon(Icons.zoom_in_rounded, color: colors.text),
                    ]),
                  ],
                ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// Minimalista: listado de consumo ágil con pocas distracciones visuales.
  static Widget minimalist({
    required List<Map<String, dynamic>> products,
    required MenuDigitalColors colors,
    required MenuProductPhoto image,
    required MenuProductDetail onDetails,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card, borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.border)),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Column(children: [
        for (final p in products) ...[
          InkWell(
            onTap: () => onDetails(p),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(children: [
                image(p, 56, 57),
                const SizedBox(width: 11),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name(p), maxLines: 2,
                      style: TextStyle(color: colors.text,
                        fontWeight: FontWeight.w800, fontSize: 15)),
                    if (description(p).isNotEmpty)
                      Text(description(p), maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.text.withOpacity(.72),
                          fontSize: 11)),
                  ],
                )),
                const SizedBox(width: 8),
                Text(price(p), style: TextStyle(color: colors.text,
                  fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(width: 5),
                Icon(Icons.chevron_right_rounded, color: colors.text,
                  size: 17),
              ]),
            ),
          ),
          Divider(height: 1, color: colors.border),
        ],
      ]),
    );
  }
}
