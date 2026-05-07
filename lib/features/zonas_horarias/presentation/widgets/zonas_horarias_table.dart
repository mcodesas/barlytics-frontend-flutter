import 'package:flutter/material.dart';
import '../../data/models/zonas_horarias_response_model.dart';

class ZonasHorariasTable extends StatelessWidget {
  const ZonasHorariasTable({super.key, required this.items});
  final List<ZonasHorariasResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
