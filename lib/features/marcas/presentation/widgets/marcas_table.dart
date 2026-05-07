import 'package:flutter/material.dart';
import '../../data/models/marcas_response_model.dart';

class MarcasTable extends StatelessWidget {
  const MarcasTable({super.key, required this.items});
  final List<MarcasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
