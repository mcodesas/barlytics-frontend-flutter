import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/reportes/presentation/utils/order_whatsapp_message_formatter.dart';

void main() {
  final fecha = DateTime(2026, 10, 21, 14, 45);

  final productos = <Map<String, dynamic>>[
    {
      'producto': 'Cerveza Águila',
      'presentaciones_pedir': 3,
      'presentacion_compra': 'Caja x 24',
      'unidades_pedir': 72,
      'descripcion': 'Lata de 330 ml',
      'costo_pedido_estimado': 135000,
    },
    {
      'producto': 'Limón',
      'presentaciones_pedir': 2,
      'presentacion_compra': 'Unidad',
      'unidades_pedir': 2,
      'costo_pedido_estimado': 5000,
    },
  ];

  String formato({
    List<Map<String, dynamic>>? rows,
    String companyName = 'Gastrobar El Mirador',
    String branchName = 'Sede Central',
    int? orderId = 128,
    String? supplierName = 'Distribuidora ABC',
    String? observation,
  }) {
    return OrderWhatsappMessageFormatter.format(
      products: rows ?? productos,
      companyName: companyName,
      branchName: branchName,
      date: fecha,
      orderId: orderId,
      supplierName: supplierName,
      observation: observation,
    );
  }

  test('incluye empresa sucursal proveedor y fecha en encabezado separado', () {
    final text = formato();
    expect(text, startsWith('*PEDIDO DE COMPRA #128*\n\n'));
    expect(text, contains('*Empresa:* Gastrobar El Mirador\n'));
    expect(text, contains('*Sucursal:* Sede Central\n'));
    expect(text, contains('*Proveedor:* Distribuidora ABC\n'));
    expect(text, contains('*Fecha:* 21/10/2026 14:45\n\n'));
    expect(text, contains('*PRODUCTOS SOLICITADOS (2)*\n\n'));
  });

  test('en cada línea escribe cantidad antes que nombre y descripción', () {
    final text = formato();
    final first = text.indexOf('• *3 cajas x 24* — Cerveza Águila');
    final second = text.indexOf('• *2 unidades* — Limón');

    expect(first, greaterThan(0));
    expect(second, greaterThan(first));
    expect(text, contains('  Lata de 330 ml\n'));
    expect(text, contains('  Equivalente: 72 unidades\n'));
    expect(text, isNot(contains('Equivalente: 2 unidades')));
    expect(text, contains('*TOTAL ESTIMADO:*'));
  });

  test('conserva saltos de línea en observaciones del pedido', () {
    final text = formato(observation: 'Entregar mañana.\nDespués de las 10:00 a. m.');
    expect(
      text,
      contains('\n\n*OBSERVACIONES:*\nEntregar mañana.\nDespués de las 10:00 a. m.\n\n'),
    );
    expect(text, endsWith('_Pedido generado desde BarLytics_'));
  });

  test('omite costos cuando no hay valor en el pedido', () {
    final text = formato(
      rows: [
        {
          'producto': 'Agua sin gas',
          'presentaciones_pedir': 6,
          'presentacion_compra': 'botella',
          'unidades_pedir': 6,
          'costo_pedido_estimado': 0,
        },
      ],
      supplierName: '',
      observation: '',
    );
    expect(text, contains('• *6 botellas* — Agua sin gas'));
    expect(text, isNot(contains('*Proveedor:*')));
    expect(text, isNot(contains('TOTAL ESTIMADO')));
    expect(text, isNot(contains('Valor estimado:')));
    expect(text, isNot(contains('OBSERVACIONES')));
  });

  test('si faltan costos el total es parcial para no engañar al proveedor', () {
    final text = formato(rows: [
      {'producto': 'A', 'presentaciones_pedir': 2, 'presentacion_compra': 'Unidad',
       'unidades_pedir': 2, 'costo_pedido_estimado': 15000},
      {'producto': 'B', 'presentaciones_pedir': 1, 'presentacion_compra': 'Unidad',
       'unidades_pedir': 1, 'costo_pedido_estimado': 0},
    ]);
    expect(text, contains('*TOTAL ESTIMADO PARCIAL:*'));
    expect(text, isNot(contains('*TOTAL ESTIMADO:*')));
  });

  test('limpia saltos extraños del nombre sin perder observaciones', () {
    final text = formato(
      companyName: 'Gastrobar\n  La Terraza',
      rows: [
        {'producto': '  Agua\n  con gas  ', 'presentaciones_pedir': 2,
         'presentacion_compra': 'Unidad', 'unidades_pedir': 2},
      ],
    );
    expect(text, contains('*Empresa:* Gastrobar La Terraza'));
    expect(text, contains('• *2 unidades* — Agua con gas'));
    expect(text, isNot(contains('null')));
  });
  test('el mensaje mantiene saltos al codificarse para WhatsApp', () {
    final message = formato(observation: 'Línea 1\nLínea 2');
    final encoded = Uri.encodeComponent(message);
    expect(encoded, contains('%0A'));
    expect(Uri.decodeComponent(encoded), message);
    expect(Uri.decodeComponent(encoded),
        contains('*OBSERVACIONES:*\nLínea 1\nLínea 2'));
  });

  test('cada pedido independiente conserva únicamente sus productos', () {
    final pedidoA = formato(
      supplierName: 'Distribuidora A',
      rows: [productos.first],
      orderId: 201,
    );
    final pedidoB = formato(
      supplierName: 'Distribuidora B',
      rows: [productos.last],
      orderId: 202,
    );
    expect(pedidoA, contains('• *3 cajas x 24* — Cerveza Águila'));
    expect(pedidoA, isNot(contains('Limón')));
    expect(pedidoB, contains('• *2 unidades* — Limón'));
    expect(pedidoB, isNot(contains('Cerveza Águila')));
    expect(pedidoA, contains('*Proveedor:* Distribuidora A'));
    expect(pedidoB, contains('*Proveedor:* Distribuidora B'));
  });

}
