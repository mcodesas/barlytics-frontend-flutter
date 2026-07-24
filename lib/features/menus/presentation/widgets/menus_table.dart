import 'package:flutter/material.dart';
import '../../data/models/menus_response_model.dart';

class MenusTable extends StatelessWidget {
  const MenusTable({super.key, required this.items});
  final List<MenusResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
