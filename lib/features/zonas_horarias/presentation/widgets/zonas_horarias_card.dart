import 'package:flutter/material.dart';
import '../../data/models/zonas_horarias_response_model.dart';

class ZonasHorariasCard extends StatelessWidget {
  const ZonasHorariasCard({super.key, required this.item, this.onTap});
  final ZonasHorariasResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Zonas horarias' : item.label()),
          onTap: onTap,
        ),
      );
}
