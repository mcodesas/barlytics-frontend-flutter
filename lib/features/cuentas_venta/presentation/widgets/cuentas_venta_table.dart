import 'package:flutter/material.dart';
import '../../data/models/cuentas_venta_response_model.dart';

class CuentasVentaTable extends StatelessWidget {
  const CuentasVentaTable({super.key, required this.items});
  final List<CuentasVentaResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
