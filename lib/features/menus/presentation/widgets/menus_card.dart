import 'package:flutter/material.dart';
import '../../data/models/menus_response_model.dart';

class MenusCard extends StatelessWidget {
  const MenusCard({super.key, required this.item, this.onTap});
  final MenusResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Menus' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
