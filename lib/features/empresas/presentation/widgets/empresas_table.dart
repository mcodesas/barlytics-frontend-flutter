import 'package:flutter/material.dart';
import '../../data/models/empresas_response_model.dart';

class EmpresasTable extends StatelessWidget {
  const EmpresasTable({super.key, required this.items});
  final List<EmpresasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
