import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';

class MovimientosFormPage extends StatelessWidget {
  const MovimientosFormPage({
    super.key,
    this.id,
    this.initialValues = const <String, dynamic>{},
  });

  final String? id;
  final Map<String, dynamic> initialValues;

  @override
  Widget build(BuildContext context) => DynamicCrudFormPage(
        config: movimientosConfig,
        id: id,
        initialValues: initialValues,
      );
}
