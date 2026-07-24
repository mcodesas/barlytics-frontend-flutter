import 'package:flutter/material.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuariosTable extends StatelessWidget {
  const UsuariosTable({super.key, required this.items});
  final List<UsuariosResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
