import 'package:flutter/material.dart';

import 'pagos_list_page.dart';

/// La consulta detallada se abre desde el panel inferior del centro de pagos.
class PagosDetailPage extends StatelessWidget {
  const PagosDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => PagosListPage(initialPaymentId: int.tryParse(id));
}
