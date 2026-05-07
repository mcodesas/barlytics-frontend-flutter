import 'package:flutter/material.dart';
import '../../data/models/productos_response_model.dart';

class ProductosTable extends StatelessWidget {
  const ProductosTable({super.key, required this.items});
  final List<ProductosResponseModel> items;

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [DataColumn(label: Text('ID')), DataColumn(label: Text('Resumen'))],
        rows: items.map((item) => DataRow(cells: [DataCell(Text('${item.id ?? '-'}')), DataCell(Text(item.label()))])).toList(),
      );
}
