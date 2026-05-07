import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_detail_page.dart';

class MarcasDetailPage extends StatelessWidget {
  const MarcasDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => DynamicCrudDetailPage(config: marcasConfig, id: id);
}
