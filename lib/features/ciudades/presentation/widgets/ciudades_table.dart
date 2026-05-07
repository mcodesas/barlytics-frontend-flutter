import 'package:flutter/material.dart';
import '../../data/models/ciudades_response_model.dart';

class CiudadesTable extends StatelessWidget {
  const CiudadesTable({super.key, required this.items});
  final List<CiudadesResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
