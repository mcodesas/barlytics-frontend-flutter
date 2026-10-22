import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:barlytics_frontend/app/theme/app_palette.dart';
import 'package:barlytics_frontend/features/reportes/presentation/widgets/order_history_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  testWidgets('historial separa proveedor, pagos y productos', (tester) async {
    final order = <String, dynamic>{
      'pediId': 128,
      'fecha': '2026-10-21T14:45:00',
      'estadoPago': 'PAGO_PARCIAL',
      'estado': 'CONFIRMADO',
      'totalEstimado': 140000,
      'totalPagado': 40000,
      'saldoPendiente': 100000,
      'destinoNombre': 'Proveedor Central',
      'whatsappDestino': '573000000000',
      'observacion': 'Entregar mañana',
      'detalles': [
        {
          'producto': 'Cerveza Dorada',
          'presentaciones': 2,
          'presentacion': 'Caja',
          'unidades': 48,
          'subtotal': 120000,
        },
      ],
      'pagos': [
        {
          'medio': 'EFECTIVO',
          'valor': 40000,
          'fecha': '2026-10-21T15:00:00',
        },
      ],
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderHistoryCard(data: order, palette: appPalettes.first),
        ),
      ),
    ));
    expect(find.text('Pedido #128'), findsOneWidget);
    expect(find.text('Pago parcial'), findsOneWidget);
    expect(find.textContaining('Proveedor Central'), findsOneWidget);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('Productos (1)'), findsOneWidget);
    expect(find.text('Cerveza Dorada'), findsOneWidget);
    expect(find.textContaining('Pagos (1)'), findsOneWidget);
    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.textContaining('Entregar mañana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
