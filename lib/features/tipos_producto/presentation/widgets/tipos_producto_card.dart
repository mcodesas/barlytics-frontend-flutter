import 'package:flutter/material.dart';
import '../../data/models/tipos_producto_response_model.dart';

class TiposProductoCard extends StatelessWidget {
  const TiposProductoCard({super.key, required this.item, this.onTap});
  final TiposProductoResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Tipos producto' : item.label()),
          onTap: onTap,
        ),
      );
}
