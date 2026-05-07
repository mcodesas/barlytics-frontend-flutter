import 'package:flutter/material.dart';
import '../../data/models/roles_response_model.dart';

class RolesTable extends StatelessWidget {
  const RolesTable({super.key, required this.items});
  final List<RolesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
