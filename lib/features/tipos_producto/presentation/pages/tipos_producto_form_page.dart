import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';

class TiposProductoFormPage extends StatelessWidget {
  const TiposProductoFormPage({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) => DynamicCrudFormPage(config: tiposproductoConfig, id: id);
}
