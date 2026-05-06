import 'package:flutter/material.dart';
import '../../data/models/productos_response_model.dart';

class ProductosCard extends StatelessWidget {
  const ProductosCard({super.key, required this.item, this.onTap});
  final ProductosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Productos' : item.label()),
          onTap: onTap,
        ),
      );
}
