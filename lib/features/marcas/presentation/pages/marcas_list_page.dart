import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_list_page.dart';

class MarcasListPage extends StatelessWidget {
  const MarcasListPage({super.key});

  @override
  Widget build(BuildContext context) => DynamicCrudListPage(config: marcasConfig);
}
