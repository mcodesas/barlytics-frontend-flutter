import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Dashboard preparado para consumir reportes de ventas, inventario y productos más vendidos.'),
        ),
      );
}
