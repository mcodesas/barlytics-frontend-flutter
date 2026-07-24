import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';

class CiudadesFormPage extends StatelessWidget {
  const CiudadesFormPage({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) => DynamicCrudFormPage(config: ciudadesConfig, id: id);
}
