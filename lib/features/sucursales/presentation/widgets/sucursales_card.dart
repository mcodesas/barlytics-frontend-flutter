import 'package:flutter/material.dart';
import '../../data/models/sucursales_response_model.dart';

class SucursalesCard extends StatelessWidget {
  const SucursalesCard({super.key, required this.item, this.onTap});
  final SucursalesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Sucursales' : item.label()),
          onTap: onTap,
        ),
      );
}
