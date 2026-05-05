import 'package:flutter/material.dart';
import '../../data/models/marcas_response_model.dart';

class MarcasCard extends StatelessWidget {
  const MarcasCard({super.key, required this.item, this.onTap});
  final MarcasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Marcas' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
