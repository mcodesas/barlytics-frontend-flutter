import 'package:flutter/material.dart';
import '../../data/models/mesas_response_model.dart';

class MesasCard extends StatelessWidget {
  const MesasCard({super.key, required this.item, this.onTap});
  final MesasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Mesas' : item.label()),
          onTap: onTap,
        ),
      );
}
