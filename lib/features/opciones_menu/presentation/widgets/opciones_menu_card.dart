import 'package:flutter/material.dart';
import '../../data/models/opciones_menu_response_model.dart';

class OpcionesMenuCard extends StatelessWidget {
  const OpcionesMenuCard({super.key, required this.item, this.onTap});
  final OpcionesMenuResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Opciones menu' : item.label()),
          onTap: onTap,
        ),
      );
}
