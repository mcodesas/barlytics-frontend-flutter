import 'package:flutter/material.dart';
import '../../data/models/reportes_response_model.dart';

class ReportesTable extends StatelessWidget {
  const ReportesTable({super.key, required this.items});
  final List<ReportesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
