import 'package:flutter/material.dart';
import '../../data/models/ventas_response_model.dart';

class VentasCard extends StatelessWidget {
  const VentasCard({super.key, required this.item, this.onTap});
  final VentasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Ventas' : item.label()),
          onTap: onTap,
        ),
      );
}
