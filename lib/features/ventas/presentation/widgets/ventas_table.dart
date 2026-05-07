import 'package:flutter/material.dart';
import '../../data/models/ventas_response_model.dart';

class VentasTable extends StatelessWidget {
  const VentasTable({super.key, required this.items});
  final List<VentasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
