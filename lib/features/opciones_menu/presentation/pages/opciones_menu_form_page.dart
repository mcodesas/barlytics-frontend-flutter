import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';

class OpcionesMenuFormPage extends StatelessWidget {
  const OpcionesMenuFormPage({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) => DynamicCrudFormPage(config: opcionesmenuConfig, id: id);
}
