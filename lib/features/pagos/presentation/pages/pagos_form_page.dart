import 'package:flutter/material.dart';

import 'pagos_list_page.dart';

/// El registro de pagos se realiza en el panel inferior del centro de pagos.
class PagosFormPage extends StatelessWidget {
  const PagosFormPage({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) => PagosListPage(
        openCreateOnStart: id == null,
        initialPaymentId: int.tryParse(id ?? ''),
      );
}
