import 'package:flutter/material.dart';
import '../../data/models/pagos_response_model.dart';

class PagosTable extends StatelessWidget {
  const PagosTable({super.key, required this.items});
  final List<PagosResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
