import 'package:intl/intl.dart';

/// Solo construye el texto del pedido para WhatsApp, sin modificar el pedido.
class OrderWhatsappMessageFormatter {
  const OrderWhatsappMessageFormatter._();

  static final NumberFormat _quantityFormat = NumberFormat.decimalPattern('es_CO')
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 3;

  static final NumberFormat _moneyFormat =
      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  static String _singleLine(Object? value, {String fallback = ''}) {
    final clean = (value?.toString() ?? '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll('*', '')
        .replaceAll('_', '')
        .trim();
    return clean.isEmpty ? fallback : clean;
  }

  static double _asNumber(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return 0;
    return double.tryParse(raw.toString()) ?? 0;
  }

  static String _formatQuantity(double amount) => _quantityFormat.format(amount);

  static String _presentationLabel(String label, double quantity) {
    final trimmed = _singleLine(label, fallback: 'unidad');
    if (quantity == 1) return trimmed;
    final match =
        RegExp(r'^([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)(.*)$').firstMatch(trimmed);
    if (match == null) return trimmed;
    final first = match.group(1)!;
    final rest = match.group(2)!;
    final plural = switch (first.toLowerCase()) {
      'unidad' => 'unidades',
      'caja' => 'cajas',
      'paquete' => 'paquetes',
      'botella' => 'botellas',
      'bolsa' => 'bolsas',
      'bulto' => 'bultos',
      'docena' => 'docenas',
      'lata' => 'latas',
      'sixpack' => 'sixpacks',
      'pack' => 'packs',
      'canasta' => 'canastas',
      'bandeja' => 'bandejas',
      'saco' => 'sacos',
      _ => first,
    };
    return plural + rest;
  }

  /// Usa cantidades y subtotales confirmados; omite precios no disponibles.
  static String format({
    required List<Map<String, dynamic>> products,
    required String companyName,
    required String branchName,
    required DateTime date,
    int? orderId,
    String? supplierName,
    String? observation,
  }) {
    final company = _singleLine(companyName, fallback: 'Empresa');
    final branch = _singleLine(branchName, fallback: 'Sucursal');
    final supplier = _singleLine(supplierName);
    final note = (observation ?? '').trim().replaceAll('\r\n', '\n');

    final buffer = StringBuffer()
      ..writeln('*PEDIDO DE COMPRA' +
          (orderId == null ? '' : ' #' + orderId.toString()) + '*')
      ..writeln()
      ..writeln('*Empresa:* ' + company)
      ..writeln('*Sucursal:* ' + branch);
    if (supplier.isNotEmpty) buffer.writeln('*Proveedor:* ' + supplier);
    buffer
      ..writeln('*Fecha:* ' + DateFormat('dd/MM/yyyy HH:mm').format(date))
      ..writeln()
      ..writeln('Hola, buen día. Por favor confírmanos la disponibilidad del siguiente pedido:')
      ..writeln()
      ..writeln('*PRODUCTOS SOLICITADOS (' + products.length.toString() + ')*');

    var estimatedTotal = 0.0;
    var knownPrices = 0;

    for (final row in products) {
      final presentations = _asNumber(row['presentaciones_pedir']);
      final units = _asNumber(row['unidades_pedir']);
      final count = presentations > 0 ? presentations : units;
      final label = presentations > 0
          ? _presentationLabel(
              _singleLine(row['presentacion_compra'], fallback: 'unidad'),
              presentations,
            )
          : _presentationLabel('unidad', units);
      final product = _singleLine(row['producto'], fallback: 'Producto sin nombre');
      final description = _singleLine(
          row['descripcion'] ?? row['producto_descripcion'] ?? row['prodDescripcion']);

      buffer
        ..writeln()
        ..writeln('• *' + _formatQuantity(count) + ' ' + label + '* — ' + product);

      if (description.isNotEmpty &&
          description.toLowerCase() != product.toLowerCase()) {
        buffer.writeln('  ' + description);
      }
      if (presentations > 0 && units > 0 &&
          (units - presentations).abs() > 0.0001) {
        buffer.writeln('  Equivalente: ' + _formatQuantity(units) + ' unidades');
      }

      final value = _asNumber(row['costo_pedido_estimado']);
      if (value > 0) {
        knownPrices++;
        estimatedTotal += value;
        buffer.writeln('  Valor estimado: ' + _moneyFormat.format(value));
      }
    }

    if (knownPrices > 0) {
      buffer
        ..writeln()
        ..writeln((knownPrices == products.length
                ? '*TOTAL ESTIMADO:* '
                : '*TOTAL ESTIMADO PARCIAL:* ') +
            _moneyFormat.format(estimatedTotal));
    }

    if (note.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('*OBSERVACIONES:*')
        ..writeln(note);
    }

    buffer
      ..writeln()
      ..writeln('Muchas gracias. Quedamos atentos a tu confirmación.')
      ..write('_Pedido generado desde BarLytics_');
    return buffer.toString();
  }
}
