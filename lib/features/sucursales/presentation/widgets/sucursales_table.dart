import 'package:flutter/material.dart';
import '../../data/models/sucursales_response_model.dart';

class SucursalesTable extends StatelessWidget {
  const SucursalesTable({super.key, required this.items});
  final List<SucursalesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
