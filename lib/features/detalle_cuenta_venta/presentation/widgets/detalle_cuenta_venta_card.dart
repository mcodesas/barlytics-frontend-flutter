import 'package:flutter/material.dart';
import '../../data/models/detalle_cuenta_venta_response_model.dart';

class DetalleCuentaVentaCard extends StatelessWidget {
  const DetalleCuentaVentaCard({super.key, required this.item, this.onTap});
  final DetalleCuentaVentaResponseModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(item.label().isEmpty ? 'Detalle cuenta venta' : item.label()),
          onTap: onTap,
        ),
      );
}
