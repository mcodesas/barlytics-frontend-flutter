import 'package:flutter/material.dart';
import '../../data/models/opciones_menu_response_model.dart';

class OpcionesMenuTable extends StatelessWidget {
  const OpcionesMenuTable({super.key, required this.items});
  final List<OpcionesMenuResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
