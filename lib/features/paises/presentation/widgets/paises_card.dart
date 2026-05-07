import 'package:flutter/material.dart';
import '../../data/models/paises_response_model.dart';

class PaisesCard extends StatelessWidget {
  const PaisesCard({super.key, required this.item, this.onTap});
  final PaisesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Paises' : item.label()),
          onTap: onTap,
        ),
      );
}
