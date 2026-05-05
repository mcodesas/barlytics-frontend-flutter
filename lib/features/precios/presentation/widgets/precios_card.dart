import 'package:flutter/material.dart';
import '../../data/models/precios_response_model.dart';

class PreciosCard extends StatelessWidget {
  const PreciosCard({super.key, required this.item, this.onTap});
  final PreciosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Precios' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
