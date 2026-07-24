import 'package:flutter/material.dart';
import '../../data/models/precios_response_model.dart';

class PreciosTable extends StatelessWidget {
  const PreciosTable({super.key, required this.items});
  final List<PreciosResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
