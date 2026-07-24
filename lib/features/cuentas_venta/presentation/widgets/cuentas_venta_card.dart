import 'package:flutter/material.dart';
import '../../data/models/cuentas_venta_response_model.dart';

class CuentasVentaCard extends StatelessWidget {
  const CuentasVentaCard({super.key, required this.item, this.onTap});
  final CuentasVentaResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Cuentas venta' : item.label()),
          onTap: onTap,
        ),
      );
}
