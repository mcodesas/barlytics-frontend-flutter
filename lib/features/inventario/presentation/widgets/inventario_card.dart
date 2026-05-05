import 'package:flutter/material.dart';
import '../../data/models/inventario_response_model.dart';

class InventarioCard extends StatelessWidget {
  const InventarioCard({super.key, required this.item, this.onTap});
  final InventarioResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Inventario' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
