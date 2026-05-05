import 'package:flutter/material.dart';
import '../../data/models/regiones_response_model.dart';

class RegionesCard extends StatelessWidget {
  const RegionesCard({super.key, required this.item, this.onTap});
  final RegionesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Regiones' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
