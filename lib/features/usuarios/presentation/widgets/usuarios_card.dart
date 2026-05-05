import 'package:flutter/material.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuariosCard extends StatelessWidget {
  const UsuariosCard({super.key, required this.item, this.onTap});
  final UsuariosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Usuarios' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
