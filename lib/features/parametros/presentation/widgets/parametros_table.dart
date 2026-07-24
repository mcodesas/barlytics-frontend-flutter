import 'package:flutter/material.dart';
import '../../data/models/parametros_response_model.dart';

class ParametrosTable extends StatelessWidget {
  const ParametrosTable({super.key, required this.items});
  final List<ParametrosResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
