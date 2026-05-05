import 'package:flutter/material.dart';
import '../../data/models/mesas_response_model.dart';

class MesasTable extends StatelessWidget {
  const MesasTable({super.key, required this.items});
  final List<MesasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
