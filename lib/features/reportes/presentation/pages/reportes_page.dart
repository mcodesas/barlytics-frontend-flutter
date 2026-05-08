import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

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
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = ModuleVisuals.byKey('reportes');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            foregroundColor: Colors.white,
            expandedHeight: 210,
            title: const Text('Reportes'),
            flexibleSpace: FlexibleSpaceBar(
              background: TechBackground(
                padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [visual.color, AppColors.tertiary]), borderRadius: BorderRadius.circular(25)),
                      child: Icon(visual.icon, color: Colors.white, size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Reportes e indicadores', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('Consulta información operativa de ventas, pagos e inventario.', style: TextStyle(color: Colors.white.withOpacity(0.76), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width < 700 ? 1 : MediaQuery.sizeOf(context).width < 1100 ? 2 : 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: MediaQuery.sizeOf(context).width < 700 ? 3.2 : 2.2,
              ),
              itemCount: endpoints.length,
              itemBuilder: (context, index) {
                final entry = endpoints.entries.elementAt(index);
                return _ReportCard(title: entry.key, path: entry.value, color: visual.color);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.path, required this.color});
  final String title;
  final String path;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReporteDetail(title: title, path: path, color: color))),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border), gradient: LinearGradient(colors: [Colors.white, color.withOpacity(0.06)])),
            child: Row(
              children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, AppColors.tertiary]), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.query_stats_rounded, color: Colors.white, size: 30)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                ])),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      );
}

class _ReporteDetail extends ConsumerWidget {
  const _ReporteDetail({required this.title, required this.path, required this.color});
  final String title;
  final String path;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: api.get<List<dynamic>>(path, (json) => json is List ? json : <dynamic>[]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const AppLoader();
          if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString());
          final data = snapshot.data?.data ?? const [];
          if (data.isEmpty) return const AppEmptyView(message: 'El reporte no tiene datos disponibles.');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) => Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withOpacity(0.14), child: Icon(Icons.analytics_outlined, color: color)),
                title: Text('Registro ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(data[index].toString(), maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            ),
          );
        },
      ),
    );
  }
}
