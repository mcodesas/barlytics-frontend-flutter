import 'package:flutter/material.dart';
import '../../data/models/tipos_producto_response_model.dart';

class TiposProductoTable extends StatelessWidget {
  const TiposProductoTable({super.key, required this.items});
  final List<TiposProductoResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
