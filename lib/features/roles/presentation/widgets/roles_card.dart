import 'package:flutter/material.dart';
import '../../data/models/roles_response_model.dart';

class RolesCard extends StatelessWidget {
  const RolesCard({super.key, required this.item, this.onTap});
  final RolesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Roles' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
