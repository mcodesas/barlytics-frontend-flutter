import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/utils/currency_utils.dart';
import '../utils/order_whatsapp_message_formatter.dart';

/// Historial compacto y legible, organizado por pedido y no por celdas
/// diminutas. Los importes son los calculados en el backend.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.data, required this.palette});

  final Map<String, dynamic> data;
  final AppPalette palette;

  double _money(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  String _date(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null
        ? (raw?.toString() ?? 'Sin fecha')
        : DateFormat('dd MMM yyyy · HH:mm', 'es_CO').format(parsed);
  }

  String _paymentStatus(String value) {
    return switch (value) {
      'PAGADO' => 'Pagado',
      'PAGO_PARCIAL' => 'Pago parcial',
      _ => 'Pendiente de pago',
    };
  }

  Widget _badge(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(title, style: TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w800, color: color,
      )),
    );
  }

  Widget _amount(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        )),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(CurrencyUtils.format(value), style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, color: color,
          )),
        ),
      ],
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.40),
        border: Border.all(color: palette.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: palette.secondary, size: 19),
            const SizedBox(width: 7),
            Expanded(child: Text(title, style: TextStyle(
              color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900,
            ))),
          ]),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }

  Widget _product(Map<String, dynamic> detail) {
    final units = _money(detail['unidades']);
    final packages = _money(detail['presentaciones']);
    final amount = _money(detail['subtotal']);
    final quantity = OrderWhatsappMessageFormatter.purchaseQuantityLabel({
      'presentacion_compra': detail['presentacion'],
      'unidades_por_presentacion': detail['unidadesPorPresentacion'],
    }, presentations: packages, units: units);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: palette.secondary),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((detail['producto'] ?? 'Producto').toString(),
                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                quantity + (units > 0 && (units - packages).abs() > 0.0001
                    ? ' · ' + units.toStringAsFixed(units % 1 == 0 ? 0 : 2) + ' unidades'
                    : ''),
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          )),
          if (amount > 0)
            Text(CurrencyUtils.format(amount), style: TextStyle(
              color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5,
            )),
        ],
      ),
    );
  }

  Widget _payment(Map<String, dynamic> payment) {
    final amount = _money(payment['valor']);
    final method = (payment['medio'] ?? 'Pago').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 18, color: palette.success),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              if (payment['fecha'] != null)
                Text(_date(payment['fecha']), style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              if ((payment['observacion'] ?? '').toString().trim().isNotEmpty)
                Text(payment['observacion'].toString(), style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ],
          )),
          Text(CurrencyUtils.format(amount), style: TextStyle(
            color: palette.success, fontSize: 13, fontWeight: FontWeight.w900,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = data['pediId']?.toString() ?? '—';
    final total = _money(data['totalEstimado']);
    final paid = _money(data['totalPagado']);
    final balance = _money(data['saldoPendiente']);
    final status = (data['estadoPago'] ?? 'PENDIENTE').toString().toUpperCase();
    final orderStatus = (data['estado'] ?? 'CONFIRMADO').toString().toUpperCase();
    final provider = (data['destinoNombre'] ?? '').toString().trim();
    final phone = (data['whatsappDestino'] ?? '').toString().trim();
    final note = (data['observacion'] ?? '').toString().trim();
    final products = _rows(data['detalles']);
    final payments = _rows(data['pagos']);
    final paidProgress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0).toDouble();
    final tone = status == 'PAGADO' ? palette.success : palette.warning;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Wrap(
              spacing: 8,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Pedido #' + id, style: TextStyle(
                  color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17,
                )),
                _badge(_paymentStatus(status), tone),
                _badge(orderStatus == 'RECIBIDO' ? 'Recibido' : 'Por recibir',
                    orderStatus == 'RECIBIDO' ? palette.success : palette.secondary),
              ],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (provider.isEmpty ? 'Proveedor general' : provider) + ' · ' + _date(data['fecha']),
                style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 13),
              LayoutBuilder(builder: (context, constraints) {
                final narrow = constraints.maxWidth < 390;
                final totals = [
                  _amount('Total', total, palette.textPrimary),
                  _amount('Abonado', paid, palette.success),
                  _amount('Por pagar', balance, balance > 0 ? palette.warning : palette.success),
                ];
                if (narrow) {
                  return Wrap(
                    spacing: 24, runSpacing: 12,
                    children: [
                      for (final item in totals)
                        SizedBox(width: 125, child: item),
                    ],
                  );
                }
                return Row(children: [
                  for (final item in totals) Expanded(child: item),
                ]);
              }),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: paidProgress, minHeight: 7,
                  color: palette.success,
                  backgroundColor: palette.cardBorder,
                ),
              ),
              const SizedBox(height: 8),
              Text(products.length.toString() + ' productos · ' +
                  (payments.isEmpty ? 'Sin abonos' : payments.length.toString() + ' abonos'),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ],
          ),
          children: [
            if (phone.isNotEmpty || note.isNotEmpty) ...[
              if (phone.isNotEmpty)
                Align(alignment: Alignment.centerLeft, child: Text(
                  'WhatsApp proveedor: ' + phone,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                )),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 7),
                Align(alignment: Alignment.centerLeft, child: Text(
                  'Observaciones: ' + note,
                  style: TextStyle(color: palette.textPrimary, fontSize: 12.5),
                )),
              ],
              const SizedBox(height: 12),
            ],
            LayoutBuilder(builder: (context, constraints) {
              final productPanel = _section(
                'Productos (' + products.length.toString() + ')',
                Icons.inventory_2_rounded,
                products.isEmpty
                    ? [Text('Sin productos registrados.', style: TextStyle(color: palette.textSecondary))]
                    : products.map(_product).toList(),
              );
              final paymentPanel = _section(
                'Pagos (' + payments.length.toString() + ')',
                Icons.payments_outlined,
                payments.isEmpty
                    ? [Text('Todavía no hay abonos registrados.', style: TextStyle(color: palette.textSecondary))]
                    : payments.map(_payment).toList(),
              );
              if (constraints.maxWidth < 590) {
                return Column(children: [
                  productPanel, const SizedBox(height: 10), paymentPanel,
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: productPanel), const SizedBox(width: 10),
                  Expanded(child: paymentPanel),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
