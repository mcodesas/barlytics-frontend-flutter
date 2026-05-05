import 'package:flutter/material.dart';
import '../../data/models/medios_pago_response_model.dart';

class MediosPagoCard extends StatelessWidget {
  const MediosPagoCard({super.key, required this.item, this.onTap});
  final MediosPagoResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Medios pago' : item.label()),
          subtitle: Text('ID: ${item.id ?? '-'}'),
          onTap: onTap,
        ),
      );
}
