import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/utils/currency_utils.dart';

/// Diagnóstico compacto para Próximo pedido. Oculta columnas técnicas de
/// reportes genéricos y conserva los valores del backend sin recalcular stock.
class OrderInventoryDiagnosticTable extends StatelessWidget {
  const OrderInventoryDiagnosticTable({
    super.key,
    required this.rows,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _qty(Object? value) {
    if (value == null) return '—';
    final valueNum = _num(value);
    if (valueNum == valueNum.roundToDouble()) return valueNum.toInt().toString();
    return valueNum.toStringAsFixed(2);
  }

  String _status(Object? raw) {
    return switch ((raw ?? '').toString().toUpperCase()) {
      'PEDIR_AHORA' => 'Pedir ahora',
      'STOCK_NEGATIVO' => 'Stock negativo',
      'SOBRESTOCK' => 'Sobrestock',
      'SIN_CONFIGURAR' => 'Sin configurar',
      'STOCK_SUFICIENTE' => 'Stock suficiente',
      _ => 'Sin estado',
    };
  }

  Color _statusColor(Object? raw) {
    return switch ((raw ?? '').toString().toUpperCase()) {
      'PEDIR_AHORA' || 'STOCK_NEGATIVO' => palette.warning,
      'SOBRESTOCK' => palette.secondary,
      'SIN_CONFIGURAR' => palette.textSecondary,
      'STOCK_SUFICIENTE' => palette.success,
      _ => palette.textSecondary,
    };
  }

  Widget _pill(Object? status) {
    final tone = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.24)),
      ),
      child: Text(
        _status(status),
        style: TextStyle(color: tone, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _metric(String title, Object? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 5),
        Text(
          _qty(value),
          style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final status = row['estado_reposicion'];
    final name = (row['producto'] ?? 'Producto').toString();
    final suggested = _num(row['presentaciones_pedir']);
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.cardBorder),
        color: palette.background.withOpacity(0.34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              _pill(status),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _metric('Disponible', row['stock_actual'])),
              Expanded(child: _metric('Mínimo', row['stock_minimo'])),
              Expanded(child: _metric('Máximo', row['stock_maximo'])),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: palette.cardBorder, height: 1),
          const SizedBox(height: 11),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                suggested > 0
                    ? 'Sugerido: ' + _qty(row['presentaciones_pedir']) +
                        ' ' + (row['presentacion_compra'] ?? 'unidades').toString()
                    : 'No requiere compra sugerida',
                style: TextStyle(
                  color: suggested > 0 ? palette.secondary : palette.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_num(row['costo_pedido_estimado']) > 0)
                Text(
                  CurrencyUtils.format(_num(row['costo_pedido_estimado'])),
                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [for (final row in rows) _card(row)],
          );
        }

        const columns = <double>[280, 110, 110, 110, 165, 170, 145];
        const labels = <String>[
          'Producto',
          'Disponible',
          'Mínimo',
          'Máximo',
          'Estado',
          'Compra sugerida',
          'Costo estimado',
        ];
        final widths = <int, TableColumnWidth>{
          for (var i = 0; i < columns.length; i++) i: FixedColumnWidth(columns[i]),
        };
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: columns.fold<double>(0, (sum, width) => sum + width),
              child: Table(
                columnWidths: widths,
                border: TableBorder(
                  horizontalInside: BorderSide(color: palette.cardBorder),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11)),
                    children: [
                      for (final label in labels)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          child: Text(label,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              )),
                        ),
                    ],
                  ),
                  for (var i = 0; i < rows.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? palette.background.withOpacity(0.35)
                            : palette.surface.withOpacity(0.65),
                      ),
                      children: [
                        _cell((rows[i]['producto'] ?? 'Producto').toString(), bold: true),
                        _cell(_qty(rows[i]['stock_actual'])),
                        _cell(_qty(rows[i]['stock_minimo'])),
                        _cell(_qty(rows[i]['stock_maximo'])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: _pill(rows[i]['estado_reposicion']),
                        ),
                        _cell(_num(rows[i]['presentaciones_pedir']) > 0
                            ? _qty(rows[i]['presentaciones_pedir']) + ' ' +
                                (rows[i]['presentacion_compra'] ?? 'unidades').toString()
                            : '—'),
                        _cell(_num(rows[i]['costo_pedido_estimado']) > 0
                            ? CurrencyUtils.format(_num(rows[i]['costo_pedido_estimado']))
                            : '—', bold: true),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}
