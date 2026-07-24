import 'package:flutter/material.dart';
import '../../data/models/regiones_response_model.dart';

class RegionesTable extends StatelessWidget {
  const RegionesTable({super.key, required this.items});
  final List<RegionesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
