import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_detail_page.dart';

class DetalleCuentaVentaDetailPage extends StatelessWidget {
  const DetalleCuentaVentaDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DynamicCrudDetailPage(config: detallecuentaventaConfig, id: id);
}
