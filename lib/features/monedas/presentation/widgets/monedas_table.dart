import 'package:flutter/material.dart';
import '../../data/models/monedas_response_model.dart';

class MonedasTable extends StatelessWidget {
  const MonedasTable({super.key, required this.items});
  final List<MonedasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
