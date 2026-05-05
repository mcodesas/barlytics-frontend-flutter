import 'package:flutter/material.dart';
import '../../data/models/monedas_response_model.dart';

class MonedasCard extends StatelessWidget {
  const MonedasCard({super.key, required this.item, this.onTap});
  final MonedasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Monedas' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
