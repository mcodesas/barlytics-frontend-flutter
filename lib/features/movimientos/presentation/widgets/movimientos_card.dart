import 'package:flutter/material.dart';
import '../../data/models/movimientos_response_model.dart';

class MovimientosCard extends StatelessWidget {
  const MovimientosCard({super.key, required this.item, this.onTap});
  final MovimientosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Movimientos' : item.label()),
          onTap: onTap,
        ),
      );
}
