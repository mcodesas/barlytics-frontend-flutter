import 'package:flutter/material.dart';

/// Medidas compartidas por buscadores, selectores y filtros operativos.
///
/// Mantener estos valores centralizados evita que cada módulo defina campos
/// de 48, 52 o más píxeles y conserva una interfaz compacta tipo POS.
abstract final class AppControlMetrics {
  static const double filterHeight = 40;
  static const double filterIconExtent = 36;
  static const EdgeInsets filterContentPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 9,
  );
  static const BoxConstraints filterConstraints = BoxConstraints(
    minHeight: filterHeight,
    maxHeight: filterHeight,
  );
  static const BoxConstraints filterIconConstraints = BoxConstraints(
    minWidth: filterIconExtent,
    maxWidth: filterIconExtent,
    minHeight: filterIconExtent,
    maxHeight: filterIconExtent,
  );
}

/// Convierte una decoración normal en un filtro compacto y consistente.
extension CompactFilterInputDecoration on InputDecoration {
  InputDecoration compactFilter({bool fixedHeight = true}) {
    return copyWith(
      isDense: true,
      contentPadding: AppControlMetrics.filterContentPadding,
      constraints: fixedHeight
          ? AppControlMetrics.filterConstraints
          : const BoxConstraints(minHeight: AppControlMetrics.filterHeight),
      prefixIconConstraints: AppControlMetrics.filterIconConstraints,
      suffixIconConstraints: AppControlMetrics.filterIconConstraints,
    );
  }
}
