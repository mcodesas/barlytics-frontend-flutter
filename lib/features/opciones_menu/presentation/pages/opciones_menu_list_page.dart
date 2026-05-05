import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_list_page.dart';

class OpcionesMenuListPage extends StatelessWidget {
  const OpcionesMenuListPage({super.key});

  @override
  Widget build(BuildContext context) => DynamicCrudListPage(config: opcionesmenuConfig);
}
