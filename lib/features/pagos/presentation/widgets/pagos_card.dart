import 'package:flutter/material.dart';
import '../../data/models/pagos_response_model.dart';

class PagosCard extends StatelessWidget {
  const PagosCard({super.key, required this.item, this.onTap});
  final PagosResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Pagos' : item.label()),
          onTap: onTap,
        ),
      );
}
