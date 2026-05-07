import 'package:flutter/material.dart';
import '../../data/models/parametros_response_model.dart';

class ParametrosCard extends StatelessWidget {
  const ParametrosCard({super.key, required this.item, this.onTap});
  final ParametrosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Parametros' : item.label()),
          onTap: onTap,
        ),
      );
}
