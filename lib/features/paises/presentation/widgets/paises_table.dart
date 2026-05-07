import 'package:flutter/material.dart';
import '../../data/models/paises_response_model.dart';

class PaisesTable extends StatelessWidget {
  const PaisesTable({super.key, required this.items});
  final List<PaisesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
