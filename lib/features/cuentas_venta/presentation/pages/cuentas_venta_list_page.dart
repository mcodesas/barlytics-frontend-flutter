import 'package:flutter/material.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_list_page.dart';

class CuentasVentaListPage extends StatelessWidget {
  const CuentasVentaListPage({super.key});

  @override
  Widget build(BuildContext context) => DynamicCrudListPage(config: cuentasventaConfig);
}
