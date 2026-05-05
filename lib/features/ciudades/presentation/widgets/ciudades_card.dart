import 'package:flutter/material.dart';
import '../../data/models/ciudades_response_model.dart';

class CiudadesCard extends StatelessWidget {
  const CiudadesCard({super.key, required this.item, this.onTap});
  final CiudadesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Ciudades' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
