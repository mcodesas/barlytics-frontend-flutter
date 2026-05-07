import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_detail_page.dart';

class OpcionesMenuDetailPage extends StatelessWidget {
  const OpcionesMenuDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DynamicCrudDetailPage(config: opcionesmenuConfig, id: id);
}
