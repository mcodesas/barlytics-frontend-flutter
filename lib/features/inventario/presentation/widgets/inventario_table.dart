import 'package:flutter/material.dart';
import '../../data/models/inventario_response_model.dart';

class InventarioTable extends StatelessWidget {
  const InventarioTable({super.key, required this.items});
  final List<InventarioResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
