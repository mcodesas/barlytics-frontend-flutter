import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';

class ReportesPage extends ConsumerWidget {
  const ReportesPage({super.key});

  static const endpoints = <String, String>{
    'Ventas por fecha': '/api/v1/reportes/ventas',
    'Ventas por medio de pago': '/api/v1/reportes/ventas/medio-pago',
    'Stock actual': '/api/v1/reportes/stock-actual',
    'Productos más vendidos': '/api/v1/reportes/productos-mas-vendidos',
    'Movimientos de inventario': '/api/v1/reportes/movimientos-inventario',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Reportes')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in endpoints.entries)
              Card(
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReporteDetail(title: entry.key, path: entry.value))),
                ),
              ),
          ],
        ),
      );
}

class _ReporteDetail extends ConsumerWidget {
  const _ReporteDetail({required this.title, required this.path});
  final String title;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: api.get<List<dynamic>>(path, (json) => json is List ? json : <dynamic>[]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const AppLoader();
          if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString());
          final data = snapshot.data?.data ?? const [];
          if (data.isEmpty) return const Center(child: Text('Sin datos para mostrar'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) => Card(child: ListTile(title: Text(data[index].toString()))),
          );
        },
      ),
    );
  }
}
