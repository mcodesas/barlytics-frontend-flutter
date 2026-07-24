import 'package:flutter/material.dart';
import '../../data/models/reportes_response_model.dart';

class ReportesCard extends StatelessWidget {
  const ReportesCard({super.key, required this.item, this.onTap});
  final ReportesResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Reportes' : item.label()),
          onTap: onTap,
        ),
      );
}
