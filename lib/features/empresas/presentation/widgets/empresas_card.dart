import 'package:flutter/material.dart';
import '../../data/models/empresas_response_model.dart';

class EmpresasCard extends StatelessWidget {
  const EmpresasCard({super.key, required this.item, this.onTap});
  final EmpresasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Empresas' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
