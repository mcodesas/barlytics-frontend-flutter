import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/network/api_response.dart';
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
    'Cruce inventario vs ventas': '/api/v1/reportes/inventario/cruce-ventas',
    'Productos desfalcados': '/api/v1/reportes/inventario/productos-desfalcados',
    'Desfalcos por persona': '/api/v1/reportes/inventario/productos-desfalcados/persona',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final visual = ModuleVisuals.byKey('reportes');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ReportsToolbar(
                  total: endpoints.length,
                  palette: palette,
                  icon: visual.icon,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width < 680 ? 1 : width < 1120 ? 2 : 3;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: columns == 1 ? 128 : 142,
                      ),
                      itemCount: endpoints.length,
                      itemBuilder: (context, index) {
                        final entry = endpoints.entries.elementAt(index);
                        return _ReportCard(
                          title: entry.key,
                          path: entry.value,
                          palette: palette,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportsToolbar extends StatelessWidget {
  const _ReportsToolbar({
    required this.total,
    required this.palette,
    required this.icon,
  });

  final int total;
  final AppPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
              palette.secondary.withOpacity(palette.darkBackground ? 0.13 : 0.07),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.translucentBorder),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow,
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final heading = Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: palette.onPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Centro de reportes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecciona el indicador que deseas consultar. Los reportes con fecha se abren inicialmente con la información de hoy.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final counter = Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.44 : 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Text(
                '$total reportes disponibles',
                style: TextStyle(
                  color: palette.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 14), counter],
              );
            }

            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 18),
                counter,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.path,
    required this.palette,
  });

  final String title;
  final String path;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ReporteDetail(title: title, path: path),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
                palette.secondary.withOpacity(palette.darkBackground ? 0.10 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow.withOpacity(0.72),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: palette.secondary.withOpacity(0.18)),
                ),
                child: Icon(Icons.query_stats_rounded, color: palette.secondary, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _reportDescription(path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: palette.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReporteDetail extends ConsumerStatefulWidget {
  const _ReporteDetail({required this.title, required this.path});

  final String title;
  final String path;

  @override
  ConsumerState<_ReporteDetail> createState() => _ReporteDetailState();
}

class _ReporteDetailState extends ConsumerState<_ReporteDetail> {
  late Future<ApiResponse<List<dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ApiResponse<List<dynamic>>> _load() {
    final api = ref.read(apiClientProvider);
    return api.get<List<dynamic>>(
      _reportPathWithDefaultDates(widget.path),
      (json) => json is List ? json : <dynamic>[],
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.98),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver a reportes',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: palette.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.analytics_rounded, color: palette.secondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'Información consultada para la fecha actual',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualizar reporte',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          color: palette.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<ApiResponse<List<dynamic>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const AppLoader(message: 'Consultando reporte...');
                      }
                      if (snapshot.hasError) {
                        return AppErrorView(
                          message: snapshot.error.toString(),
                          onRetry: _refresh,
                        );
                      }
                      final response = snapshot.data;
                      final data = response?.data ?? const <dynamic>[];
                      if (data.isEmpty) {
                        return const AppEmptyView(message: 'El reporte no tiene datos disponibles.');
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _ReportRecordCard(
                          index: index,
                          value: data[index],
                          palette: palette,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRecordCard extends StatelessWidget {
  const _ReportRecordCard({
    required this.index,
    required this.value,
    required this.palette,
  });

  final int index;
  final dynamic value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final entries = value is Map
        ? Map<String, dynamic>.from(value as Map).entries.toList(growable: false)
        : <MapEntry<String, dynamic>>[MapEntry('Valor', value)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Registro ${index + 1}',
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 18, color: palette.cardBorder),
            _ReportValueRow(entry: entries[i], palette: palette),
          ],
        ],
      ),
    );
  }
}

class _ReportValueRow extends StatelessWidget {
  const _ReportValueRow({required this.entry, required this.palette});

  final MapEntry<String, dynamic> entry;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final label = Text(
          _humanize(entry.key),
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
        final value = Text(
          _displayValue(entry.value),
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 4), value],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 190, child: label),
            const SizedBox(width: 16),
            Expanded(child: value),
          ],
        );
      },
    );
  }
}

String _reportPathWithDefaultDates(String path) {
  final today = DateTime.now();
  final date = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  final needsDates = path.contains('/ventas') ||
      path.contains('/productos-mas-vendidos') ||
      path.contains('/movimientos-inventario') ||
      path.contains('/inventario/cruce-ventas') ||
      path.contains('/inventario/productos-desfalcados');
  if (!needsDates || path.contains('?')) return path;
  return '$path?inicio=$date&fin=$date';
}

String _reportDescription(String path) {
  if (path.contains('medio-pago')) return 'Distribución del recaudo por forma de pago.';
  if (path.contains('stock-actual')) return 'Existencias disponibles por producto y sucursal.';
  if (path.contains('productos-mas-vendidos')) return 'Ranking de productos por cantidad vendida.';
  if (path.contains('movimientos-inventario')) return 'Entradas, salidas y ajustes registrados.';
  if (path.contains('cruce-ventas')) return 'Comparación entre inventario y consumo vendido.';
  if (path.contains('persona')) return 'Diferencias de inventario agrupadas por responsable.';
  if (path.contains('desfalcados')) return 'Productos con diferencias que requieren revisión.';
  return 'Resumen de ventas registradas durante el periodo.';
}

String _humanize(String value) {
  final spaced = value
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}')
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return 'Dato';
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _displayValue(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Sí' : 'No';
  if (value is Iterable) return value.map(_displayValue).join(', ');
  if (value is Map) {
    return Map<String, dynamic>.from(value as Map)
        .entries
        .map((entry) => '${_humanize(entry.key)}: ${_displayValue(entry.value)}')
        .join(' · ');
  }
  final text = value.toString().trim();
  return text.isEmpty ? '—' : text;
}
