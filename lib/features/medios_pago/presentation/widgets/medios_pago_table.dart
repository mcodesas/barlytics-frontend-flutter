import 'package:flutter/material.dart';
import '../../data/models/medios_pago_response_model.dart';

class MediosPagoTable extends StatelessWidget {
  const MediosPagoTable({super.key, required this.items});
  final List<MediosPagoResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
