import 'package:flutter/material.dart';
import '../../data/models/detalle_cuenta_venta_response_model.dart';

class DetalleCuentaVentaTable extends StatelessWidget {
  const DetalleCuentaVentaTable({super.key, required this.items});
  final List<DetalleCuentaVentaResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
