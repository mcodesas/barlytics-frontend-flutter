import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../services/reporte_pdf_service.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

class ReportesPage extends ConsumerWidget {
  const ReportesPage({super.key}) : _initialKey = null;

  const ReportesPage.ganancias({super.key})
      : _initialKey = 'ganancias';

  const ReportesPage.proximoPedido({super.key})
      : _initialKey = 'proximo_pedido';

  const ReportesPage.reporte({
    super.key,
    required String keyName,
  }) : _initialKey = keyName;

  final String? _initialKey;

  static const reports = <_ReportDefinition>[
    _ReportDefinition(
      keyName: 'reporte_resumen_ejecutivo',
      title: 'Resumen ejecutivo',
      description: 'Panorama integral del negocio: ventas, rentabilidad neta, gastos, recaudo, productos e inventario.',
      path: '/api/v1/reportes/resumen',
      icon: Icons.dashboard_customize_rounded,
      requiresDates: true,
      summary: true,
      chartLabelKey: 'fecha',
      chartValueKey: 'total',
      currencyKeys: [
        'total_vendido',
        'total_propinas',
        'ticket_promedio',
        'total',
        'ingresos_periodo',
        'costo_ventas_periodo',
        'ganancia_bruta_periodo',
        'gastos_fijos_periodo',
        'gastos_turno_periodo',
        'salidas_caja_periodo',
        'pagos_pedidos_periodo',
        'pagos_gastos_configurados_periodo',
        'gastos_variables_periodo',
        'mano_obra_periodo',
        'gastos_operativos_periodo',
        'ganancia_neta_estimada_periodo',
      ],
      percentageKeys: [
        'margen_bruto_porcentaje',
        'margen_neto_porcentaje',
      ],
    ),
    _ReportDefinition(
      keyName: 'reporte_ventas_fecha',
      title: 'Ventas por fecha',
      description: 'Identifica los días fuertes y débiles, el ticket promedio y cómo evoluciona la venta en el periodo.',
      path: '/api/v1/reportes/ventas',
      icon: Icons.show_chart_rounded,
      requiresDates: true,
      chartLabelKey: 'fecha',
      chartValueKey: 'total',
      currencyKeys: ['subtotal_productos', 'propinas', 'total', 'ticket_promedio'],
    ),
    _ReportDefinition(
      keyName: 'reporte_ventas_medio_pago',
      title: 'Ventas por medio de pago',
      description: 'Entiende por dónde entra el dinero y detecta concentración o dependencia de un medio de pago.',
      path: '/api/v1/reportes/ventas/medio-pago',
      icon: Icons.account_balance_wallet_rounded,
      requiresDates: true,
      chartLabelKey: 'medio_pago',
      chartValueKey: 'total',
      currencyKeys: ['total'],
      percentageKeys: ['porcentaje'],
    ),
    _ReportDefinition(
      keyName: 'reporte_stock_actual',
      title: 'Stock actual',
      description: 'Controla disponibilidad, mínimos, agotados, sobrestock y productos sin parámetros de inventario.',
      path: '/api/v1/reportes/stock-actual',
      icon: Icons.inventory_2_rounded,
      chartLabelKey: 'producto',
      chartValueKey: 'unidades',
      percentageKeys: ['salud_inventario_porcentaje'],
    ),
    _ReportDefinition(
      keyName: 'ganancias',
      title: 'Ganancias',
      description: 'Mide utilidad real después de costo de venta, gastos fijos, variables y mano de obra.',
      path: '/api/v1/reportes/inventario/ganancias-pedido',
      icon: Icons.trending_up,
      requiresDates: true,
      kind: _ReportKind.profit,
      chartLabelKey: 'producto',
      chartValueKey: 'ganancia_bruta_periodo',
      currencyKeys: [
        'precio_venta_actual',
        'costo_unitario_actual',
        'ganancia_unitaria_actual',
        'ingresos_periodo',
        'costo_ventas_periodo',
        'ganancia_bruta_periodo',
        'gastos_fijos_periodo',
        'gastos_turno_periodo',
        'gastos_variables_periodo',
        'mano_obra_periodo',
        'gastos_operativos_periodo',
        'ganancia_neta_estimada_periodo',
      ],
      percentageKeys: [
        'margen_bruto_porcentaje',
        'margen_neto_porcentaje',
      ],
    ),
    _ReportDefinition(
      keyName: 'proximo_pedido',
      title: 'Próximo pedido',
      description: 'Convierte el estado del inventario en una propuesta de compra con cantidades y costo estimado.',
      path: '/api/v1/reportes/inventario/ganancias-pedido',
      icon: Icons.local_shipping_rounded,
      requiresDates: true,
      showDateFilter: false,
      kind: _ReportKind.nextOrder,
      chartLabelKey: 'producto',
      chartValueKey: 'unidades_pedir',
      currencyKeys: [
        'costo_presentacion_actual',
        'costo_pedido_estimado',
      ],
    ),
    _ReportDefinition(
      keyName: 'reporte_cruce_conteo',
      title: 'Cruce de conteo físico',
      description: 'Detecta diferencias físicas, cuantifica su impacto económico y prioriza investigaciones de inventario.',
      path: '/api/v1/reportes/inventario/cruce-conteo',
      icon: Icons.fact_check_rounded,
      requiresDates: true,
      chartLabelKey: 'producto',
      chartValueKey: 'diferencia_unidades',
      currencyKeys: ['costo_unitario', 'diferencia_valor_compra', 'valor_faltantes', 'valor_sobrantes'],
      percentageKeys: ['diferencia_porcentaje'],
      signedChart: true,
    ),
    _ReportDefinition(
      keyName: 'reporte_productos_mas_vendidos',
      title: 'Productos más vendidos',
      description: 'Descubre qué productos impulsan volumen e ingresos y cuánto concentran las ventas del periodo.',
      path: '/api/v1/reportes/productos-mas-vendidos',
      icon: Icons.emoji_events_rounded,
      requiresDates: true,
      chartLabelKey: 'producto',
      chartValueKey: 'cantidad',
      currencyKeys: ['total', 'precio_promedio'],
      percentageKeys: ['concentracion_top_3_porcentaje'],
    ),
    _ReportDefinition(
      keyName: 'reporte_movimientos_inventario',
      title: 'Movimientos de inventario',
      description: 'Audita el flujo de inventario, identifica ajustes y rastrea quién registró cada movimiento.',
      path: '/api/v1/reportes/movimientos-inventario',
      icon: Icons.swap_vert_circle_rounded,
      requiresDates: true,
      chartLabelKey: 'tipo_movimiento',
      chartValueKey: 'cantidad_unidades',
    ),
    _ReportDefinition(
      keyName: 'reporte_rotacion_inventario',
      title: 'Rotación de inventario',
      description: 'Detecta productos que rotan, los que se estancan y los que requieren reposición o revisión.',
      path: '/api/v1/reportes/inventario/cruce-ventas',
      icon: Icons.sync_alt_rounded,
      requiresDates: true,
      chartLabelKey: 'producto',
      chartValueKey: 'rotacion_porcentaje',
      currencyKeys: ['valor_vendido'],
      percentageKeys: [
        'rotacion_porcentaje',
        'rotacion_promedio_porcentaje',
      ],
    ),
    _ReportDefinition(
      keyName: 'reporte_alertas_inventario',
      title: 'Alertas de inventario',
      description: 'Prioriza productos con riesgo operativo: stock negativo, agotados con demanda y ventas comprometidas.',
      path: '/api/v1/reportes/inventario/productos-desfalcados',
      icon: Icons.warning_amber_rounded,
      requiresDates: true,
      chartLabelKey: 'producto',
      chartValueKey: 'ventas_periodo',
      currencyKeys: [
        'valor_vendido',
        'valor_vendido_en_riesgo',
      ],
      percentageKeys: ['rotacion_porcentaje'],
    ),
    _ReportDefinition(
      keyName: 'reporte_salidas_responsable',
      title: 'Salidas por responsable',
      description: 'Facilita control y trazabilidad de salidas para detectar concentraciones o comportamientos atípicos.',
      path: '/api/v1/reportes/inventario/productos-desfalcados/persona',
      icon: Icons.manage_accounts_rounded,
      requiresDates: true,
      chartLabelKey: 'responsable',
      chartValueKey: 'unidades_salida',
      percentageKeys: ['concentracion_principal_porcentaje'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(planCapabilitiesProvider).valueOrNull;
    if (entitlement != null && !entitlement.includes('REPORTES_OPERATIVOS')) {
      return const _PlanFeatureBlocked();
    }
    if (_initialKey != null) {
      final definition = reports.firstWhere(
        (item) => item.keyName == _initialKey,
      );
      return _ReporteDetail(
        definition: definition,
        standalone: true,
      );
    }

    final catalogReports = reports.toList(growable: false);
    final palette = ref.watch(selectedAppPaletteProvider);
    final visual = ModuleVisuals.byKey('reportes');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ReportsToolbar(
                  total: catalogReports.length,
                  palette: palette,
                  icon: visual.icon,
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final columns = width < 680
                              ? 1
                              : width < 1020
                                  ? 2
                                  : 3;
                          const spacing = 12.0;
                          final cardWidth =
                              (width - (columns - 1) * spacing) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final definition in catalogReports)
                                SizedBox(
                                  width: cardWidth,
                                  child: _ReportCard(
                                    definition: definition,
                                    palette: palette,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanFeatureBlocked extends StatelessWidget {
  const _PlanFeatureBlocked();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AppEmptyView(
            message: 'Los reportes operativos no están incluidos en tu plan actual. Puedes habilitarlos cambiando de plan.',
          ),
        ),
      );
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: palette.panelDecoration(
              baseRadius: 28,
              tint: palette.secondary,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final heading = Row(
                  children: [
                    Container(
                      width: compact ? 48 : 54,
                      height: compact ? 48 : 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        icon,
                        color: palette.onPrimary,
                        size: compact ? 24 : 27,
                      ),
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
                            'Ventas, rentabilidad, gastos, inventario, recaudo y trazabilidad convertidos en información para decidir.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              fontSize: 12,
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
                    color: palette.secondary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.secondary.withOpacity(0.20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_rounded, color: palette.secondary, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        '$total reportes',
                        style: TextStyle(
                          color: palette.secondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.definition, required this.palette});

  final _ReportDefinition definition;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(definition.keyName);
    final accent = visual.color;
    final area = _reportAreaLabel(definition);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(palette.radius(22)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ReporteDetail(definition: definition),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: palette.panelDecoration(
            baseRadius: 22,
            tint: accent,
            elevated: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: accent.withOpacity(0.20),
                      ),
                    ),
                    child: Icon(
                      definition.icon,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      definition.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.actionColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: palette.actionColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                definition.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.09),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(.18)),
                  ),
                  child: Text(
                    area,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _ReportCapabilityChip(
                    icon: Icons.insights_rounded,
                    label: 'Gráfico',
                    palette: palette,
                  ),
                  _ReportCapabilityChip(
                    icon: Icons.table_chart_rounded,
                    label: 'Datos',
                    palette: palette,
                  ),
                  _ReportCapabilityChip(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    palette: palette,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCapabilityChip extends StatelessWidget {
  const _ReportCapabilityChip({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.40),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.secondary, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProfitPeriodMode { day, week, fortnight, month, inventoryCross }

class _ReporteDetail extends ConsumerStatefulWidget {
  const _ReporteDetail({
    required this.definition,
    this.standalone = false,
  });

  final _ReportDefinition definition;
  final bool standalone;

  @override
  ConsumerState<_ReporteDetail> createState() => _ReporteDetailState();
}

class _ReporteDetailState extends ConsumerState<_ReporteDetail> {
  late DateTimeRange _range;
  late Future<_ReportPayload> _future;
  int? _branchId;
  bool _exporting = false;
  _ReportPayload? _lastPayload;
  int _loadVersion = 0;
  _ProfitPeriodMode _profitPeriodMode = _ProfitPeriodMode.month;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = widget.definition.kind == _ReportKind.profit
        ? DateTimeRange(
            start: DateTime(today.year, today.month),
            end: today,
          )
        : DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          );
    _branchId = ref.read(branchScopeProvider).activeBranchId;
    _future = _load();
  }

  bool get _isProfitReport => widget.definition.kind == _ReportKind.profit;

  _ReportDefinition get _activeDefinition {
    if (_isProfitReport &&
        _profitPeriodMode == _ProfitPeriodMode.inventoryCross) {
      return ReportesPage.reports.firstWhere(
        (item) => item.path.contains('/inventario/cruce-conteo'),
      );
    }
    return widget.definition;
  }

  Future<_ReportPayload> _load() async {
    final loadVersion = ++_loadVersion;
    final definition = _activeDefinition;
    final query = <String, dynamic>{};
    if (definition.requiresDates) {
      query['inicio'] = DateFormat('yyyy-MM-dd').format(_range.start);
      query['fin'] = DateFormat('yyyy-MM-dd').format(_range.end);
    }
    if (_branchId != null) query['sucursalId'] = _branchId;
    if (definition.path.contains('productos-mas-vendidos')) {
      query['limite'] = 50;
    }

    final response = await ref.read(apiClientProvider).get<Object?>(
          definition.path,
          (json) => json,
          queryParameters: query,
        );
    var payload = _ReportPayload.fromRaw(
      response.data,
      summary: definition.summary,
    );
    // El inventario puede no tener ventas: los gastos y la mano de obra
    // deben seguir visibles, usando el resumen financiero para el periodo.
    if (definition.kind == _ReportKind.profit) {
      final financeResponse = await ref.read(apiClientProvider).get<Object?>(
        '/api/v1/reportes/resumen',
        (json) => json,
        queryParameters: query,
      );
      final financeData = financeResponse.data;
      if (financeData is Map) {
        payload = _ReportPayload(
          summary: Map<String, dynamic>.from(financeData),
          rows: payload.rows,
        );
      }
    }
    if (mounted && loadVersion == _loadVersion) {
      setState(() => _lastPayload = payload);
    }
    return payload;
  }

  void _refresh() {
    setState(() {
      _lastPayload = null;
      _future = _load();
    });
  }

  Future<void> _selectPeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
      helpText: 'Selecciona el periodo del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (selected == null || !mounted) return;
    if (selected.end.difference(selected.start).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El periodo máximo permitido es de 366 días.')),
      );
      return;
    }
    setState(() {
      _lastPayload = null;
      _range = DateTimeRange(
        start: DateUtils.dateOnly(selected.start),
        end: DateUtils.dateOnly(selected.end),
      );
      _future = _load();
    });
  }

  Future<void> _selectActivePeriod() async {
    if (!_isProfitReport) {
      await _selectPeriod();
      return;
    }

    switch (_profitPeriodMode) {
      case _ProfitPeriodMode.day:
        await _selectProfitDay();
        return;
      case _ProfitPeriodMode.week:
        await _selectProfitWeek();
        return;
      case _ProfitPeriodMode.fortnight:
        await _selectProfitFortnight();
        return;
      case _ProfitPeriodMode.month:
        await _selectProfitMonth();
        return;
      case _ProfitPeriodMode.inventoryCross:
        await _selectPeriod();
        return;
    }
  }

  Future<void> _selectProfitDay() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      initialDate: _range.end,
      helpText: 'Selecciona el día de la ganancia',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (selected == null || !mounted) return;
    final day = DateUtils.dateOnly(selected);
    setState(() {
      _lastPayload = null;
      _range = DateTimeRange(start: day, end: day);
      _future = _load();
    });
  }

  Future<void> _selectProfitWeek() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      initialDate: _range.end,
      helpText: 'Selecciona una fecha de la semana',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar semana',
    );
    if (selected == null || !mounted) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(selected);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final naturalSunday = monday.add(const Duration(days: 6));
    final sunday = naturalSunday.isAfter(today) ? today : naturalSunday;

    setState(() {
      _lastPayload = null;
      _range = DateTimeRange(start: monday, end: sunday);
      _future = _load();
    });
  }

  Future<void> _selectProfitFortnight() async {
    final selectedMonth = await _showProfitMonthPicker(
      initialMonth: _range.start,
    );
    if (selectedMonth == null || !mounted) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final lastDayOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final currentMonth = selectedMonth.year == today.year &&
        selectedMonth.month == today.month;

    final initialFortnight = _range.start.day >= 16 ? 2 : 1;
    final selectedFortnight = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final secondAvailable = !currentMonth || today.day >= 16;

        Widget option({
          required int value,
          required String title,
          required String subtitle,
          required bool enabled,
        }) {
          final selected = initialFortnight == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? scheme.primaryContainer.withOpacity(.55)
                  : scheme.surfaceContainerHighest.withOpacity(.35),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: enabled
                    ? () => Navigator.of(dialogContext).pop(value)
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        value == 1
                            ? Icons.looks_one_rounded
                            : Icons.looks_two_rounded,
                        color: enabled
                            ? scheme.primary
                            : scheme.onSurface.withOpacity(.30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: enabled
                                    ? scheme.onSurface
                                    : scheme.onSurface.withOpacity(.35),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: enabled
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface.withOpacity(.28),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected && enabled)
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(
            'Quincena · ${_monthYearLabel(selectedMonth)}',
          ),
          content: SizedBox(
            width: math.min(MediaQuery.sizeOf(dialogContext).width * .86, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(
                  value: 1,
                  title: 'Primera quincena',
                  subtitle: 'Del 1 al 15',
                  enabled: true,
                ),
                option(
                  value: 2,
                  title: 'Segunda quincena',
                  subtitle:
                      'Del 16 al ${lastDayOfMonth.day}${currentMonth && !secondAvailable ? ' · aún no disponible' : ''}',
                  enabled: secondAvailable,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selectedFortnight == null || !mounted) return;

    final firstDay = selectedFortnight == 1
        ? DateTime(selectedMonth.year, selectedMonth.month, 1)
        : DateTime(selectedMonth.year, selectedMonth.month, 16);
    final naturalLastDay = selectedFortnight == 1
        ? DateTime(selectedMonth.year, selectedMonth.month, 15)
        : lastDayOfMonth;
    final lastDay = naturalLastDay.isAfter(today) ? today : naturalLastDay;

    setState(() {
      _lastPayload = null;
      _range = DateTimeRange(start: firstDay, end: lastDay);
      _future = _load();
    });
  }

  Future<void> _selectProfitMonth() async {
    final selected = await _showProfitMonthPicker(
      initialMonth: _range.start,
    );
    if (selected == null || !mounted) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final firstDay = DateTime(selected.year, selected.month);
    final naturalLastDay = DateTime(selected.year, selected.month + 1, 0);
    final lastDay = naturalLastDay.isAfter(today) ? today : naturalLastDay;

    setState(() {
      _lastPayload = null;
      _range = DateTimeRange(start: firstDay, end: lastDay);
      _future = _load();
    });
  }

  Future<DateTime?> _showProfitMonthPicker({
    required DateTime initialMonth,
  }) async {
    final now = DateUtils.dateOnly(DateTime.now());
    const firstYear = 2020;
    var selectedYear = initialMonth.year.clamp(firstYear, now.year).toInt();
    var selectedMonth = initialMonth.month;

    if (selectedYear == now.year && selectedMonth > now.month) {
      selectedMonth = now.month;
    }

    const monthNames = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;

            void changeYear(int year) {
              setDialogState(() {
                selectedYear = year;
                if (selectedYear == now.year && selectedMonth > now.month) {
                  selectedMonth = now.month;
                }
              });
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              title: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Selecciona el mes'),
                  ),
                ],
              ),
              content: SizedBox(
                width: math.min(MediaQuery.sizeOf(context).width * .86, 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withOpacity(.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withOpacity(.65),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Año anterior',
                            onPressed: selectedYear > firstYear
                                ? () => changeYear(selectedYear - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedYear,
                                isExpanded: true,
                                alignment: Alignment.center,
                                items: [
                                  for (var year = firstYear;
                                      year <= now.year;
                                      year++)
                                    DropdownMenuItem<int>(
                                      value: year,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$year',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (year) {
                                  if (year != null) changeYear(year);
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Año siguiente',
                            onPressed: selectedYear < now.year
                                ? () => changeYear(selectedYear + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.35,
                      ),
                      itemBuilder: (_, index) {
                        final month = index + 1;
                        final futureMonth =
                            selectedYear == now.year && month > now.month;
                        final selected = selectedMonth == month;

                        return Material(
                          color: selected
                              ? scheme.primary
                              : scheme.surfaceContainerHighest.withOpacity(.35),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: futureMonth
                                ? null
                                : () => setDialogState(
                                      () => selectedMonth = month,
                                    ),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.outlineVariant.withOpacity(.55),
                                ),
                              ),
                              child: Text(
                                monthNames[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: futureMonth
                                      ? scheme.onSurface.withOpacity(.30)
                                      : selected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mes seleccionado: ${monthNames[selectedMonth - 1]} $selectedYear',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    DateTime(selectedYear, selectedMonth),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aplicar mes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _changeProfitPeriodMode(_ProfitPeriodMode mode) {
    if (_profitPeriodMode == mode) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final anchor = _range.end.isAfter(today) ? today : _range.end;
    final nextRange = switch (mode) {
      _ProfitPeriodMode.day => DateTimeRange(start: anchor, end: anchor),
      _ProfitPeriodMode.week => () {
          final monday = anchor.subtract(
            Duration(days: anchor.weekday - DateTime.monday),
          );
          final naturalSunday = monday.add(const Duration(days: 6));
          return DateTimeRange(
            start: monday,
            end: naturalSunday.isAfter(today) ? today : naturalSunday,
          );
        }(),
      _ProfitPeriodMode.fortnight => DateTimeRange(
          start: DateTime(
            anchor.year,
            anchor.month,
            anchor.day <= 15 ? 1 : 16,
          ),
          end: anchor.day <= 15
              ? (anchor.year == today.year &&
                      anchor.month == today.month &&
                      DateTime(anchor.year, anchor.month, 15).isAfter(today)
                  ? today
                  : DateTime(anchor.year, anchor.month, 15))
              : (anchor.year == today.year && anchor.month == today.month
                  ? today
                  : DateTime(anchor.year, anchor.month + 1, 0)),
        ),
      _ProfitPeriodMode.month => DateTimeRange(
          start: DateTime(anchor.year, anchor.month),
          end: anchor.year == today.year && anchor.month == today.month
              ? today
              : DateTime(anchor.year, anchor.month + 1, 0),
        ),
      _ProfitPeriodMode.inventoryCross => DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        ),
    };

    setState(() {
      _profitPeriodMode = mode;
      _lastPayload = null;
      _range = nextRange;
      _future = _load();
    });
  }

  Future<void> _exportPdf(_ReportPayload payload) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final branchState = ref.read(branchScopeProvider);
      final branch = branchState.branches
          .where((item) => item.sucuId == _branchId)
          .firstOrNull;
      final definition = _activeDefinition;
      final metrics = _buildMetrics(definition, payload);
      final rows = _pdfRowsForDefinition(definition, payload.pdfRows);
      final includePeriod = definition.requiresDates && definition.showDateFilter;
      final bytes = await ReportePdfService().build(
        title: definition.title,
        description: definition.description,
        start: includePeriod ? _range.start : null,
        end: includePeriod ? _range.end : null,
        branchName: branch?.sucuNombre ?? (_branchId == null ? 'Sucursal permitida' : 'Sucursal $_branchId'),
        rows: rows,
        metrics: metrics,
        currencyKeys: definition.currencyKeys,
        percentageKeys: definition.percentageKeys,
        chartLabelKey: definition.chartLabelKey,
        chartValueKey: definition.chartValueKey,
        signedChart: definition.signedChart,
      );
      final name = _safeFileName(definition.title);
      final period = includePeriod
          ? '_${DateFormat('yyyyMMdd').format(_range.start)}_${DateFormat('yyyyMMdd').format(_range.end)}'
          : '_${DateFormat('yyyyMMdd').format(DateTime.now())}';
      final saved = await downloadBytesFile(
        fileName: '${name.toLowerCase()}$period.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Reporte PDF guardado correctamente.'
                  : 'La descarga del PDF fue cancelada.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible generar el PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final activeDefinition = _activeDefinition;

    ref.listen<BranchScopeState>(branchScopeProvider, (previous, next) {
      if (_branchId == null && next.activeBranchId != null && mounted) {
        setState(() {
          _lastPayload = null;
          _branchId = next.activeBranchId;
          _future = _load();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          SafeArea(
            child: Column(
              children: [
                _DetailHeader(
                  definition: widget.definition,
                  palette: palette,
                  range: _range,
                  branchId: _branchId,
                  branches: branchState.branches,
                  exporting: _exporting,
                  canExport: _lastPayload != null && !_lastPayload!.isEmpty,
                  showBackButton: !widget.standalone,
                  onBack: () => Navigator.of(context).maybePop(),
                  onRefresh: _refresh,
                  onSelectPeriod: _selectActivePeriod,
                  profitPeriodMode:
                      _isProfitReport ? _profitPeriodMode : null,
                  onProfitPeriodModeChanged:
                      _isProfitReport ? _changeProfitPeriodMode : null,
                  onBranchChanged: (value) {
                    setState(() {
                      _lastPayload = null;
                      _branchId = value;
                      _future = _load();
                    });
                  },
                  onExport: _lastPayload == null || _lastPayload!.isEmpty
                      ? null
                      : () => _exportPdf(_lastPayload!),
                ),
                Expanded(
                  child: FutureBuilder<_ReportPayload>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const AppLoader(message: 'Construyendo reporte...');
                      }
                      if (snapshot.hasError) {
                        return AppErrorView(
                          message: snapshot.error.toString(),
                          onRetry: _refresh,
                        );
                      }
                      final payload = snapshot.data ?? const _ReportPayload();
                      if (payload.isEmpty) {
                        return AppEmptyView(
                          message: activeDefinition.path.contains('cruce-conteo')
                              ? 'No hay conteos físicos en el periodo. Registra el conteo desde Inventario y vuelve a consultar.'
                              : 'No hay datos para los filtros seleccionados.',
                        );
                      }
                      return _ReportContent(
                        definition: activeDefinition,
                        payload: payload,
                        palette: palette,
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.definition,
    required this.palette,
    required this.range,
    required this.branchId,
    required this.branches,
    required this.exporting,
    required this.canExport,
    required this.showBackButton,
    required this.onBack,
    required this.onRefresh,
    required this.onSelectPeriod,
    this.profitPeriodMode,
    this.onProfitPeriodModeChanged,
    required this.onBranchChanged,
    required this.onExport,
  });

  final _ReportDefinition definition;
  final AppPalette palette;
  final DateTimeRange range;
  final int? branchId;
  final List<dynamic> branches;
  final bool exporting;
  final bool canExport;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onSelectPeriod;
  final _ProfitPeriodMode? profitPeriodMode;
  final ValueChanged<_ProfitPeriodMode>? onProfitPeriodModeChanged;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback? onExport;

  String _periodLabel(
    DateTimeRange value,
    _ProfitPeriodMode? mode,
  ) {
    return switch (mode) {
      _ProfitPeriodMode.day => DateFormat('dd/MM/yyyy').format(value.start),
      _ProfitPeriodMode.week =>
        'Semana ${DateFormat('dd/MM').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}',
      _ProfitPeriodMode.fortnight =>
        '${value.start.day >= 16 ? '2.ª' : '1.ª'} quincena · ${_monthYearLabel(value.start)}',
      _ProfitPeriodMode.month => _monthYearLabel(value.start),
      _ProfitPeriodMode.inventoryCross =>
        '${DateFormat('dd/MM').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}',
      null =>
        '${DateFormat('dd/MM/yyyy').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: palette.panelDecoration(
              baseRadius: 24,
              tint: palette.secondary,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 680;
                final tablet = constraints.maxWidth < 1020;

                final reportIdentity = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBackButton)
                      IconButton(
                        tooltip: 'Volver a reportes',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: palette.textPrimary,
                        visualDensity: VisualDensity.compact,
                      ),
                    Container(
                      width: mobile ? 40 : 46,
                      height: mobile ? 40 : 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        definition.icon,
                        color: palette.onPrimary,
                        size: mobile ? 21 : 24,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition.title,
                            maxLines: mobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 17 : 18.5,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            definition.description,
                            maxLines: mobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final refreshButton = IconButton.filledTonal(
                  tooltip: 'Actualizar reporte',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  color: palette.secondary,
                  visualDensity: VisualDensity.compact,
                );

                final exportButton = FilledButton.icon(
                  onPressed: !canExport || exporting ? null : onExport,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.actionColor,
                    foregroundColor: palette.onAction,
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 10 : 13,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 19),
                  label: Text(
                    exporting ? 'Generando' : 'PDF',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                );

                final dateFilter = definition.requiresDates && definition.showDateFilter
                    ? SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: onSelectPeriod,
                          icon: const Icon(Icons.date_range_rounded, size: 17),
                          label: Text(
                            _periodLabel(range, profitPeriodMode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: const Size(0, 40),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    : null;

                final periodModeFilter = profitPeriodMode == null ||
                        onProfitPeriodModeChanged == null
                    ? null
                    : _ProfitPeriodSelector(
                        selected: profitPeriodMode!,
                        palette: palette,
                        onChanged: onProfitPeriodModeChanged!,
                      );

                final branchFilter = DropdownButtonFormField<int?>(
                  value: branches.any((item) => item.sucuId == branchId) ? branchId : null,
                  isExpanded: true,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  iconSize: 19,
                  decoration: InputDecoration(
                    hintText: 'Sucursal',
                    prefixIcon: const Icon(Icons.storefront_rounded, size: 17),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    constraints: const BoxConstraints(minHeight: 40),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ).compactFilter(),
                  items: [
                    ...branches
                        .where((item) => item.sucuId != null)
                        .map<DropdownMenuItem<int?>>(
                          (item) => DropdownMenuItem<int?>(
                            value: item.sucuId,
                            child: Text(
                              item.sucuNombre ?? 'Sucursal ${item.sucuId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: onBranchChanged,
                );

                if (mobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      reportIdentity,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          refreshButton,
                          const SizedBox(width: 8),
                          Expanded(child: exportButton),
                        ],
                      ),
                      if (periodModeFilter != null) ...[
                        const SizedBox(height: 9),
                        periodModeFilter,
                      ],
                      const SizedBox(height: 9),
                      LayoutBuilder(
                        builder: (context, filterConstraints) {
                          final twoColumns = filterConstraints.maxWidth >= 430 &&
                              dateFilter != null;
                          if (!twoColumns) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (dateFilter != null) dateFilter,
                                if (dateFilter != null) const SizedBox(height: 8),
                                SizedBox(height: 40, child: branchFilter),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: dateFilter!),
                              const SizedBox(width: 8),
                              Expanded(child: SizedBox(height: 40, child: branchFilter)),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: reportIdentity),
                        const SizedBox(width: 12),
                        refreshButton,
                        const SizedBox(width: 8),
                        exportButton,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (periodModeFilter != null)
                          SizedBox(
                            width: tablet ? 520 : 570,
                            child: periodModeFilter,
                          ),
                        if (dateFilter != null)
                          SizedBox(
                            width: tablet ? 205 : 220,
                            child: dateFilter,
                          ),
                        SizedBox(
                          width: tablet ? 220 : 235,
                          height: 40,
                          child: branchFilter,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfitPeriodSelector extends StatelessWidget {
  const _ProfitPeriodSelector({
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final _ProfitPeriodMode selected;
  final AppPalette palette;
  final ValueChanged<_ProfitPeriodMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <({
      _ProfitPeriodMode value,
      String label,
      IconData icon,
    })>[
      (value: _ProfitPeriodMode.day, label: 'Día', icon: Icons.today_rounded),
      (value: _ProfitPeriodMode.week, label: 'Semana', icon: Icons.view_week_rounded),
      (
        value: _ProfitPeriodMode.fortnight,
        label: 'Quincena',
        icon: Icons.date_range_rounded,
      ),
      (value: _ProfitPeriodMode.month, label: 'Mes', icon: Icons.calendar_month_rounded),
      (
        value: _ProfitPeriodMode.inventoryCross,
        label: 'Cruce inventario',
        icon: Icons.fact_check_rounded,
      ),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              flex: option.value == _ProfitPeriodMode.inventoryCross ? 2 : 1,
              child: _ProfitPeriodButton(
                label: option.label,
                icon: option.icon,
                selected: selected == option.value,
                palette: palette,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfitPeriodButton extends StatelessWidget {
  const _ProfitPeriodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 74;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 6),
              decoration: BoxDecoration(
                color: selected
                    ? palette.secondary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!compact) ...[
                    Icon(
                      icon,
                      size: 15,
                      color:
                          selected ? palette.secondary : palette.textSecondary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? palette.secondary
                            : palette.textSecondary,
                        fontSize: compact ? 9.5 : 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.definition,
    required this.payload,
    required this.palette,
  });

  final _ReportDefinition definition;
  final _ReportPayload payload;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final metrics = _buildMetrics(definition, payload);
    if (definition.summary) {
      return _SummaryContent(payload: payload, metrics: metrics, palette: palette);
    }
    if (definition.path.contains('cruce-conteo')) {
      return _InventoryCountReconciliationContent(
        definition: definition,
        payload: payload,
        metrics: metrics,
        palette: palette,
      );
    }
    if (definition.kind == _ReportKind.profit) {
      return _ProfitContent(
        definition: definition,
        payload: payload,
        metrics: metrics,
        palette: palette,
      );
    }
    if (definition.kind == _ReportKind.nextOrder) {
      return _NextOrderContent(
        definition: definition,
        payload: payload,
        metrics: metrics,
        palette: palette,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricsGrid(
                  metrics: metrics,
                  palette: palette,
                  currencyKeys: definition.currencyKeys,
                  percentageKeys: definition.percentageKeys,
                ),
                const SizedBox(height: 14),
                _ReportDecisionSection(
                  definition: definition,
                  rows: payload.rows,
                  metrics: metrics,
                  palette: palette,
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: _reportChartTitle(definition),
                  subtitle: _reportChartSubtitle(definition),
                  icon: _reportChartIcon(definition),
                  palette: palette,
                  child: definition.path.endsWith('/ventas')
                      ? _ReportTimeSeriesChart(
                          rows: payload.rows,
                          dateKey: 'fecha',
                          valueKey: 'total',
                          palette: palette,
                          currency: true,
                        )
                      : _HorizontalBarChart(
                          rows: payload.rows,
                          labelKey: definition.chartLabelKey,
                          valueKey: definition.chartValueKey,
                          palette: palette,
                          currency: definition.currencyKeys
                              .contains(definition.chartValueKey),
                          percentage: definition.percentageKeys
                              .contains(definition.chartValueKey),
                          signed: definition.signedChart,
                        ),
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Detalle para validar y actuar',
                  subtitle:
                      '${payload.rows.length} registros. Busca, compara y cambia entre tarjetas o tabla según el dispositivo.',
                  icon: Icons.table_rows_rounded,
                  palette: palette,
                  child: _ReportTable(
                    rows: payload.rows,
                    palette: palette,
                    currencyKeys: definition.currencyKeys,
                    percentageKeys: definition.percentageKeys,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _ReportDecisionSection extends StatelessWidget {
  const _ReportDecisionSection({
    required this.definition,
    required this.rows,
    required this.metrics,
    required this.palette,
  });

  final _ReportDefinition definition;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final insights = _buildReportInsights(
      definition,
      rows,
      metrics,
      palette,
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    return _Panel(
      title: 'Lectura para decidir',
      subtitle:
          'Lo más importante del reporte, convertido en señales que ayudan a tomar acción.',
      icon: Icons.lightbulb_outline_rounded,
      palette: palette,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620
              ? 1
              : constraints.maxWidth < 980
                  ? 2
                  : math.min(3, insights.length);
          const spacing = 9.0;
          final width =
              (constraints.maxWidth - (columns - 1) * spacing) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final insight in insights)
                SizedBox(
                  width: width,
                  child: _ReportInsightCard(
                    insight: insight,
                    palette: palette,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportInsightData {
  const _ReportInsightData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _ReportInsightCard extends StatelessWidget {
  const _ReportInsightCard({
    required this.insight,
    required this.palette,
  });

  final _ReportInsightData insight;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 126),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: insight.color.withOpacity(.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: insight.color.withOpacity(.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: insight.color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    insight.icon,
                    color: insight.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    insight.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              insight.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
}

List<_ReportInsightData> _buildReportInsights(
  _ReportDefinition definition,
  List<Map<String, dynamic>> rows,
  Map<String, dynamic> metrics,
  AppPalette palette,
) {
  if (rows.isEmpty) return const <_ReportInsightData>[];

  if (definition.path.endsWith('/ventas')) {
    final ranked = [...rows]
      ..sort((a, b) => _toDouble(b['total']).compareTo(_toDouble(a['total'])));
    final best = ranked.first;
    final total = _sum(rows, 'total');
    final propinas = _sum(rows, 'propinas');
    final average = rows.isEmpty ? 0 : total / rows.length;
    return [
      _ReportInsightData(
        title: 'Día con mayor venta',
        value: _displayValue(best['fecha']),
        detail: CurrencyUtils.format(_toDouble(best['total'])),
        icon: Icons.emoji_events_rounded,
        color: palette.success,
      ),
      _ReportInsightData(
        title: 'Venta promedio por día',
        value: CurrencyUtils.format(average),
        detail: 'Promedio sobre ${rows.length} días con movimiento.',
        icon: Icons.query_stats_rounded,
        color: palette.secondary,
      ),
      _ReportInsightData(
        title: 'Propinas',
        value: CurrencyUtils.format(propinas),
        detail: total <= 0
            ? 'Sin ventas para calcular participación.'
            : '${(propinas * 100 / total).toStringAsFixed(1)} % del total vendido.',
        icon: Icons.volunteer_activism_rounded,
        color: palette.accent,
      ),
    ];
  }

  if (definition.path.contains('medio-pago')) {
    final ranked = [...rows]
      ..sort((a, b) => _toDouble(b['total']).compareTo(_toDouble(a['total'])));
    final top = ranked.first;
    final total = _sum(rows, 'total');
    final share = total <= 0 ? 0 : _toDouble(top['total']) * 100 / total;
    return [
      _ReportInsightData(
        title: 'Medio principal',
        value: _displayValue(top['medio_pago']),
        detail: CurrencyUtils.format(_toDouble(top['total'])),
        icon: Icons.account_balance_wallet_rounded,
        color: palette.secondary,
      ),
      _ReportInsightData(
        title: 'Concentración del recaudo',
        value: '${share.toStringAsFixed(1)} %',
        detail: share >= 70
            ? 'Alta dependencia de un solo medio de pago.'
            : 'El recaudo está distribuido entre varios medios.',
        icon: Icons.donut_large_rounded,
        color: share >= 70 ? palette.warning : palette.success,
      ),
      _ReportInsightData(
        title: 'Diversidad de pagos',
        value: '${rows.length} medios',
        detail: 'Útiles para conciliación y control de caja.',
        icon: Icons.hub_rounded,
        color: palette.accent,
      ),
    ];
  }

  if (definition.path.contains('stock-actual')) {
    final critical = rows.where((row) {
      final status = (row['estado'] ?? '').toString();
      return status == 'STOCK_NEGATIVO' ||
          status == 'AGOTADO' ||
          status == 'STOCK_BAJO';
    }).length;
    final unconfigured =
        rows.where((row) => row['estado'] == 'SIN_CONFIGURAR').length;
    final overstock =
        rows.where((row) => row['estado'] == 'SOBRESTOCK').length;
    final riskShare = rows.isEmpty ? 0 : critical * 100 / rows.length;
    return [
      _ReportInsightData(
        title: 'Productos en riesgo',
        value: '$critical',
        detail: '${riskShare.toStringAsFixed(1)} % del catálogo requiere atención.',
        icon: Icons.warning_amber_rounded,
        color: critical > 0 ? Colors.orangeAccent : palette.success,
      ),
      _ReportInsightData(
        title: 'Sin mínimo configurado',
        value: '$unconfigured',
        detail: unconfigured == 0
            ? 'Todos tienen referencia para reposición.'
            : 'Configura mínimos para obtener alertas confiables.',
        icon: Icons.tune_rounded,
        color: unconfigured > 0 ? palette.warning : palette.success,
      ),
      _ReportInsightData(
        title: 'Sobrestock',
        value: '$overstock',
        detail: overstock == 0
            ? 'No se detectan excesos sobre el máximo.'
            : 'Revisa capital inmovilizado y ritmo de rotación.',
        icon: Icons.inventory_2_rounded,
        color: overstock > 0 ? palette.accent : palette.success,
      ),
    ];
  }

  if (definition.path.contains('productos-mas-vendidos')) {
    final ranked = [...rows]
      ..sort((a, b) => _toDouble(b['cantidad']).compareTo(_toDouble(a['cantidad'])));
    final top = ranked.first;
    final totalUnits = _sum(rows, 'cantidad');
    final top3Units = ranked
        .take(3)
        .fold<double>(0, (sum, row) => sum + _toDouble(row['cantidad']));
    final concentration = totalUnits <= 0 ? 0 : top3Units * 100 / totalUnits;
    return [
      _ReportInsightData(
        title: 'Producto líder',
        value: _displayValue(top['producto']),
        detail: '${_displayValue(top['cantidad'])} unidades · ${CurrencyUtils.format(_toDouble(top['total']))}',
        icon: Icons.workspace_premium_rounded,
        color: palette.success,
      ),
      _ReportInsightData(
        title: 'Concentración Top 3',
        value: '${concentration.toStringAsFixed(1)} %',
        detail: 'Participación de los tres productos con más unidades.',
        icon: Icons.leaderboard_rounded,
        color: palette.secondary,
      ),
      _ReportInsightData(
        title: 'Ingresos del ranking',
        value: CurrencyUtils.format(_sum(rows, 'total')),
        detail: '${_displayValue(totalUnits)} unidades vendidas.',
        icon: Icons.payments_rounded,
        color: palette.actionColor,
      ),
    ];
  }

  if (definition.path.contains('movimientos-inventario')) {
    final entradas = rows
        .where((row) => row['operacion'] == 'ENTRADA')
        .fold<double>(0, (sum, row) => sum + _toDouble(row['cantidad_unidades']));
    final salidas = rows
        .where((row) => row['operacion'] == 'SALIDA')
        .fold<double>(0, (sum, row) => sum + _toDouble(row['cantidad_unidades']));
    final ajustes =
        rows.where((row) => row['operacion'] == 'AJUSTE').length;
    final balance = entradas - salidas;
    return [
      _ReportInsightData(
        title: 'Entradas registradas',
        value: _displayValue(entradas),
        detail: 'Unidades incorporadas al inventario.',
        icon: Icons.south_west_rounded,
        color: palette.success,
      ),
      _ReportInsightData(
        title: 'Salidas registradas',
        value: _displayValue(salidas),
        detail: 'Unidades descontadas en el periodo.',
        icon: Icons.north_east_rounded,
        color: Colors.orangeAccent,
      ),
      _ReportInsightData(
        title: 'Balance de flujo',
        value: _displayValue(balance),
        detail: '$ajustes ajustes manuales registrados.',
        icon: Icons.balance_rounded,
        color: balance < 0 ? palette.warning : palette.secondary,
      ),
    ];
  }

  if (definition.path.contains('cruce-ventas')) {
    final ranked = [...rows]
      ..sort(
        (a, b) => _toDouble(b['rotacion_porcentaje'])
            .compareTo(_toDouble(a['rotacion_porcentaje'])),
      );
    final top = ranked.first;
    final withoutRotation =
        rows.where((row) => row['estado'] == 'SIN_ROTACION').length;
    final risk = rows.where((row) {
      final status = (row['estado'] ?? '').toString();
      return status == 'STOCK_NEGATIVO' ||
          status == 'AGOTADO_CON_ROTACION' ||
          status == 'STOCK_BAJO';
    }).length;
    return [
      _ReportInsightData(
        title: 'Mayor rotación',
        value: _displayValue(top['producto']),
        detail:
            '${_displayValue(top['rotacion_porcentaje'], percentage: true)} de rotación.',
        icon: Icons.autorenew_rounded,
        color: palette.success,
      ),
      _ReportInsightData(
        title: 'Sin rotación',
        value: '$withoutRotation',
        detail: 'Productos sin ventas en el periodo seleccionado.',
        icon: Icons.pause_circle_outline_rounded,
        color: withoutRotation > 0 ? palette.warning : palette.success,
      ),
      _ReportInsightData(
        title: 'Rotación con riesgo de stock',
        value: '$risk',
        detail: 'Productos que requieren reposición o validación.',
        icon: Icons.crisis_alert_rounded,
        color: risk > 0 ? Colors.orangeAccent : palette.success,
      ),
    ];
  }

  if (definition.path.contains('productos-desfalcados') &&
      !definition.path.contains('/persona')) {
    final negative =
        rows.where((row) => _toDouble(row['stock_actual']) < 0).length;
    final outWithDemand =
        rows.where((row) => row['estado'] == 'AGOTADO_CON_ROTACION').length;
    final associatedSales = _sum(rows, 'valor_vendido');
    return [
      _ReportInsightData(
        title: 'Stock negativo',
        value: '$negative',
        detail: negative == 0
            ? 'No hay productos con existencia negativa.'
            : 'Requieren conteo y revisión de movimientos.',
        icon: Icons.error_outline_rounded,
        color: negative > 0 ? Colors.redAccent : palette.success,
      ),
      _ReportInsightData(
        title: 'Agotados con demanda',
        value: '$outWithDemand',
        detail: 'Productos sin stock que tuvieron ventas en el periodo.',
        icon: Icons.remove_shopping_cart_rounded,
        color: outWithDemand > 0 ? Colors.orangeAccent : palette.success,
      ),
      _ReportInsightData(
        title: 'Ventas asociadas al riesgo',
        value: CurrencyUtils.format(associatedSales),
        detail: 'Referencia del movimiento comercial de los productos alertados.',
        icon: Icons.attach_money_rounded,
        color: palette.warning,
      ),
    ];
  }

  if (definition.path.contains('/persona')) {
    final ranked = [...rows]
      ..sort(
        (a, b) => _toDouble(b['unidades_salida'])
            .compareTo(_toDouble(a['unidades_salida'])),
      );
    final top = ranked.first;
    final total = _sum(rows, 'unidades_salida');
    final topShare =
        total <= 0 ? 0 : _toDouble(top['unidades_salida']) * 100 / total;
    return [
      _ReportInsightData(
        title: 'Mayor volumen de salidas',
        value: _displayValue(top['responsable']),
        detail:
            '${_displayValue(top['unidades_salida'])} unidades registradas.',
        icon: Icons.person_search_rounded,
        color: palette.secondary,
      ),
      _ReportInsightData(
        title: 'Concentración principal',
        value: '${topShare.toStringAsFixed(1)} %',
        detail: topShare >= 60
            ? 'Conviene revisar el contexto de esta concentración.'
            : 'Las salidas están distribuidas entre responsables.',
        icon: Icons.pie_chart_outline_rounded,
        color: topShare >= 60 ? palette.warning : palette.success,
      ),
      _ReportInsightData(
        title: 'Trazabilidad',
        value: '${_displayValue(_sum(rows, 'movimientos'))} movimientos',
        detail: '${rows.length} responsables con actividad.',
        icon: Icons.manage_search_rounded,
        color: palette.accent,
      ),
    ];
  }

  return [
    _ReportInsightData(
      title: 'Registros analizados',
      value: '${rows.length}',
      detail: 'Consulta el detalle para validar tendencias y excepciones.',
      icon: Icons.analytics_rounded,
      color: palette.secondary,
    ),
  ];
}

String _reportAreaLabel(_ReportDefinition definition) {
  if (definition.summary || definition.kind == _ReportKind.profit) {
    return 'FINANZAS Y GESTIÓN';
  }
  if (definition.path.contains('/ventas') ||
      definition.path.contains('productos-mas-vendidos')) {
    return 'VENTAS Y RECAUDO';
  }
  if (definition.path.contains('/persona') ||
      definition.path.contains('movimientos-inventario') ||
      definition.path.contains('cruce-conteo')) {
    return 'CONTROL Y TRAZABILIDAD';
  }
  if (definition.path.contains('inventario') ||
      definition.path.contains('stock-actual')) {
    return 'INVENTARIO';
  }
  return 'OPERACIÓN';
}

String _reportChartTitle(_ReportDefinition definition) {
  if (definition.path.endsWith('/ventas')) return 'Evolución de ventas';
  if (definition.path.contains('medio-pago')) return 'Participación del recaudo';
  if (definition.path.contains('stock-actual')) return 'Existencias por producto';
  if (definition.path.contains('productos-mas-vendidos')) {
    return 'Ranking de demanda';
  }
  if (definition.path.contains('movimientos-inventario')) {
    return 'Movimiento por tipo';
  }
  if (definition.path.contains('cruce-ventas')) return 'Rotación por producto';
  if (definition.path.contains('productos-desfalcados') &&
      !definition.path.contains('/persona')) {
    return 'Productos con demanda en riesgo';
  }
  if (definition.path.contains('/persona')) return 'Salidas por responsable';
  return 'Lectura gráfica';
}

String _reportChartSubtitle(_ReportDefinition definition) {
  if (definition.path.endsWith('/ventas')) {
    return 'Compara los días del periodo y detecta cuándo se concentra la facturación.';
  }
  if (definition.path.contains('medio-pago')) {
    return 'Visualiza qué medios concentran el recaudo para facilitar conciliación y control.';
  }
  if (definition.path.contains('stock-actual')) {
    return 'Compara existencias y detecta productos que merecen una revisión de mínimos o máximos.';
  }
  if (definition.path.contains('productos-mas-vendidos')) {
    return 'Identifica los productos que más unidades aportan al movimiento comercial.';
  }
  if (definition.path.contains('movimientos-inventario')) {
    return 'Observa qué tipos de movimiento explican la mayor parte del flujo de inventario.';
  }
  if (definition.path.contains('cruce-ventas')) {
    return 'Prioriza productos con mayor movimiento y detecta referencias estancadas.';
  }
  if (definition.path.contains('productos-desfalcados') &&
      !definition.path.contains('/persona')) {
    return 'Dimensiona los productos con riesgo de disponibilidad frente a su movimiento comercial.';
  }
  if (definition.path.contains('/persona')) {
    return 'Compara el volumen de salidas registrado por cada responsable.';
  }
  return 'Los valores más relevantes del reporte para identificar tendencias rápidamente.';
}

IconData _reportChartIcon(_ReportDefinition definition) {
  if (definition.path.endsWith('/ventas')) return Icons.show_chart_rounded;
  if (definition.path.contains('medio-pago')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (definition.path.contains('stock-actual')) return Icons.inventory_2_rounded;
  if (definition.path.contains('productos-mas-vendidos')) {
    return Icons.leaderboard_rounded;
  }
  if (definition.path.contains('movimientos-inventario')) {
    return Icons.swap_vert_circle_rounded;
  }
  if (definition.path.contains('cruce-ventas')) return Icons.sync_alt_rounded;
  if (definition.path.contains('/persona')) {
    return Icons.manage_accounts_rounded;
  }
  if (definition.path.contains('productos-desfalcados')) {
    return Icons.warning_amber_rounded;
  }
  return Icons.insights_rounded;
}

enum _ProfitProductFilter { todos, rentables, margenBajo, perdidas, sinCosto }

class _ProfitContent extends StatefulWidget {
  const _ProfitContent({
    required this.definition,
    required this.payload,
    required this.metrics,
    required this.palette,
  });

  final _ReportDefinition definition;
  final _ReportPayload payload;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  State<_ProfitContent> createState() => _ProfitContentState();
}

class _ProfitContentState extends State<_ProfitContent> {
  final TextEditingController _searchController = TextEditingController();
  _ProfitProductFilter _filter = _ProfitProductFilter.todos;
  bool _tableView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsForDefinition(widget.definition, widget.payload.rows)
        .where((row) => _toDouble(row['unidades_vendidas_periodo']) > 0)
        .toList(growable: false);
    final filteredRows = _filterRows(rows);
    final positiveRows = rows
        .where((row) => _toDouble(row['ganancia_bruta_periodo']) > 0)
        .toList(growable: false)
      ..sort(
        (a, b) => _toDouble(b['ganancia_bruta_periodo'])
            .compareTo(_toDouble(a['ganancia_bruta_periodo'])),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfitHero(
                  rows: rows,
                  metadata: widget.payload.summary.isNotEmpty
                      ? widget.payload.summary
                      : (widget.payload.rows.isEmpty
                          ? const <String, dynamic>{}
                          : widget.payload.rows.first),
                  palette: widget.palette,
                ),
                const SizedBox(height: 14),
                _ProfitExpenseDetails(
                  items: _asRows(widget.payload.summary['desglose_gastos_periodo']),
                  finance: widget.payload.summary,
                  palette: widget.palette,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 940;
                    final topProducts = _Panel(
                      title: 'Productos que sostienen la ganancia',
                      subtitle:
                          'Participación de los productos que más utilidad aportan en el periodo.',
                      icon: Icons.workspace_premium_rounded,
                      palette: widget.palette,
                      child: positiveRows.isEmpty
                          ? _PositiveEmptyState(
                              palette: widget.palette,
                              message:
                                  'Todavía no hay productos con ganancia positiva en el periodo.',
                            )
                          : _ProfitContributionList(
                              rows: positiveRows,
                              palette: widget.palette,
                            ),
                    );
                    final health = _Panel(
                      title: 'Salud de la rentabilidad',
                      subtitle:
                          'Señales rápidas para saber dónde revisar precios y costos.',
                      icon: Icons.monitor_heart_rounded,
                      palette: widget.palette,
                      child: _ProfitHealthSummary(
                        rows: rows,
                        palette: widget.palette,
                      ),
                    );

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          topProducts,
                          const SizedBox(height: 14),
                          health,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: topProducts),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: health),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Ganancia por producto',
                  subtitle:
                      '${filteredRows.length} de ${rows.length} productos visibles. Busca y filtra sin perder el contexto del reporte.',
                  icon: Icons.inventory_2_rounded,
                  palette: widget.palette,
                  trailing: _ProfitViewToggle(
                    tableView: _tableView,
                    palette: widget.palette,
                    onChanged: (value) => setState(() => _tableView = value),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfitFilterBar(
                        controller: _searchController,
                        selected: _filter,
                        palette: widget.palette,
                        onSearchChanged: (_) => setState(() {}),
                        onFilterChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 16),
                      if (filteredRows.isEmpty)
                        _PositiveEmptyState(
                          palette: widget.palette,
                          message:
                              'No hay productos que coincidan con la búsqueda o el filtro seleccionado.',
                        )
                      else if (_tableView)
                        _ReportTable(
                          rows: filteredRows,
                          palette: widget.palette,
                          currencyKeys: widget.definition.currencyKeys,
                          percentageKeys: widget.definition.percentageKeys,
                        )
                      else
                        _ProfitProductGrid(
                          rows: filteredRows,
                          palette: widget.palette,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterRows(
    List<Map<String, dynamic>> rows,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = rows.where((row) {
      final product = (row['producto'] ?? '').toString().toLowerCase();
      final branch = (row['sucursal'] ?? '').toString().toLowerCase();
      if (query.isNotEmpty &&
          !product.contains(query) &&
          !branch.contains(query)) {
        return false;
      }

      final profit = _toDouble(row['ganancia_bruta_periodo']);
      final margin = _toDouble(row['margen_bruto_porcentaje']);
      final unitCost = _toDouble(row['costo_unitario_actual']);
      return switch (_filter) {
        _ProfitProductFilter.todos => true,
        _ProfitProductFilter.rentables => profit > 0 && margin >= 20,
        _ProfitProductFilter.margenBajo => profit >= 0 && margin < 20,
        _ProfitProductFilter.perdidas => profit < 0,
        _ProfitProductFilter.sinCosto => unitCost <= 0,
      };
    }).toList(growable: false);

    filtered.sort(
      (a, b) => _toDouble(b['ganancia_bruta_periodo'])
          .compareTo(_toDouble(a['ganancia_bruta_periodo'])),
    );
    return filtered;
  }
}

class _ProfitHero extends StatelessWidget {
  const _ProfitHero({
    required this.rows,
    required this.metadata,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metadata;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final ingresos = _sum(rows, 'ingresos_periodo');
    final costoProductos = _sum(rows, 'costo_ventas_periodo');
    final gananciaBruta = _sum(rows, 'ganancia_bruta_periodo');
    final unidades = _sum(rows, 'unidades_vendidas_periodo');

    final gastosFijos = _toDouble(metadata['gastos_fijos_periodo']);
    final gastosTurno = _toDouble(metadata['gastos_turno_periodo']);
    final gastosVariables = _toDouble(metadata['gastos_variables_periodo']);
    final gastosVariablesConfigurados =
        (gastosVariables - gastosTurno).clamp(0.0, double.infinity).toDouble();
    final manoObra = _toDouble(metadata['mano_obra_periodo']);
    final gastosOperativosRaw =
        _toDouble(metadata['gastos_operativos_periodo']);
    final gastosOperativos = gastosOperativosRaw != 0
        ? gastosOperativosRaw
        : gastosFijos + gastosVariables + manoObra;
    final netaBackend =
        _toDouble(metadata['ganancia_neta_estimada_periodo']);
    final gananciaNeta = metadata.containsKey('ganancia_neta_estimada_periodo')
        ? netaBackend
        : gananciaBruta - gastosOperativos;

    final margenNeto =
        ingresos == 0 ? 0.0 : gananciaNeta * 100 / ingresos;
    final costosTotales = costoProductos + gastosOperativos;
    final positive = gananciaNeta >= 0;
    final resultColor = positive ? palette.success : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(
        baseRadius: 26,
        tint: resultColor,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final mainResult = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: resultColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: resultColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ganancia neta estimada del periodo',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          positive
                              ? 'Resultado después del costo de los productos, gastos fijos, variables y mano de obra configurada.'
                              : 'Los costos y gastos configurados superan la ganancia bruta del periodo.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _displayValue(gananciaNeta, currency: true),
                  style: TextStyle(
                    color: resultColor,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 32 : 40,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProfitPill(
                    icon: Icons.percent_rounded,
                    label:
                        'Margen neto ${_displayValue(margenNeto, percentage: true)}',
                    color: resultColor,
                    palette: palette,
                  ),
                  _ProfitPill(
                    icon: Icons.inventory_2_rounded,
                    label: '${rows.length} productos vendidos',
                    color: palette.secondary,
                    palette: palette,
                  ),
                  _ProfitPill(
                    icon: Icons.numbers_rounded,
                    label: '${_displayValue(unidades)} unidades',
                    color: palette.actionColor,
                    palette: palette,
                  ),
                ],
              ),
            ],
          );

          final breakdown = Column(
            children: [
              _ProfitBreakdownRow(
                icon: Icons.point_of_sale_rounded,
                label: 'Ingresos por productos',
                value: ingresos,
                color: palette.secondary,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.shopping_cart_checkout_rounded,
                label: 'Costo de lo vendido',
                value: costoProductos,
                color: Colors.orange.shade700,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Ganancia bruta',
                value: gananciaBruta,
                color: palette.actionColor,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.lock_outline,
                label: 'Gastos fijos',
                value: gastosFijos,
                color: palette.secondary,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.tune_rounded,
                label: 'Variables configurados',
                value: gastosVariablesConfigurados,
                color: palette.warning,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.shopping_bag_outlined,
                label: 'Gastos del turno',
                value: gastosTurno,
                color: Colors.orangeAccent,
                palette: palette,
              ),
              const SizedBox(height: 10),
              _ProfitBreakdownRow(
                icon: Icons.groups_2_outlined,
                label: 'Mano de obra',
                value: manoObra,
                color: Colors.deepPurpleAccent,
                palette: palette,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ingresos <= 0
                      ? 0.0
                      : (costosTotales / ingresos)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                  minHeight: 9,
                  backgroundColor: palette.background.withOpacity(0.7),
                  color: costosTotales > ingresos
                      ? Colors.redAccent
                      : Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ingresos <= 0
                          ? 'Sin ingresos en el periodo'
                          : 'Costos y gastos representan ${_displayValue(costosTotales * 100 / ingresos, percentage: true)} de los ingresos',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainResult,
                const SizedBox(height: 20),
                Divider(color: palette.cardBorder),
                const SizedBox(height: 16),
                breakdown,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: mainResult),
              Container(
                width: 1,
                height: 270,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: palette.cardBorder,
              ),
              Expanded(flex: 2, child: breakdown),
            ],
          );
        },
      ),
    );
  }
}

class _ProfitExpenseDetails extends StatelessWidget {
  const _ProfitExpenseDetails({
    required this.items,
    required this.finance,
    required this.palette,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> finance;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    const categories = <String, String>{
      'FIJO': 'Gastos fijos',
      'VARIABLE': 'Gastos variables configurados',
      'GASTOS TURNO': 'Gastos del turno',
      'MANO DE OBRA': 'Mano de obra por cargo',
    };
    final subtotal = <String, double>{};
    for (final item in items) {
      final type = (item['categoria'] ?? '').toString().toUpperCase();
      subtotal[type] = (subtotal[type] ?? 0) + _toDouble(item['valor']);
    }
    final total = subtotal.values.fold<double>(0, (sum, amount) => sum + amount);
    final expected = _toDouble(finance['gastos_operativos_periodo']);
    final difference = total - expected;

    return _Panel(
      title: '¿En qué se van los gastos?',
      subtitle: 'Detalle calculado del periodo y la sucursal seleccionados. Mano de obra corresponde a tarifas configuradas, no a un estado de pago de nómina.',
      icon: Icons.receipt_long_rounded,
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Text(
              'No se encontraron gastos que afecten la utilidad en este periodo.',
              style: TextStyle(color: palette.textSecondary),
            ),
          for (final category in categories.entries)
            if (items.any((item) => (item['categoria'] ?? '').toString().toUpperCase() == category.key))
              ExpansionTile(
                key: PageStorageKey('detalle-gasto-${category.key}'),
                initiallyExpanded: category.key == 'MANO DE OBRA',
                tilePadding: EdgeInsets.zero,
                title: Text(
                  category.value,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${items.where((item) => (item['categoria'] ?? '').toString().toUpperCase() == category.key).length} conceptos',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                trailing: Text(
                  _displayValue(subtotal[category.key] ?? 0, currency: true),
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
                children: [
                  for (final item in items.where((entry) => (entry['categoria'] ?? '').toString().toUpperCase() == category.key))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (item['concepto'] ?? 'Sin concepto').toString(),
                                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
                                ),
                                if (item['fecha'] != null || (item['tipo'] ?? '').toString().trim().isNotEmpty)
                                  Text(
                                    [
                                      if (item['fecha'] != null) item['fecha'].toString(),
                                      if ((item['tipo'] ?? '').toString().trim().isNotEmpty) item['tipo'].toString(),
                                    ].join(' · '),
                                    style: TextStyle(color: palette.textSecondary, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _displayValue(_toDouble(item['valor']), currency: true),
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total detallado',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _displayValue(total, currency: true),
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (finance.containsKey('gastos_operativos_periodo') && difference.abs() > 0.01)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Atención: diferencia de ${_displayValue(difference, currency: true)} frente al total del reporte. Revisa los conceptos del periodo.',
                style: TextStyle(color: palette.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfitPill extends StatelessWidget {
  const _ProfitPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitBreakdownRow extends StatelessWidget {
  const _ProfitBreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _displayValue(value, currency: true),
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ProfitContributionList extends StatelessWidget {
  const _ProfitContributionList({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(6).toList(growable: false);
    final totalPositive = rows.fold<double>(
      0,
      (sum, row) => sum + math.max(0, _toDouble(row['ganancia_bruta_periodo'])),
    );
    final maxProfit = visible.fold<double>(
      1,
      (value, row) => math.max(
        value,
        _toDouble(row['ganancia_bruta_periodo']),
      ),
    );

    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          _ProfitContributionItem(
            index: index,
            row: visible[index],
            totalPositive: totalPositive,
            maxProfit: maxProfit,
            palette: palette,
          ),
          if (index < visible.length - 1) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.cardBorder),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _ProfitContributionItem extends StatelessWidget {
  const _ProfitContributionItem({
    required this.index,
    required this.row,
    required this.totalPositive,
    required this.maxProfit,
    required this.palette,
  });

  final int index;
  final Map<String, dynamic> row;
  final double totalPositive;
  final double maxProfit;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final profit = _toDouble(row['ganancia_bruta_periodo']);
    final share = totalPositive <= 0 ? 0.0 : profit * 100 / totalPositive;
    final factor = maxProfit <= 0
        ? 0.0
        : (profit / maxProfit).clamp(0.0, 1.0).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index == 0
                ? palette.success.withOpacity(0.14)
                : palette.secondary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: index == 0 ? palette.success : palette.secondary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayValue(row['producto']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _displayValue(profit, currency: true),
                    style: TextStyle(
                      color: palette.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: factor,
                  minHeight: 7,
                  backgroundColor: palette.background.withOpacity(0.65),
                  color: palette.success,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_displayValue(share, percentage: true)} de la ganancia positiva · ${_displayValue(row['unidades_vendidas_periodo'])} unidades',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfitHealthSummary extends StatelessWidget {
  const _ProfitHealthSummary({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final healthy = rows.where((row) {
      final profit = _toDouble(row['ganancia_bruta_periodo']);
      final margin = _toDouble(row['margen_bruto_porcentaje']);
      return profit > 0 && margin >= 20;
    }).length;
    final lowMargin = rows.where((row) {
      final profit = _toDouble(row['ganancia_bruta_periodo']);
      final margin = _toDouble(row['margen_bruto_porcentaje']);
      return profit >= 0 && margin < 20;
    }).length;
    final losses = rows
        .where((row) => _toDouble(row['ganancia_bruta_periodo']) < 0)
        .length;
    final noCost = rows
        .where((row) => _toDouble(row['costo_unitario_actual']) <= 0)
        .length;

    final sortedByMargin = [...rows]
      ..sort(
        (a, b) => _toDouble(b['margen_bruto_porcentaje'])
            .compareTo(_toDouble(a['margen_bruto_porcentaje'])),
      );
    final best = sortedByMargin.isEmpty ? null : sortedByMargin.first;

    return Column(
      children: [
        _ProfitHealthLine(
          icon: Icons.check_circle_rounded,
          title: 'Rentabilidad saludable',
          detail: '$healthy productos con margen igual o superior al 20 %',
          value: healthy,
          color: palette.success,
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ProfitHealthLine(
          icon: Icons.speed_rounded,
          title: 'Margen bajo',
          detail: '$lowMargin productos dejan menos del 20 %',
          value: lowMargin,
          color: palette.warning,
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ProfitHealthLine(
          icon: Icons.trending_down_rounded,
          title: 'Vendidos con pérdida',
          detail: '$losses productos requieren revisar precio o costo',
          value: losses,
          color: Colors.redAccent,
          palette: palette,
        ),
        const SizedBox(height: 12),
        _ProfitHealthLine(
          icon: Icons.help_outline_rounded,
          title: 'Sin costo configurado',
          detail: '$noCost productos no permiten calcular una utilidad confiable',
          value: noCost,
          color: Colors.orange.shade700,
          palette: palette,
        ),
        if (best != null) ...[
          const SizedBox(height: 15),
          Divider(height: 1, color: palette.cardBorder),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.star_rounded, color: palette.success, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Mejor margen: '),
                      TextSpan(
                        text: _displayValue(best['producto']),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' (${_displayValue(best['margen_bruto_porcentaje'], percentage: true)}).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProfitHealthLine extends StatelessWidget {
  const _ProfitHealthLine({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String detail;
  final int value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfitFilterBar extends StatelessWidget {
  const _ProfitFilterBar({
    required this.controller,
    required this.selected,
    required this.palette,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _ProfitProductFilter selected;
  final AppPalette palette;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ProfitProductFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final search = TextField(
          maxLength: 120,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Buscar producto o sucursal',
            prefixIcon: const Icon(Icons.search_rounded, size: 17),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 17),
                    visualDensity: VisualDensity.compact,
                  ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            constraints: const BoxConstraints(maxHeight: 40),
            filled: true,
            fillColor: palette.background.withOpacity(0.50),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
          ).compactFilter(),
        );
        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ProfitFilterChip(
                label: 'Todos',
                icon: Icons.apps_rounded,
                value: _ProfitProductFilter.todos,
                selected: selected,
                palette: palette,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: 7),
              _ProfitFilterChip(
                label: 'Rentables',
                icon: Icons.trending_up_rounded,
                value: _ProfitProductFilter.rentables,
                selected: selected,
                palette: palette,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: 7),
              _ProfitFilterChip(
                label: 'Margen bajo',
                icon: Icons.speed_rounded,
                value: _ProfitProductFilter.margenBajo,
                selected: selected,
                palette: palette,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: 7),
              _ProfitFilterChip(
                label: 'Pérdidas',
                icon: Icons.trending_down_rounded,
                value: _ProfitProductFilter.perdidas,
                selected: selected,
                palette: palette,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: 7),
              _ProfitFilterChip(
                label: 'Sin costo',
                icon: Icons.help_outline_rounded,
                value: _ProfitProductFilter.sinCosto,
                selected: selected,
                palette: palette,
                onSelected: onFilterChanged,
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              filters,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 245, height: 40, child: search),
            const SizedBox(width: 12),
            Expanded(child: filters),
          ],
        );
      },
    );
  }
}

class _ProfitFilterChip extends StatelessWidget {
  const _ProfitFilterChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final _ProfitProductFilter value;
  final _ProfitProductFilter selected;
  final AppPalette palette;
  final ValueChanged<_ProfitProductFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? palette.secondary.withOpacity(0.14)
              : palette.background.withOpacity(0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? palette.secondary.withOpacity(0.32)
                : palette.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? palette.secondary : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? palette.secondary : palette.textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitViewToggle extends StatelessWidget {
  const _ProfitViewToggle({
    required this.tableView,
    required this.palette,
    required this.onChanged,
  });

  final bool tableView;
  final AppPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfitViewButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Ver tarjetas',
            active: !tableView,
            palette: palette,
            onTap: () => onChanged(false),
          ),
          _ProfitViewButton(
            icon: Icons.table_rows_rounded,
            tooltip: 'Ver tabla',
            active: tableView,
            palette: palette,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ProfitViewButton extends StatelessWidget {
  const _ProfitViewButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? palette.secondary.withOpacity(0.14) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? palette.secondary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProfitProductGrid extends StatelessWidget {
  const _ProfitProductGrid({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 1040
                ? 2
                : 3;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final row in rows)
              SizedBox(
                width: width,
                child: _ProfitProductCard(row: row, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _ProfitProductCard extends StatelessWidget {
  const _ProfitProductCard({required this.row, required this.palette});

  final Map<String, dynamic> row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final profit = _toDouble(row['ganancia_bruta_periodo']);
    final margin = _toDouble(row['margen_bruto_porcentaje']);
    final unitCost = _toDouble(row['costo_unitario_actual']);
    final status = _profitProductStatus(profit, margin, unitCost, palette);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: status.color,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(status.icon, color: status.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayValue(row['producto']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _displayValue(row['sucursal']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GANANCIA',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _displayValue(profit, currency: true),
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _displayValue(margin, percentage: true),
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.cardBorder),
          const SizedBox(height: 11),
          _ProfitProductValueRow(
            label: 'Ingresos',
            value: _displayValue(row['ingresos_periodo'], currency: true),
            palette: palette,
          ),
          const SizedBox(height: 7),
          _ProfitProductValueRow(
            label: 'Costo vendido',
            value: _displayValue(row['costo_ventas_periodo'], currency: true),
            palette: palette,
          ),
          const SizedBox(height: 7),
          _ProfitProductValueRow(
            label: 'Unidades vendidas',
            value: _displayValue(row['unidades_vendidas_periodo']),
            palette: palette,
          ),
          const SizedBox(height: 7),
          _ProfitProductValueRow(
            label: 'Ganancia por unidad',
            value: _displayValue(row['ganancia_unitaria_actual'], currency: true),
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _ProfitProductValueRow extends StatelessWidget {
  const _ProfitProductValueRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _ProfitProductStatus {
  const _ProfitProductStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

_ProfitProductStatus _profitProductStatus(
  double profit,
  double margin,
  double unitCost,
  AppPalette palette,
) {
  if (unitCost <= 0) {
    return _ProfitProductStatus(
      'Sin costo',
      Icons.help_outline_rounded,
      Colors.orange.shade700,
    );
  }
  if (profit < 0) {
    return const _ProfitProductStatus(
      'Pérdida',
      Icons.trending_down_rounded,
      Colors.redAccent,
    );
  }
  if (margin < 20) {
    return _ProfitProductStatus(
      'Margen bajo',
      Icons.speed_rounded,
      palette.warning,
    );
  }
  return _ProfitProductStatus(
    'Rentable',
    Icons.trending_up_rounded,
    palette.success,
  );
}


enum _ProfitOrderFilter { pedirAhora, todos, sinConfigurar, sobrestock }

enum _OrderWorkspaceFilter { sugeridos, todos, criticos, seleccionados, sinCosto }

class _NextOrderContent extends ConsumerStatefulWidget {
  const _NextOrderContent({
    required this.definition,
    required this.payload,
    required this.metrics,
    required this.palette,
  });

  final _ReportDefinition definition;
  final _ReportPayload payload;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  ConsumerState<_NextOrderContent> createState() =>
      _NextOrderContentState();
}

class _NextOrderContentState extends ConsumerState<_NextOrderContent> {
  static const _whatsappParameterCode = 'PEDIDO_WHATSAPP_DESTINO';

  _ProfitOrderFilter _filter = _ProfitOrderFilter.pedirAhora;
  _OrderWorkspaceFilter _workspaceFilter = _OrderWorkspaceFilter.sugeridos;
  final Map<int, int> _selectedPresentations = <int, int>{};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  bool _showInventoryDetail = false;
  bool _confirming = false;
  bool _exportingSelection = false;
  bool _sendingWhatsapp = false;
  int? _confirmedOrderId;
  String? _confirmedWhatsapp;
  double _confirmedPaid = 0;
  double _confirmedBalance = 0;
  String? _confirmedPaymentStatus;
  List<Map<String, dynamic>> _confirmedRows = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _confirmedOrders = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _orderDestinations = const <Map<String, dynamic>>[];
  final Map<int, int?> _selectedDestinationByProduct = <int, int?>{};
  Future<List<Map<String, dynamic>>>? _orderHistoryFuture;
  int? _orderHistoryBranchId;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshOrderHistory();
      _loadOrderDestinations();
    });
  }

  @override
  void didUpdateWidget(covariant _NextOrderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.payload.rows, widget.payload.rows)) {
      _initializeSelection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshOrderHistory();
        _loadOrderDestinations();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  void _initializeSelection() {
    _selectedPresentations.clear();
    var hasSuggested = false;
    for (final row in widget.payload.rows) {
      final productId = _productId(row);
      final suggested = _toDouble(row['presentaciones_pedir']).ceil();
      if (productId != null &&
          suggested > 0 &&
          _purchasePresentationCost(row) > 0) {
        hasSuggested = true;
        _selectedPresentations[productId] = suggested;
      }
    }
    if (!hasSuggested && _workspaceFilter == _OrderWorkspaceFilter.sugeridos) {
      _workspaceFilter = _OrderWorkspaceFilter.todos;
    }
    _confirmedOrderId = null;
    _confirmedWhatsapp = null;
    _confirmedPaid = 0;
    _confirmedBalance = 0;
    _confirmedPaymentStatus = null;
    _confirmedRows = const <Map<String, dynamic>>[];
    _confirmedOrders = const <Map<String, dynamic>>[];
  }

  int? _productId(Map<String, dynamic> row) =>
      (row['producto_id'] as num?)?.toInt();

  double _purchasePresentationCost(Map<String, dynamic> row) =>
      _orderPresentationCost(row);

  List<Map<String, dynamic>> get _orderRows {
    final rows = widget.payload.rows
        .where((row) => _productId(row) != null)
        .toList(growable: false)
      ..sort((a, b) {
        final aSuggested = _toDouble(a['unidades_pedir']) > 0;
        final bSuggested = _toDouble(b['unidades_pedir']) > 0;
        if (aSuggested != bSuggested) return aSuggested ? -1 : 1;
        final stockCompare = _toDouble(a['stock_actual'])
            .compareTo(_toDouble(b['stock_actual']));
        if (stockCompare != 0) return stockCompare;
        return (a['producto'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['producto'] ?? '').toString().toLowerCase());
      });
    return rows;
  }

  List<Map<String, dynamic>> get _suggestedOrderRows => _orderRows
      .where((row) => _toDouble(row['unidades_pedir']) > 0)
      .toList(growable: false);

  List<Map<String, dynamic>> get _selectedRows {
    final rows = <Map<String, dynamic>>[];
    for (final source in _orderRows) {
      final productId = _productId(source);
      final presentations =
          productId == null ? null : _selectedPresentations[productId];
      if (productId == null || presentations == null || presentations <= 0) {
        continue;
      }
      final factor = math.max(1.0, _toDouble(source['unidades_por_presentacion']));
      final units = presentations * factor;
      final current = _toDouble(source['stock_actual']);
      final cost = _purchasePresentationCost(source);
      final subtotal = _orderSubtotal(
        source,
        presentations: presentations.toDouble(),
      );
      rows.add(<String, dynamic>{
        ...source,
        'presentaciones_pedir': presentations,
        'unidades_pedir': units,
        'stock_proyectado': current + units,
        'costo_presentacion_actual': cost,
        'costo_pedido_estimado': subtotal,
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> get _filteredRows {
    return widget.payload.rows.where((row) {
      final status = (row['estado_reposicion'] ?? '').toString().toUpperCase();
      return switch (_filter) {
        _ProfitOrderFilter.pedirAhora =>
          status == 'PEDIR_AHORA' || status == 'STOCK_NEGATIVO',
        _ProfitOrderFilter.sinConfigurar => status == 'SIN_CONFIGURAR',
        _ProfitOrderFilter.sobrestock => status == 'SOBRESTOCK',
        _ProfitOrderFilter.todos => true,
      };
    }).toList(growable: false);
  }


  bool _matchesWorkspaceFilter(Map<String, dynamic> row) {
    final productId = _productId(row);
    final status = (row['estado_reposicion'] ?? '').toString().toUpperCase();
    final stock = _toDouble(row['stock_actual']);
    return switch (_workspaceFilter) {
      _OrderWorkspaceFilter.sugeridos => _toDouble(row['unidades_pedir']) > 0,
      _OrderWorkspaceFilter.todos => true,
      _OrderWorkspaceFilter.criticos =>
        stock <= 0 || status == 'STOCK_NEGATIVO',
      _OrderWorkspaceFilter.seleccionados =>
        productId != null && _selectedPresentations.containsKey(productId),
      _OrderWorkspaceFilter.sinCosto => _purchasePresentationCost(row) <= 0,
    };
  }

  List<Map<String, dynamic>> get _visibleOrderRows {
    final query = _searchController.text.trim().toLowerCase();
    final rows = _orderRows.where((row) {
      if (!_matchesWorkspaceFilter(row)) return false;
      if (query.isEmpty) return true;
      final searchable = [
        row['producto'],
        row['presentacion_compra'],
        row['estado_reposicion'],
      ].whereType<Object>().map((value) => value.toString().toLowerCase()).join(' ');
      return searchable.contains(query);
    }).toList(growable: true);
    rows.sort((a, b) {
      final aId = _productId(a);
      final bId = _productId(b);
      final aSelected = aId != null && _selectedPresentations.containsKey(aId);
      final bSelected = bId != null && _selectedPresentations.containsKey(bId);
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      final stockCompare = _toDouble(a['stock_actual'])
          .compareTo(_toDouble(b['stock_actual']));
      if (stockCompare != 0) return stockCompare;
      return (a['producto'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['producto'] ?? '').toString().toLowerCase());
    });
    return rows;
  }

  Map<_OrderWorkspaceFilter, int> get _workspaceCounts {
    final rows = _orderRows;
    return <_OrderWorkspaceFilter, int>{
      _OrderWorkspaceFilter.sugeridos:
          rows.where((row) => _toDouble(row['unidades_pedir']) > 0).length,
      _OrderWorkspaceFilter.todos: rows.length,
      _OrderWorkspaceFilter.criticos: rows.where((row) {
        final status = (row['estado_reposicion'] ?? '').toString().toUpperCase();
        return _toDouble(row['stock_actual']) <= 0 || status == 'STOCK_NEGATIVO';
      }).length,
      _OrderWorkspaceFilter.seleccionados: rows.where((row) {
        final id = _productId(row);
        return id != null && _selectedPresentations.containsKey(id);
      }).length,
      _OrderWorkspaceFilter.sinCosto:
          rows.where((row) => _purchasePresentationCost(row) <= 0).length,
    };
  }

  void _selectionChanged(VoidCallback update) {
    setState(() {
      update();
      _confirmedOrderId = null;
      _confirmedWhatsapp = null;
      _confirmedRows = const <Map<String, dynamic>>[];
      _confirmedOrders = const <Map<String, dynamic>>[];
    });
  }

  void _toggleProduct(Map<String, dynamic> row, bool selected) {
    final productId = _productId(row);
    if (productId == null) return;
    if (selected && _purchasePresentationCost(row) <= 0) {
      _showMessage(
        'El producto ${row['producto'] ?? ''} no tiene costo de compra configurado.',
      );
      return;
    }
    _selectionChanged(() {
      if (selected) {
        _selectedPresentations[productId] =
            math.max(1, _toDouble(row['presentaciones_pedir']).ceil());
      } else {
        _selectedPresentations.remove(productId);
      }
    });
  }

  void _changePresentations(Map<String, dynamic> row, int delta) {
    final productId = _productId(row);
    if (productId == null) return;
    _selectionChanged(() {
      final current = _selectedPresentations[productId] ?? 1;
      _selectedPresentations[productId] = math.max(1, current + delta);
    });
  }

  void _selectAll() {
    _selectionChanged(() {
      for (final row in _suggestedOrderRows) {
        final productId = _productId(row);
        if (productId != null && _purchasePresentationCost(row) > 0) {
          _selectedPresentations[productId] =
              math.max(1, _toDouble(row['presentaciones_pedir']).ceil());
        }
      }
    });
  }

  void _clearSelection() {
    _selectionChanged(_selectedPresentations.clear);
  }

  List<Map<String, dynamic>> get _effectiveOrderRows =>
      _confirmedRows.isNotEmpty ? _confirmedRows : _selectedRows;

  List<Map<String, dynamic>> _confirmedDetailsToRows(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) {
      final detail = Map<String, dynamic>.from(item);
      final productId = (detail['prodId'] as num?)?.toInt();
      final base = _selectedRows.cast<Map<String, dynamic>?>().firstWhere(
            (row) => _productId(row ?? const <String, dynamic>{}) == productId,
            orElse: () => null,
          ) ??
          const <String, dynamic>{};
      final presentations = _toDouble(detail['presentaciones']);
      final cost = _toDouble(detail['costoPresentacion']);
      final backendSubtotal = _toDouble(detail['subtotal']);
      final subtotal = backendSubtotal > 0
          ? backendSubtotal
          : presentations * cost;
      return <String, dynamic>{
        ...base,
        'producto_id': detail['prodId'],
        'producto': detail['producto'],
        'presentacion_compra': detail['presentacion'],
        'presentaciones_pedir': detail['presentaciones'],
        'unidades_por_presentacion': detail['unidadesPorPresentacion'],
        'unidades_pedir': detail['unidades'],
        'costo_presentacion_actual': cost,
        'costo_pedido_estimado': subtotal,
      };
    }).toList(growable: false);
  }

  Map<String, dynamic> _selectionMetrics(List<Map<String, dynamic>> rows) =>
      <String, dynamic>{
        'productos_seleccionados': rows.length,
        'presentaciones': _sum(rows, 'presentaciones_pedir'),
        'unidades': _sum(rows, 'unidades_pedir'),
        'total_estimado': _sum(rows, 'costo_pedido_estimado'),
      };

  Future<void> _loadOrderDestinations() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _orderDestinations = const <Map<String, dynamic>>[];
          _selectedDestinationByProduct.clear();
        });
      }
      return;
    }

    try {
      final response = await ref.read(apiClientProvider).get<Object?>(
            '/api/v1/pedidos-compra/destinos',
            (json) => json,
            queryParameters: <String, dynamic>{'sucursalId': branchId},
          );
      final raw = response.data;
      final destinations = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      final defaults = <int, int?>{};
      for (final destination in destinations) {
        final destinationId = (destination['id'] as num?)?.toInt();
        final products = destination['productoIdsPredeterminados'];
        if (destinationId == null || products is! List) continue;
        for (final product in products.whereType<num>()) {
          defaults[product.toInt()] = destinationId;
        }
      }

      if (!mounted) return;
      setState(() {
        _orderDestinations = destinations;
        for (final entry in defaults.entries) {
          _selectedDestinationByProduct.putIfAbsent(
            entry.key,
            () => entry.value,
          );
        }
      });
    } catch (_) {
      // La ausencia temporal de proveedores no debe impedir crear el pedido;
      // se conserva el WhatsApp general como fallback.
    }
  }

  Future<Map<int, int?>?> _chooseOrderDestinations(
    List<Map<String, dynamic>> rows,
  ) async {
    if (_orderDestinations.isEmpty) {
      return <int, int?>{
        for (final row in rows)
          if (_productId(row) != null) _productId(row)!: null,
      };
    }

    final selection = <int, int>{
      for (final row in rows)
        if (_productId(row) != null)
          _productId(row)!:
              _selectedDestinationByProduct[_productId(row)!] ?? 0,
    };

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Distribuir productos por proveedor'),
          content: SizedBox(
            width: 680,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 540),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final productId = _productId(row);
                  if (productId == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          (row['producto'] ?? 'Producto').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<int>(
                          value: selection[productId] ?? 0,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Enviar a',
                            isDense: true,
                          ),
                          items: <DropdownMenuItem<int>>[
                            const DropdownMenuItem<int>(
                              value: 0,
                              child: Text('WhatsApp general'),
                            ),
                            ..._orderDestinations.map((destination) {
                              final id = (destination['id'] as num?)?.toInt();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  (destination['nombre'] ?? 'Proveedor')
                                      .toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).where((item) => item.value != null),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocal(() => selection[productId] = value);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return null;

    final resolved = <int, int?>{
      for (final entry in selection.entries)
        entry.key: entry.value == 0 ? null : entry.value,
    };
    setState(() {
      _selectedDestinationByProduct
        ..clear()
        ..addAll(resolved);
    });
    return resolved;
  }

  Future<List<Map<String, dynamic>>> _loadOrderHistory(
    int branchId,
  ) async {
    final response = await ref.read(apiClientProvider).get<Object?>(
          '/api/v1/pedidos-compra/sucursal/$branchId',
          (json) => json,
          queryParameters: const <String, dynamic>{'conSaldo': false},
        );
    final raw = response.data;
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  void _refreshOrderHistory() {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      setState(() {
        _orderHistoryBranchId = null;
        _orderHistoryFuture =
            Future.value(const <Map<String, dynamic>>[]);
      });
      return;
    }
    setState(() {
      _orderHistoryBranchId = branchId;
      _orderHistoryFuture = _loadOrderHistory(branchId);
    });
  }

  Future<void> _exportSelectedPdf() async {
    final rows = _effectiveOrderRows;
    if (rows.isEmpty || _exportingSelection) return;
    setState(() => _exportingSelection = true);
    try {
      final branchState = ref.read(branchScopeProvider);
      final branch = branchState.activeBranch;
      final printableRows = rows
          .map(
            (row) => <String, dynamic>{
              'producto': row['producto'],
              'presentacion': row['presentacion_compra'],
              'presentaciones': row['presentaciones_pedir'],
              'unidades_por_presentacion': row['unidades_por_presentacion'],
              'unidades': row['unidades_pedir'],
              'stock_actual': row['stock_actual'],
              'stock_proyectado': row['stock_proyectado'],
              'costo_presentacion': row['costo_presentacion_actual'],
              'subtotal': row['costo_pedido_estimado'],
            },
          )
          .toList(growable: false);
      final orderLabel = _confirmedOrders.isEmpty
          ? 'Borrador de pedido'
          : _confirmedOrders.length == 1
              ? 'Pedido #${_confirmedOrderId ?? _confirmedOrders.first['pediId']}'
              : '${_confirmedOrders.length} pedidos confirmados';
      final observation = _observationController.text.trim();
      final bytes = await ReportePdfService().build(
        title: orderLabel,
        description: observation.isEmpty
            ? 'Productos seleccionados para reposición de inventario.'
            : 'Productos seleccionados para reposición. Observación: $observation',
        start: null,
        end: null,
        branchName: branch?.sucuNombre ?? 'Sucursal seleccionada',
        rows: printableRows,
        metrics: _selectionMetrics(rows),
        currencyKeys: const <String>[
          'total_estimado',
          'costo_presentacion',
          'subtotal',
        ],
        percentageKeys: const <String>[],
        chartLabelKey: 'producto',
        chartValueKey: 'unidades',
      );
      final suffix = _confirmedOrders.isEmpty
          ? DateFormat('yyyyMMdd_HHmm').format(DateTime.now())
          : _confirmedOrders.length == 1
              ? '${_confirmedOrderId ?? _confirmedOrders.first['pediId']}'
              : 'multiples_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      final saved = await downloadBytesFile(
        fileName: 'pedido_compra_$suffix.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'PDF del pedido generado correctamente.'
                  : 'La descarga del PDF fue cancelada.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible generar el pedido: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingSelection = false);
    }
  }

  Future<Map<String, dynamic>?> _confirmOrder({
    bool showSuccess = true,
    bool askConfirmation = true,
  }) async {
    final rows = _selectedRows;
    if (rows.isEmpty || _confirming) return null;
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      _showMessage('Selecciona una sucursal antes de confirmar el pedido.');
      return null;
    }

    final destinations = await _chooseOrderDestinations(rows);
    if (destinations == null || !mounted) return null;

    final groups = <int?, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final productId = _productId(row);
      if (productId == null) continue;
      final destinationId = destinations[productId];
      groups.putIfAbsent(destinationId, () => <Map<String, dynamic>>[]).add(row);
    }
    if (groups.isEmpty) return null;

    if (askConfirmation) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            groups.length == 1
                ? 'Confirmar pedido'
                : 'Confirmar ' + groups.length.toString() + ' pedidos',
          ),
          content: Text(
            'Se confirmarán ' +
                rows.length.toString() +
                ' productos por un total estimado de ' +
                _displayValue(
                  _sum(rows, 'costo_pedido_estimado'),
                  currency: true,
                ) +
                '.\n\nBarLytics los dividirá en ' +
                groups.length.toString() +
                (groups.length == 1
                    ? ' pedido según el WhatsApp seleccionado.'
                    : ' pedidos independientes según cada proveedor/WhatsApp.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return null;
    }

    setState(() => _confirming = true);
    try {
      final response = await ref.read(apiClientProvider).post<Object?>(
            '/api/v1/pedidos-compra/confirmar-multiple',
            <String, dynamic>{
              'sucuId': branchId,
              'observacion': _observationController.text.trim(),
              'grupos': groups.entries.map((entry) {
                final group = <String, dynamic>{
                  'detalles': entry.value
                      .map(
                        (row) => <String, dynamic>{
                          'prodId': _productId(row),
                          'presentaciones':
                              _toDouble(row['presentaciones_pedir']).round(),
                        },
                      )
                      .toList(growable: false),
                };
                if (entry.key != null) group['destinoId'] = entry.key;
                return group;
              }).toList(growable: false),
            },
            (json) => json,
          );

      final raw = response.data;
      final created = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (!mounted || created.isEmpty) return null;

      final confirmedRows = <Map<String, dynamic>>[
        for (final order in created)
          ..._confirmedDetailsToRows(order['detalles']),
      ];
      setState(() {
        _confirmedOrders = List<Map<String, dynamic>>.unmodifiable(created);
        _confirmedOrderId = created.length == 1
            ? (created.first['pediId'] as num?)?.toInt()
            : null;
        _confirmedWhatsapp = created.length == 1
            ? created.first['whatsappDestino']?.toString()
            : null;
        _confirmedPaid = created.fold<double>(
          0,
          (value, order) => value + _toDouble(order['totalPagado']),
        );
        _confirmedBalance = created.fold<double>(
          0,
          (value, order) => value + _toDouble(order['saldoPendiente']),
        );
        _confirmedPaymentStatus = created.length == 1
            ? created.first['estadoPago']?.toString()
            : null;
        _confirmedRows = confirmedRows;
      });
      _refreshOrderHistory();

      if (showSuccess) {
        final ids = created
            .map((order) => (order['pediId'] as num?)?.toInt())
            .whereType<int>()
            .map((id) => '#' + id.toString())
            .join(', ');
        _showMessage(
          created.length == 1
              ? 'Pedido ' + ids + ' confirmado correctamente.'
              : created.length.toString() +
                  ' pedidos generados correctamente: ' +
                  ids +
                  '.',
        );
      }
      return created.first;
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No fue posible confirmar los pedidos. No se guardó una creación parcial: ' +
              error.toString(),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<String?> _loadWhatsappNumber() async {
    final branchState = ref.read(branchScopeProvider);
    final branch = branchState.activeBranch;
    final query = <String, dynamic>{};
    if (branch?.emprId != null) query['empresaId'] = branch!.emprId;
    if (branch?.sucuId != null) query['sucursalId'] = branch!.sucuId;
    final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          '/api/v1/parametros/codigo/$_whatsappParameterCode',
          (json) => json is Map
              ? Map<String, dynamic>.from(json)
              : <String, dynamic>{},
          queryParameters: query,
        );
    final data = response.data ?? <String, dynamic>{};
    final raw = (data['paraValor'] ?? data['paraValorDefecto'] ?? '').toString();
    return _normalizeWhatsapp(raw);
  }

  String? _normalizeWhatsapp(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 && digits.startsWith('3')) {
      digits = '57$digits';
    }
    return digits.length >= 10 ? digits : null;
  }

  Future<String> _loadCompanyName(int? companyId) async {
    try {
      final response =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>(
                '/api/v1/profile',
                (json) => json is Map
                    ? Map<String, dynamic>.from(json)
                    : <String, dynamic>{},
              );
      final data = response.data ?? const <String, dynamic>{};
      final commercialName =
          data['empresaNombreComercial']?.toString().trim() ?? '';
      final businessName =
          data['empresaRazonSocial']?.toString().trim() ?? '';
      if (commercialName.isNotEmpty) return commercialName;
      if (businessName.isNotEmpty) return businessName;
    } catch (_) {
      // La consulta del nombre no debe impedir abrir WhatsApp.
    }
    return companyId == null ? 'Empresa no identificada' : 'Empresa $companyId';
  }

  String _buildWhatsappMessage(
    List<Map<String, dynamic>> rows,
    String companyName,
    String branchName, {
    int? orderId,
    String? destinationName,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        '*PEDIDO DE COMPRA' +
            (orderId == null ? '' : ' #' + orderId.toString()) +
            '*',
      )
      ..writeln('*Empresa:* ' + companyName)
      ..writeln('*Sucursal:* ' + branchName);
    if (destinationName != null && destinationName.trim().isNotEmpty) {
      buffer.writeln('*Proveedor:* ' + destinationName.trim());
    }
    buffer
      ..writeln(
        '*Fecha:* ' +
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      )
      ..writeln()
      ..writeln('*Productos:*');

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final presentations = _displayValue(row['presentaciones_pedir']);
      final presentation =
          (row['presentacion_compra'] ?? 'Unidad').toString();
      final units = _displayValue(row['unidades_pedir']);
      final subtotal =
          _displayValue(row['costo_pedido_estimado'], currency: true);
      buffer
        ..writeln(
          (index + 1).toString() +
              '. *' +
              (row['producto'] ?? 'Producto').toString() +
              '*',
        )
        ..writeln(
          '   ' +
              presentations +
              ' ' +
              presentation +
              ' (' +
              units +
              ' unidades) - ' +
              subtotal,
        );
    }
    buffer
      ..writeln()
      ..writeln(
        '*Total estimado:* ' +
            _displayValue(
              _sum(rows, 'costo_pedido_estimado'),
              currency: true,
            ),
      );
    final observation = _observationController.text.trim();
    if (observation.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('*Observación:* ' + observation);
    }
    buffer
      ..writeln()
      ..write('Generado desde BarLytics.');
    return buffer.toString();
  }

  Future<Map<String, dynamic>?> _selectConfirmedOrderForWhatsapp() async {
    if (_confirmedOrders.isEmpty) return null;
    if (_confirmedOrders.length == 1) return _confirmedOrders.first;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selecciona el pedido a enviar'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _confirmedOrders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = _confirmedOrders[index];
              final id = (order['pediId'] as num?)?.toInt();
              final destination =
                  order['destinoNombre']?.toString().trim().isNotEmpty == true
                      ? order['destinoNombre'].toString()
                      : 'WhatsApp general';
              final phone =
                  order['whatsappDestino']?.toString().trim() ?? '';
              return ListTile(
                leading: const Icon(Icons.message_outlined),
                title: Text(
                  (id == null ? 'Pedido' : 'Pedido #' + id.toString()) +
                      ' · ' +
                      destination,
                ),
                subtitle: Text(
                  phone.isEmpty
                      ? 'Sin número específico; se usará el general.'
                      : phone,
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => Navigator.pop(dialogContext, order),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsapp() async {
    if ((_selectedRows.isEmpty && _confirmedOrders.isEmpty) ||
        _sendingWhatsapp) {
      return;
    }

    if (_confirmedOrders.isEmpty) {
      final confirmFirst = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar antes de enviar'),
          content: const Text(
            'Para mantener la trazabilidad, primero se crearán los pedidos separados por proveedor/WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar y continuar'),
            ),
          ],
        ),
      );
      if (confirmFirst != true || !mounted) return;
      final confirmed = await _confirmOrder(
        showSuccess: false,
        askConfirmation: false,
      );
      if (confirmed == null || !mounted) return;
    }

    final order = await _selectConfirmedOrderForWhatsapp();
    if (order == null || !mounted) return;

    final rows = _confirmedDetailsToRows(order['detalles']);
    if (rows.isEmpty) {
      _showMessage('El pedido seleccionado no tiene productos para enviar.');
      return;
    }

    setState(() => _sendingWhatsapp = true);
    try {
      final number =
          _normalizeWhatsapp(order['whatsappDestino']?.toString() ?? '') ??
              await _loadWhatsappNumber();
      if (number == null) {
        _showMessage(
          'Configura un WhatsApp para el proveedor o el número general de la sucursal.',
        );
        return;
      }
      final branch = ref.read(branchScopeProvider).activeBranch;
      final companyName = await _loadCompanyName(branch?.emprId);
      final message = _buildWhatsappMessage(
        rows,
        companyName,
        branch?.sucuNombre ?? 'Sucursal seleccionada',
        orderId: (order['pediId'] as num?)?.toInt(),
        destinationName: order['destinoNombre']?.toString(),
      );
      final uri = Uri.parse(
        'https://wa.me/' +
            number +
            '?text=' +
            Uri.encodeComponent(message),
      );
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('No fue posible abrir WhatsApp en este dispositivo.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No fue posible preparar el mensaje de WhatsApp: ' +
              error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingWhatsapp = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allRows = widget.payload.rows;
    final orderRows = _orderRows;
    final suggestedRows = _suggestedOrderRows;
    final selectedRows = _selectedRows;
    final visibleRows = _visibleOrderRows;
    final filteredRows = _rowsForDefinition(widget.definition, _filteredRows);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderHealthStrip(
                  allRows: allRows,
                  orderRows: suggestedRows,
                  selectedRows: selectedRows,
                  palette: widget.palette,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _confirming ||
                                _exportingSelection ||
                                _sendingWhatsapp
                            ? null
                            : () {
                                _searchController.clear();
                                setState(
                                  () => _workspaceFilter =
                                      _OrderWorkspaceFilter.todos,
                                );
                              },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                        label: const Text('Pedido manual'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await context.push('/proveedores-pedidos');
                          if (mounted) {
                            await _loadOrderDestinations();
                            _refreshOrderHistory();
                          }
                        },
                        icon: const Icon(Icons.storefront_outlined, size: 17),
                        label: Text(
                          _orderDestinations.isEmpty
                              ? 'Configurar proveedores / WhatsApp'
                              : 'Proveedores / WhatsApp (' +
                                  _orderDestinations.length.toString() +
                                  ')',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: widget.palette.surface.withOpacity(
                      widget.palette.darkBackground ? 0.92 : 0.98,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: widget.palette.cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: _OrderWorkspaceToolbar(
                          controller: _searchController,
                          selectedFilter: _workspaceFilter,
                          counts: _workspaceCounts,
                          selectedCount: selectedRows.length,
                          palette: widget.palette,
                          busy: _confirming ||
                              _exportingSelection ||
                              _sendingWhatsapp,
                          onSearchChanged: (_) => setState(() {}),
                          onClearSearch: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          onFilterChanged: (value) =>
                              setState(() => _workspaceFilter = value),
                          onSelectAll: _selectAll,
                          onClearSelection: _clearSelection,
                        ),
                      ),
                      Divider(height: 1, color: widget.palette.cardBorder),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: orderRows.isEmpty
                            ? _PositiveEmptyState(
                                palette: widget.palette,
                                message:
                                    'No hay productos disponibles para construir un pedido.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (suggestedRows.isEmpty) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: widget.palette.success.withOpacity(.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: widget.palette.success.withOpacity(.20),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            color: widget.palette.success,
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              'El inventario está cubierto. Puedes crear un pedido manual seleccionando cualquier producto del catálogo.',
                                              style: TextStyle(
                                                color: widget.palette.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 1040;
                                  final products = _OrderProductList(
                                    rows: visibleRows,
                                    selectedPresentations:
                                        _selectedPresentations,
                                    palette: widget.palette,
                                    busy: _confirming ||
                                        _exportingSelection ||
                                        _sendingWhatsapp,
                                    onToggle: _toggleProduct,
                                    onChangePresentations:
                                        _changePresentations,
                                  );
                                  final summary = _OrderCartSummary(
                                    selectedRows: selectedRows,
                                    palette: widget.palette,
                                    observationController:
                                        _observationController,
                                    confirmedOrderId: _confirmedOrderId,
                                    confirmedOrderCount: _confirmedOrders.length,
                                    confirmedPaid: _confirmedPaid,
                                    confirmedBalance: _confirmedBalance,
                                    confirmedPaymentStatus:
                                        _confirmedPaymentStatus,
                                    busy: _confirming ||
                                        _exportingSelection ||
                                        _sendingWhatsapp,
                                    confirming: _confirming,
                                    exporting: _exportingSelection,
                                    sendingWhatsapp: _sendingWhatsapp,
                                    onExportPdf: _exportSelectedPdf,
                                    onConfirm: () {
                                      _confirmOrder(showSuccess: true);
                                    },
                                    onWhatsapp: _sendWhatsapp,
                                  );
                                  if (!wide) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        products,
                                        const SizedBox(height: 12),
                                        summary,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: products),
                                      const SizedBox(width: 12),
                                      SizedBox(width: 350, child: summary),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _OrderHistoryPanel(
                  future: _orderHistoryFuture,
                  branchId: _orderHistoryBranchId,
                  palette: widget.palette,
                  onRefresh: _refreshOrderHistory,
                ),
                const SizedBox(height: 12),
                _OrderInventoryDiagnostics(
                  expanded: _showInventoryDetail,
                  allRows: allRows,
                  filteredRows: filteredRows,
                  selectedFilter: _filter,
                  definition: widget.definition,
                  palette: widget.palette,
                  onToggle: () => setState(
                    () => _showInventoryDetail = !_showInventoryDetail,
                  ),
                  onFilterChanged: (value) => setState(() => _filter = value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}


class _OrderHistoryPanel extends StatelessWidget {
  const _OrderHistoryPanel({
    required this.future,
    required this.branchId,
    required this.palette,
    required this.onRefresh,
  });

  final Future<List<Map<String, dynamic>>>? future;
  final int? branchId;
  final AppPalette palette;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(
          palette.darkBackground ? 0.92 : 0.98,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: palette.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de pedidos y pagos',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total, abonos, saldo pendiente y trazabilidad de cada pedido confirmado.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar pedidos',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          if (branchId == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _PositiveEmptyState(
                palette: palette,
                message: 'Selecciona una sucursal para consultar sus pedidos.',
              ),
            )
          else
            FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(22),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'No fue posible cargar el historial de pedidos.',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _PositiveEmptyState(
                      palette: palette,
                      message:
                          'Todavía no hay pedidos confirmados para esta sucursal.',
                    ),
                  );
                }

                final total = _sum(rows, 'totalEstimado');
                final paid = _sum(rows, 'totalPagado');
                final balance = _sum(rows, 'saldoPendiente');
                final pending = rows
                    .where(
                      (row) => _toDouble(row['saldoPendiente']) > 0.009,
                    )
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              constraints.maxWidth < 620 ? 2 : 4;
                          const gap = 8.0;
                          final width =
                              (constraints.maxWidth -
                                      gap * (columns - 1)) /
                                  columns;
                          final items = [
                            (
                              'Pedidos',
                              '${rows.length}',
                              Icons.inventory_2_outlined,
                            ),
                            (
                              'Comprado',
                              _displayValue(total, currency: true),
                              Icons.shopping_cart_checkout_rounded,
                            ),
                            (
                              'Pagado',
                              _displayValue(paid, currency: true),
                              Icons.payments_outlined,
                            ),
                            (
                              'Pendiente',
                              _displayValue(balance, currency: true),
                              pending > 0
                                  ? Icons.schedule_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                          ];
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final item in items)
                                SizedBox(
                                  width: width,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: palette.background.withOpacity(.28),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: palette.cardBorder.withOpacity(.65),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.$3,
                                          color: palette.secondary,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.$2,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              Text(
                                                item.$1,
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: palette.cardBorder),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1040 ? 2 : 1;
                          const gap = 10.0;
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final row in rows)
                                SizedBox(
                                  width: width,
                                  child: _OrderHistoryRow(
                                    row: row,
                                    palette: palette,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OrderHistoryRow extends StatelessWidget {
  const _OrderHistoryRow({
    required this.row,
    required this.palette,
  });

  final Map<String, dynamic> row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final id = (row['pediId'] as num?)?.toInt();
    final total = _toDouble(row['totalEstimado']);
    final paid = _toDouble(row['totalPagado']);
    final balance = _toDouble(row['saldoPendiente']);
    final status = (row['estadoPago'] ?? 'PENDIENTE')
        .toString()
        .toUpperCase();
    final orderStatus =
        (row['estado'] ?? 'CONFIRMADO').toString().toUpperCase();
    final provider = (row['destinoNombre'] ?? '').toString().trim();
    final whatsapp = (row['whatsappDestino'] ?? '').toString().trim();
    final observation = (row['observacion'] ?? '').toString().trim();
    final payments = row['pagos'] is List
        ? (row['pagos'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final details = row['detalles'] is List
        ? (row['detalles'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final tone = status == 'PAGADO'
        ? palette.success
        : status == 'PAGO_PARCIAL'
            ? palette.warning
            : Colors.orangeAccent;
    final paidProgress =
        total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0).toDouble();

    Widget metric(String label, double value, {Color? valueColor}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(.34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.cardBorder.withOpacity(.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _displayValue(value, currency: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? .24 : .42,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              orderStatus == 'RECIBIDO'
                  ? Icons.inventory_2_rounded
                  : Icons.local_shipping_outlined,
              color: tone,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  id == null ? 'Pedido confirmado' : 'Pedido #$id',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
              _OrderPaymentStatusBadge(status: status, color: tone),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.isNotEmpty || row['fecha'] != null)
                  Row(
                    children: [
                      if (provider.isNotEmpty) ...[
                        Icon(
                          Icons.storefront_outlined,
                          color: palette.secondary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.8,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (row['fecha'] != null)
                        Text(
                          _orderHistoryDate(row['fecha']),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 9.4,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    metric('Total', total),
                    const SizedBox(width: 6),
                    metric('Pagado', paid, valueColor: palette.success),
                    const SizedBox(width: 6),
                    metric(
                      'Pendiente',
                      balance,
                      valueColor: balance > 0 ? tone : palette.success,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: paidProgress,
                    minHeight: 5,
                    backgroundColor: palette.cardBorder.withOpacity(.45),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  orderStatus == 'RECIBIDO'
                      ? 'Mercancía recibida · ${details.length} producto${details.length == 1 ? '' : 's'}'
                      : 'Pendiente de recepción · ${details.length} producto${details.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: orderStatus == 'RECIBIDO'
                        ? palette.success
                        : palette.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.4,
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (whatsapp.isNotEmpty || observation.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: palette.surface.withOpacity(.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.cardBorder.withOpacity(.55)),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (whatsapp.isNotEmpty)
                      Text(
                        'WhatsApp: $whatsapp',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (observation.isNotEmpty)
                      Text(
                        'Nota: $observation',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final paymentPanel = _OrderHistorySubPanel(
                  title: 'Pagos',
                  icon: Icons.payments_outlined,
                  palette: palette,
                  child: payments.isEmpty
                      ? Text(
                          balance > 0
                              ? 'Sin abonos registrados. El pedido sigue pendiente de pago.'
                              : 'No hay pagos registrados.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < payments.length; i++) ...[
                              _OrderPaymentRow(
                                payment: payments[i],
                                palette: palette,
                              ),
                              if (i != payments.length - 1)
                                const SizedBox(height: 6),
                            ],
                          ],
                        ),
                );

                final detailPanel = _OrderHistorySubPanel(
                  title: 'Productos',
                  icon: Icons.inventory_2_outlined,
                  palette: palette,
                  child: details.isEmpty
                      ? Text(
                          'Sin detalle disponible.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < details.length; i++) ...[
                              _OrderHistoryProductRow(
                                detail: details[i],
                                palette: palette,
                              ),
                              if (i != details.length - 1)
                                const SizedBox(height: 6),
                            ],
                          ],
                        ),
                );

                if (compact) {
                  return Column(
                    children: [
                      paymentPanel,
                      const SizedBox(height: 9),
                      detailPanel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paymentPanel),
                    const SizedBox(width: 9),
                    Expanded(child: detailPanel),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderPaymentStatusBadge extends StatelessWidget {
  const _OrderPaymentStatusBadge({
    required this.status,
    required this.color,
  });

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.20)),
        ),
        child: Text(
          switch (status) {
            'PAGADO' => 'Pagado',
            'PAGO_PARCIAL' => 'Pago parcial',
            _ => 'Pendiente',
          },
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 9,
          ),
        ),
      );
}

class _OrderHistorySubPanel extends StatelessWidget {
  const _OrderHistorySubPanel({
    required this.title,
    required this.icon,
    required this.palette,
    required this.child,
  });

  final String title;
  final IconData icon;
  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(.26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.cardBorder.withOpacity(.60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: palette.secondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _OrderPaymentRow extends StatelessWidget {
  const _OrderPaymentRow({
    required this.payment,
    required this.palette,
  });

  final Map<String, dynamic> payment;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: palette.success,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayValue(
                    _toDouble(payment['valor']),
                    currency: true,
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  '${payment['medio'] ?? 'CAJA'} · ${_orderHistoryDate(payment['fecha'])}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
                if ((payment['observacion'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  Text(
                    payment['observacion'].toString(),
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _OrderHistoryProductRow extends StatelessWidget {
  const _OrderHistoryProductRow({
    required this.detail,
    required this.palette,
  });

  final Map<String, dynamic> detail;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final name = (detail['producto'] ?? 'Producto').toString();
    final presentations = _toDouble(detail['presentaciones']);
    final units = _toDouble(detail['unidades']);
    final subtotal = _toDouble(detail['subtotal']);
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${_displayValue(presentations)} pres. · '
            '${_displayValue(units)} und. · '
            '${_displayValue(subtotal, currency: true)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}

String _orderHistoryDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return 'Sin fecha';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
}

class _OrderHealthStrip extends StatelessWidget {
  const _OrderHealthStrip({
    required this.allRows,
    required this.orderRows,
    required this.selectedRows,
    required this.palette,
  });

  final List<Map<String, dynamic>> allRows;
  final List<Map<String, dynamic>> orderRows;
  final List<Map<String, dynamic>> selectedRows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final exhausted = orderRows
        .where((row) => _toDouble(row['stock_actual']) <= 0)
        .length;
    final missingCost = orderRows
        .where((row) => _orderPresentationCost(row) <= 0)
        .length;
    final recommendedTotal = _sum(orderRows, 'costo_pedido_estimado');
    final selectedTotal = _sum(selectedRows, 'costo_pedido_estimado');
    final items = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'Requieren pedido',
        value: '${orderRows.length}',
        icon: Icons.inventory_2_outlined,
        color: Colors.orange.shade700,
      ),
      (
        label: 'Stock agotado',
        value: '$exhausted',
        icon: Icons.warning_amber_rounded,
        color: exhausted > 0 ? Colors.red.shade600 : Colors.green.shade600,
      ),
      (
        label: 'Sin costo',
        value: '$missingCost',
        icon: Icons.price_change_outlined,
        color: missingCost > 0 ? Colors.red.shade600 : Colors.green.shade600,
      ),
      (
        label: selectedRows.isEmpty ? 'Costo recomendado' : 'Pedido seleccionado',
        value: _displayValue(
          selectedRows.isEmpty ? recommendedTotal : selectedTotal,
          currency: true,
        ),
        icon: Icons.payments_outlined,
        color: palette.actionColor,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.surface.withOpacity(
                      palette.darkBackground ? 0.90 : 0.98,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon, color: item.color, size: 18),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderWorkspaceToolbar extends StatelessWidget {
  const _OrderWorkspaceToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.counts,
    required this.selectedCount,
    required this.palette,
    required this.busy,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  final TextEditingController controller;
  final _OrderWorkspaceFilter selectedFilter;
  final Map<_OrderWorkspaceFilter, int> counts;
  final int selectedCount;
  final AppPalette palette;
  final bool busy;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_OrderWorkspaceFilter> onFilterChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    const labels = <_OrderWorkspaceFilter, String>{
      _OrderWorkspaceFilter.sugeridos: 'Sugeridos',
      _OrderWorkspaceFilter.todos: 'Todos',
      _OrderWorkspaceFilter.criticos: 'Agotados',
      _OrderWorkspaceFilter.seleccionados: 'En pedido',
      _OrderWorkspaceFilter.sinCosto: 'Sin costo',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final search = SizedBox(
              width: compact ? double.infinity : 300,
              child: TextField(
                maxLength: 120,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                controller: controller,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClearSearch,
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                  border: const OutlineInputBorder(),
                ).compactFilter(),
              ),
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onSelectAll,
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: const Text('Agregar sugeridos'),
                ),
                TextButton.icon(
                  onPressed: busy || selectedCount == 0
                      ? null
                      : onClearSelection,
                  icon: const Icon(Icons.remove_done_rounded, size: 17),
                  label: const Text('Vaciar'),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 8),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                search,
                const Spacer(),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final filter in _OrderWorkspaceFilter.values)
              ChoiceChip(
                selected: selectedFilter == filter,
                onSelected: (_) => onFilterChanged(filter),
                visualDensity: VisualDensity.compact,
                label: Text('${labels[filter]} (${counts[filter] ?? 0})'),
                selectedColor: palette.secondary.withOpacity(0.16),
                side: BorderSide(
                  color: selectedFilter == filter
                      ? palette.secondary.withOpacity(0.45)
                      : palette.cardBorder,
                ),
                labelStyle: TextStyle(
                  color: selectedFilter == filter
                      ? palette.secondary
                      : palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OrderProductList extends StatelessWidget {
  const _OrderProductList({
    required this.rows,
    required this.selectedPresentations,
    required this.palette,
    required this.busy,
    required this.onToggle,
    required this.onChangePresentations,
  });

  final List<Map<String, dynamic>> rows;
  final Map<int, int> selectedPresentations;
  final AppPalette palette;
  final bool busy;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final void Function(Map<String, dynamic>, int) onChangePresentations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.playlist_add_check_rounded,
                    color: palette.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Productos del pedido',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      height: 1.2,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} visibles',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: _PositiveEmptyState(
                palette: palette,
                message: 'No hay productos para el filtro o búsqueda actual.',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: palette.cardBorder.withOpacity(0.70)),
              itemBuilder: (context, index) => _OrderProductRow(
                row: rows[index],
                selectedPresentations: selectedPresentations,
                palette: palette,
                busy: busy,
                onToggle: onToggle,
                onChangePresentations: onChangePresentations,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderProductRow extends StatelessWidget {
  const _OrderProductRow({
    required this.row,
    required this.selectedPresentations,
    required this.palette,
    required this.busy,
    required this.onToggle,
    required this.onChangePresentations,
  });

  final Map<String, dynamic> row;
  final Map<int, int> selectedPresentations;
  final AppPalette palette;
  final bool busy;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final void Function(Map<String, dynamic>, int) onChangePresentations;

  @override
  Widget build(BuildContext context) {
    final productId = (row['producto_id'] as num?)?.toInt();
    final selected = productId != null && selectedPresentations.containsKey(productId);
    final count = productId == null ? 0 : selectedPresentations[productId] ?? 0;
    final hasSuggestion = _toDouble(row['unidades_pedir']) > 0;
    final suggested = hasSuggestion
        ? math.max(1, _toDouble(row['presentaciones_pedir']).ceil())
        : 1;
    final factor = math.max(1.0, _toDouble(row['unidades_por_presentacion']));
    final cost = _orderPresentationCost(row);
    final hasCost = cost > 0;
    final subtotal = _orderSubtotal(row, presentations: count.toDouble());
    final units = count * factor;
    final stock = _toDouble(row['stock_actual']);
    final minimum = _toDouble(row['stock_minimo']);
    final maximum = row['stock_maximo'] == null
        ? null
        : _toDouble(row['stock_maximo']);

    final productInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (row['producto'] ?? 'Producto').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.22,
                ),
              ),
            ),
            if (!hasCost)
              Container(
                margin: const EdgeInsets.only(left: 7),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Sin costo',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _MiniStockTrack(
          current: stock,
          minimum: minimum,
          maximum: maximum,
          palette: palette,
        ),
      ],
    );

    final suggestedInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasSuggestion ? 'Sugerido' : 'Pedido manual',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hasSuggestion
              ? '$suggested ${row['presentacion_compra'] ?? 'presentaciones'}'
              : 'Disponible para agregar',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          hasSuggestion
              ? '${_displayValue(suggested * factor)} unidades'
              : 'El stock actual no bloquea el pedido',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final quantity = _CompactOrderStepper(
      enabled: selected && !busy,
      value: count,
      onDecrease: count <= 1 ? null : () => onChangePresentations(row, -1),
      onIncrease: () => onChangePresentations(row, 1),
      palette: palette,
    );

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selected ? _displayValue(subtotal, currency: true) : '—',
          style: TextStyle(
            color: selected ? palette.actionColor : palette.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selected
              ? '${_displayValue(units)} unidades'
              : hasCost
                  ? '${_displayValue(cost, currency: true)} c/u'
                  : 'Configura el costo',
          textAlign: TextAlign.end,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: selected ? palette.secondary.withOpacity(0.055) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final checkbox = Checkbox(
            value: selected,
            visualDensity: VisualDensity.compact,
            onChanged: busy || productId == null || !hasCost
                ? null
                : (value) => onToggle(row, value ?? false),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    checkbox,
                    const SizedBox(width: 3),
                    Expanded(child: productInfo),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(child: suggestedInfo),
                    quantity,
                    const SizedBox(width: 10),
                    SizedBox(width: 98, child: amount),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              checkbox,
              const SizedBox(width: 4),
              Expanded(flex: 5, child: productInfo),
              const SizedBox(width: 14),
              SizedBox(width: 155, child: suggestedInfo),
              const SizedBox(width: 12),
              quantity,
              const SizedBox(width: 16),
              SizedBox(width: 115, child: amount),
            ],
          );
        },
      ),
    );
  }
}

class _CompactOrderStepper extends StatelessWidget {
  const _CompactOrderStepper({
    required this.enabled,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.palette,
  });

  final bool enabled;
  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppControlMetrics.filterHeight,
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: enabled ? onDecrease : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 38),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove_rounded, size: 17),
          ),
          SizedBox(
            width: 34,
            child: Text(
              enabled ? '$value' : '0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? palette.textPrimary : palette.textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1.15,
              ),
            ),
          ),
          IconButton(
            onPressed: enabled ? onIncrease : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 38),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _OrderCartSummary extends StatelessWidget {
  const _OrderCartSummary({
    required this.selectedRows,
    required this.palette,
    required this.observationController,
    required this.confirmedOrderId,
    required this.confirmedOrderCount,
    required this.confirmedPaid,
    required this.confirmedBalance,
    required this.confirmedPaymentStatus,
    required this.busy,
    required this.confirming,
    required this.exporting,
    required this.sendingWhatsapp,
    required this.onExportPdf,
    required this.onConfirm,
    required this.onWhatsapp,
  });

  final List<Map<String, dynamic>> selectedRows;
  final AppPalette palette;
  final TextEditingController observationController;
  final int? confirmedOrderId;
  final int confirmedOrderCount;
  final double confirmedPaid;
  final double confirmedBalance;
  final String? confirmedPaymentStatus;
  final bool busy;
  final bool confirming;
  final bool exporting;
  final bool sendingWhatsapp;
  final VoidCallback onExportPdf;
  final VoidCallback onConfirm;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final confirmed = confirmedOrderCount > 0;
    final total = _sum(selectedRows, 'costo_pedido_estimado');
    final presentations = _sum(selectedRows, 'presentaciones_pedir');
    final units = _sum(selectedRows, 'unidades_pedir');
    final enabled = selectedRows.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.shopping_bag_outlined,
                    color: palette.secondary, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu pedido',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      '${selectedRows.length} productos seleccionados',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OrderSummaryLine(
            label: 'Presentaciones',
            value: _displayValue(presentations),
            palette: palette,
          ),
          _OrderSummaryLine(
            label: 'Unidades',
            value: _displayValue(units),
            palette: palette,
          ),
          Divider(height: 18, color: palette.cardBorder),
          _OrderSummaryLine(
            label: 'Total estimado',
            value: _displayValue(total, currency: true),
            palette: palette,
            emphasized: true,
          ),
          if (selectedRows.isNotEmpty) ...[
            const SizedBox(height: 11),
            for (final row in selectedRows.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        (row['producto'] ?? 'Producto').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_displayValue(row['presentaciones_pedir'])}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            if (selectedRows.length > 4)
              Text(
                '+ ${selectedRows.length - 4} productos más',
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: observationController,
            enabled: !busy && !confirmed,
            minLines: 2,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Observación',
              hintText: 'Entrega, horario o indicaciones',
              prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
              border: OutlineInputBorder(),
              counterText: '',
            ).compactFilter(fixedHeight: false),
          ),
          if (confirmed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          confirmedOrderCount == 1
                              ? 'Pedido #${confirmedOrderId ?? ''} confirmado'
                              : '$confirmedOrderCount pedidos confirmados',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (confirmedOrderCount == 1
                                  ? '${confirmedPaymentStatus ?? 'PENDIENTE'} · '
                                  : '') +
                              'Pagado ${_displayValue(confirmedPaid, currency: true)} · '
                              'Saldo ${_displayValue(confirmedBalance, currency: true)}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          confirmedBalance > 0
                              ? 'Puedes registrar el pago desde Cierre de caja → Registrar salida → Pago de pedido.'
                              : 'Este pedido no tiene saldo pendiente.',
                          style: TextStyle(
                            color: confirmedBalance > 0
                                ? palette.secondary
                                : palette.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 11),
          SizedBox(
            height: AppControlMetrics.filterHeight,
            child: FilledButton.icon(
              onPressed: busy || !enabled || confirmed
                  ? null
                  : onConfirm,
              icon: confirming
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                confirming ? 'Confirmando' : 'Confirmar pedido',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppControlMetrics.filterHeight,
                  child: OutlinedButton.icon(
                    onPressed: busy || !enabled ? null : onExportPdf,
                    icon: exporting
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: Text(
                      exporting ? 'PDF' : 'PDF',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: AppControlMetrics.filterHeight,
                  child: FilledButton.tonalIcon(
                    onPressed: busy || !enabled ? null : onWhatsapp,
                    icon: sendingWhatsapp
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.message_outlined, size: 17),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryLine extends StatelessWidget {
  const _OrderSummaryLine({
    required this.label,
    required this.value,
    required this.palette,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: emphasized ? 12.5 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? palette.actionColor : palette.textPrimary,
              fontSize: emphasized ? 19 : 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderInventoryDiagnostics extends StatelessWidget {
  const _OrderInventoryDiagnostics({
    required this.expanded,
    required this.allRows,
    required this.filteredRows,
    required this.selectedFilter,
    required this.definition,
    required this.palette,
    required this.onToggle,
    required this.onFilterChanged,
  });

  final bool expanded;
  final List<Map<String, dynamic>> allRows;
  final List<Map<String, dynamic>> filteredRows;
  final _ProfitOrderFilter selectedFilter;
  final _ReportDefinition definition;
  final AppPalette palette;
  final VoidCallback onToggle;
  final ValueChanged<_ProfitOrderFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final counts = <_ProfitOrderFilter, int>{
      _ProfitOrderFilter.pedirAhora: allRows.where((row) {
        final status = (row['estado_reposicion'] ?? '').toString().toUpperCase();
        return status == 'PEDIR_AHORA' || status == 'STOCK_NEGATIVO';
      }).length,
      _ProfitOrderFilter.todos: allRows.length,
      _ProfitOrderFilter.sinConfigurar: allRows.where((row) {
        return (row['estado_reposicion'] ?? '').toString().toUpperCase() ==
            'SIN_CONFIGURAR';
      }).length,
      _ProfitOrderFilter.sobrestock: allRows.where((row) {
        return (row['estado_reposicion'] ?? '').toString().toUpperCase() ==
            'SOBRESTOCK';
      }).length,
    };
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Icon(Icons.manage_search_rounded,
                      color: palette.secondary, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnóstico de inventario',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'Revisa mínimos, máximos, sobrestock y productos sin configurar.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: palette.cardBorder),
                  const SizedBox(height: 10),
                  _ProfitOrderFilterBar(
                    selected: selectedFilter,
                    palette: palette,
                    onChanged: onFilterChanged,
                    counts: counts,
                  ),
                  const SizedBox(height: 10),
                  if (filteredRows.isEmpty)
                    _PositiveEmptyState(
                      palette: palette,
                      message: 'No hay productos para el filtro seleccionado.',
                    )
                  else
                    _ReportTable(
                      rows: filteredRows,
                      palette: palette,
                      currencyKeys: definition.currencyKeys,
                      percentageKeys: definition.percentageKeys,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDraftPanel extends StatelessWidget {
  const _OrderDraftPanel({
    required this.rows,
    required this.selectedPresentations,
    required this.selectedRows,
    required this.palette,
    required this.observationController,
    required this.confirmedOrderId,
    required this.busy,
    required this.confirming,
    required this.exporting,
    required this.sendingWhatsapp,
    required this.onToggle,
    required this.onChangePresentations,
    required this.onSelectAll,
    required this.onClear,
    required this.onExportPdf,
    required this.onConfirm,
    required this.onWhatsapp,
  });

  final List<Map<String, dynamic>> rows;
  final Map<int, int> selectedPresentations;
  final List<Map<String, dynamic>> selectedRows;
  final AppPalette palette;
  final TextEditingController observationController;
  final int? confirmedOrderId;
  final bool busy;
  final bool confirming;
  final bool exporting;
  final bool sendingWhatsapp;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final void Function(Map<String, dynamic>, int) onChangePresentations;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onExportPdf;
  final VoidCallback onConfirm;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final total = _sum(selectedRows, 'costo_pedido_estimado');
    final units = _sum(selectedRows, 'unidades_pedir');
    final presentations = _sum(selectedRows, 'presentaciones_pedir');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(0.38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final summary = Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _OrderDraftMetric(
                    label: 'Productos',
                    value: '${selectedRows.length}',
                    palette: palette,
                  ),
                  _OrderDraftMetric(
                    label: 'Presentaciones',
                    value: _displayValue(presentations),
                    palette: palette,
                  ),
                  _OrderDraftMetric(
                    label: 'Unidades',
                    value: _displayValue(units),
                    palette: palette,
                  ),
                  _OrderDraftMetric(
                    label: 'Total estimado',
                    value: _displayValue(total, currency: true),
                    palette: palette,
                    emphasized: true,
                  ),
                ],
              );
              final selectionActions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onSelectAll,
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Seleccionar todo'),
                  ),
                  TextButton.icon(
                    onPressed: busy || selectedRows.isEmpty ? null : onClear,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Limpiar'),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 8),
                    selectionActions,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  selectionActions,
                ],
              );
            },
          ),
        ),
        if (confirmedOrderId != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.28)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Pedido #$confirmedOrderId confirmado. Ya puedes descargarlo o enviarlo por WhatsApp.',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final row in rows)
                  SizedBox(
                    width: width,
                    child: _SelectableOrderCard(
                      row: row,
                      selectedPresentations: selectedPresentations,
                      palette: palette,
                      busy: busy,
                      onToggle: onToggle,
                      onChangePresentations: onChangePresentations,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: observationController,
          enabled: !busy && confirmedOrderId == null,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observación del pedido (opcional)',
            hintText: 'Ejemplo: entregar el viernes antes de las 4:00 p. m.',
            prefixIcon: Icon(Icons.edit_note),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 620;
            final buttons = <Widget>[
              OutlinedButton.icon(
                onPressed: busy || selectedRows.isEmpty ? null : onExportPdf,
                icon: exporting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(exporting ? 'Generando PDF' : 'PDF seleccionado'),
              ),
              FilledButton.icon(
                onPressed: busy ||
                        selectedRows.isEmpty ||
                        confirmedOrderId != null
                    ? null
                    : onConfirm,
                icon: confirming
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(confirming ? 'Confirmando' : 'Confirmar pedido'),
              ),
              FilledButton.tonalIcon(
                onPressed: busy || selectedRows.isEmpty ? null : onWhatsapp,
                icon: sendingWhatsapp
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.message),
                label: Text(
                  sendingWhatsapp ? 'Abriendo WhatsApp' : 'Enviar por WhatsApp',
                ),
              ),
            ];
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    buttons[index],
                    if (index < buttons.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Wrap(spacing: 10, runSpacing: 10, children: buttons);
          },
        ),
      ],
    );
  }
}

class _OrderDraftMetric extends StatelessWidget {
  const _OrderDraftMetric({
    required this.label,
    required this.value,
    required this.palette,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? palette.actionColor : palette.textPrimary,
            fontSize: emphasized ? 16 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SelectableOrderCard extends StatelessWidget {
  const _SelectableOrderCard({
    required this.row,
    required this.selectedPresentations,
    required this.palette,
    required this.busy,
    required this.onToggle,
    required this.onChangePresentations,
  });

  final Map<String, dynamic> row;
  final Map<int, int> selectedPresentations;
  final AppPalette palette;
  final bool busy;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final void Function(Map<String, dynamic>, int) onChangePresentations;

  @override
  Widget build(BuildContext context) {
    final productId = (row['producto_id'] as num?)?.toInt();
    final selected = productId != null &&
        selectedPresentations.containsKey(productId);
    final count = productId == null ? 0 : selectedPresentations[productId] ?? 0;
    final factor = math.max(1.0, _toDouble(row['unidades_por_presentacion']));
    final cost = _orderPresentationCost(row);
    final subtotal = _orderSubtotal(row, presentations: count.toDouble());
    final hasPurchaseCost = cost > 0;
    final units = count * factor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? palette.secondary.withOpacity(0.08)
            : palette.background.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? palette.secondary.withOpacity(0.50)
              : palette.cardBorder,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: busy || productId == null || !hasPurchaseCost
                    ? null
                    : (value) => onToggle(row, value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (row['producto'] ?? 'Producto').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stock ${_displayValue(row['stock_actual'])} · objetivo ${_stockMaximumText(row['stock_maximo'])}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Cantidad',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: busy || !selected || count <= 1
                    ? null
                    : () => onChangePresentations(row, -1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.cardBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  selected ? '$count' : '0',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: busy || !selected
                    ? null
                    : () => onChangePresentations(row, 1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(
            '$count ${row['presentacion_compra'] ?? 'Unidad'} · ${_displayValue(units)} unidades',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasPurchaseCost
                ? 'Costo ${_displayValue(cost, currency: true)} · Subtotal ${_displayValue(subtotal, currency: true)}'
                : 'Sin costo de compra configurado',
            style: TextStyle(
              color: hasPurchaseCost ? palette.actionColor : Colors.orange.shade800,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitVisual extends StatelessWidget {
  const _ProfitVisual({
    required this.rows,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final ingresos = _sum(rows, 'ingresos_periodo');
    final costos = _sum(rows, 'costo_ventas_periodo');
    final ganancia = _sum(rows, 'ganancia_bruta_periodo');
    final maxValue =
        [ingresos.abs(), costos.abs(), ganancia.abs()]
            .fold<double>(
              1,
              (current, value) => math.max(current, value).toDouble(),
            );

    final items = <({String label, double value, IconData icon, Color color})>[
      (
        label: 'Ingresos del periodo',
        value: ingresos,
        icon: Icons.point_of_sale_rounded,
        color: palette.secondary,
      ),
      (
        label: 'Costo de productos vendidos',
        value: costos,
        icon: Icons.shopping_cart_checkout_rounded,
        color: Colors.orange.shade600,
      ),
      (
        label: 'Ganancia bruta realizada',
        value: ganancia,
        icon: Icons.savings_rounded,
        color: ganancia >= 0 ? Colors.green.shade600 : Colors.red.shade600,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ProfitValueBar(
            label: items[index].label,
            value: items[index].value,
            maxValue: maxValue,
            icon: items[index].icon,
            color: items[index].color,
            palette: palette,
          ),
          if (index < items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProfitValueBar extends StatelessWidget {
  const _ProfitValueBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.icon,
    required this.color,
    required this.palette,
  });

  final String label;
  final double value;
  final double maxValue;
  final IconData icon;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0
        ? 0.0
        : (value.abs() / maxValue).clamp(0.04, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.38),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _displayValue(value, currency: true),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: palette.cardBorder.withOpacity(0.40),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusOverview extends StatelessWidget {
  const _OrderStatusOverview({
    required this.rows,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final orderRows =
        rows.where((row) => _toDouble(row['unidades_pedir']) > 0).toList();
    final missingConfig = rows
        .where((row) => row['estado_reposicion'] == 'SIN_CONFIGURAR')
        .length;
    final projectedCost = _sum(orderRows, 'costo_pedido_estimado');

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 1 : 3;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = [
          (
            'Productos para pedir',
            '${orderRows.length}',
            Icons.shopping_basket_rounded,
            Colors.orange.shade700,
          ),
          (
            'Costo estimado',
            _displayValue(projectedCost, currency: true),
            Icons.payments_rounded,
            palette.actionColor,
          ),
          (
            'Sin mínimo configurado',
            '$missingConfig',
            Icons.tune_rounded,
            missingConfig > 0 ? Colors.red.shade600 : Colors.green.shade600,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: item.$4.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: item.$4.withOpacity(0.20)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, color: item.$4),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderHighlights extends StatelessWidget {
  const _OrderHighlights({
    required this.rows,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(6).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1050
                ? 2
                : 3;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final row in visible)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: palette.background.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (row['producto'] ?? 'Producto').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            status:
                                (row['estado_reposicion'] ?? '').toString(),
                            palette: palette,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MiniStockTrack(
                        current: _toDouble(row['stock_actual']),
                        minimum: _toDouble(row['stock_minimo']),
                        maximum: row['stock_maximo'] == null
                            ? null
                            : _toDouble(row['stock_maximo']),
                        palette: palette,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_displayValue(row['presentaciones_pedir'])} ${row['presentacion_compra'] ?? 'presentaciones'} · ${_displayValue(row['unidades_pedir'])} unidades',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Costo estimado ${_displayValue(row['costo_pedido_estimado'], currency: true)}',
                        style: TextStyle(
                          color: palette.actionColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniStockTrack extends StatelessWidget {
  const _MiniStockTrack({
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.palette,
  });

  final double current;
  final double minimum;
  final double? maximum;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final safeMax = maximum == null
        ? math.max(math.max(current, minimum * 2), 1).toDouble()
        : math.max(maximum!, 1).toDouble();
    final currentFraction = (current / safeMax).clamp(0.0, 1.0).toDouble();
    final minimumFraction = (minimum / safeMax).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actual ${_displayValue(current)} · Mín. ${_displayValue(minimum)} · Máx. ${_stockMaximumText(maximum)}',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.cardBorder.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: constraints.maxWidth * currentFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: current <= minimum
                            ? Colors.orange.shade700
                            : Colors.green.shade600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: math.max(
                      0,
                      constraints.maxWidth * minimumFraction - 1,
                    ),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.red.shade600),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProfitOrderFilterBar extends StatelessWidget {
  const _ProfitOrderFilterBar({
    required this.selected,
    required this.palette,
    required this.onChanged,
    required this.counts,
  });

  final _ProfitOrderFilter selected;
  final AppPalette palette;
  final ValueChanged<_ProfitOrderFilter> onChanged;
  final Map<_ProfitOrderFilter, int> counts;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _ProfitOrderFilter.pedirAhora: 'Pedir ahora',
      _ProfitOrderFilter.todos: 'Todos',
      _ProfitOrderFilter.sinConfigurar: 'Sin mínimo',
      _ProfitOrderFilter.sobrestock: 'Sobrestock',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _ProfitOrderFilter.values)
          ChoiceChip(
            selected: selected == filter,
            onSelected: (_) => onChanged(filter),
            avatar: filter == _ProfitOrderFilter.pedirAhora
                ? const Icon(Icons.local_shipping_rounded, size: 16)
                : null,
            label: Text('${labels[filter]} (${counts[filter] ?? 0})'),
            selectedColor: palette.secondary.withOpacity(0.18),
            side: BorderSide(
              color: selected == filter
                  ? palette.secondary.withOpacity(0.45)
                  : palette.cardBorder,
            ),
            labelStyle: TextStyle(
              color: selected == filter
                  ? palette.secondary
                  : palette.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

enum _ReconciliationFilter { diferencias, faltantes, sobrantes, cuadran, todos }

class _InventoryCountReconciliationContent extends StatefulWidget {
  const _InventoryCountReconciliationContent({
    required this.definition,
    required this.payload,
    required this.metrics,
    required this.palette,
  });

  final _ReportDefinition definition;
  final _ReportPayload payload;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  State<_InventoryCountReconciliationContent> createState() =>
      _InventoryCountReconciliationContentState();
}

class _InventoryCountReconciliationContentState
    extends State<_InventoryCountReconciliationContent> {
  _ReconciliationFilter _filter = _ReconciliationFilter.diferencias;

  List<Map<String, dynamic>> get _filteredRows {
    return widget.payload.rows.where((row) {
      final status = (row['estado_conteo'] ?? '').toString().toUpperCase();
      return switch (_filter) {
        _ReconciliationFilter.diferencias => status == 'FALTANTE' || status == 'SOBRANTE',
        _ReconciliationFilter.faltantes => status == 'FALTANTE',
        _ReconciliationFilter.sobrantes => status == 'SOBRANTE',
        _ReconciliationFilter.cuadran => status == 'CUADRA',
        _ReconciliationFilter.todos => true,
      };
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.payload.rows;
    final filteredRows = _filteredRows;
    final differenceRows = rows
        .where((row) => _toDouble(row['diferencia_unidades']) != 0)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricsGrid(
                  metrics: widget.metrics,
                  palette: widget.palette,
                  currencyKeys: widget.definition.currencyKeys,
                  percentageKeys: widget.definition.percentageKeys,
                ),
                const SizedBox(height: 14),
                _ReconciliationOverview(
                  rows: rows,
                  metrics: widget.metrics,
                  palette: widget.palette,
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Diferencias que requieren revisión',
                  subtitle: 'Los productos con mayor diferencia aparecen primero. Rojo representa faltantes y verde sobrantes.',
                  icon: Icons.stacked_bar_chart_rounded,
                  palette: widget.palette,
                  child: _HorizontalBarChart(
                    rows: differenceRows,
                    labelKey: 'producto',
                    valueKey: 'diferencia_unidades',
                    palette: widget.palette,
                    signed: true,
                  ),
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Productos prioritarios',
                  subtitle: 'Comparación visual entre el stock esperado y el conteo físico.',
                  icon: Icons.fact_check_rounded,
                  palette: widget.palette,
                  child: _ReconciliationHighlights(
                    rows: differenceRows,
                    palette: widget.palette,
                    currencyKeys: widget.definition.currencyKeys,
                    percentageKeys: widget.definition.percentageKeys,
                  ),
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Control operativo del conteo',
                  subtitle: 'Filtra el resultado y consulta todos los campos sin perder información.',
                  icon: Icons.rule_folder_rounded,
                  palette: widget.palette,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReconciliationFilterBar(
                        selected: _filter,
                        rows: rows,
                        palette: widget.palette,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _ReportTable(
                          key: ValueKey(_filter),
                          rows: filteredRows,
                          palette: widget.palette,
                          currencyKeys: widget.definition.currencyKeys,
                          percentageKeys: widget.definition.percentageKeys,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReconciliationOverview extends StatelessWidget {
  const _ReconciliationOverview({
    required this.rows,
    required this.metrics,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final missing = rows.where((row) => row['estado_conteo'] == 'FALTANTE').length;
    final surplus = rows.where((row) => row['estado_conteo'] == 'SOBRANTE').length;
    final balanced = rows.where((row) => row['estado_conteo'] == 'CUADRA').length;
    final total = math.max(1, rows.length);
    final accuracy = balanced * 100 / total;
    final netUnits = _sum(rows, 'diferencia_unidades');
    final missingValue = _toDouble(metrics['valor_faltantes']);
    final surplusValue = _toDouble(metrics['valor_sobrantes']);

    final distribution = Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: palette.secondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.donut_large_rounded, color: palette.secondary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultado del conteo',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${accuracy.toStringAsFixed(1)} % de los productos cuadran.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.success.withOpacity(0.22)),
                ),
                child: Text(
                  '$balanced / ${rows.length}',
                  style: TextStyle(
                    color: palette.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  if (missing > 0)
                    Expanded(
                      flex: missing,
                      child: Container(color: Colors.redAccent),
                    ),
                  if (surplus > 0)
                    Expanded(
                      flex: surplus,
                      child: Container(color: palette.success),
                    ),
                  if (balanced > 0)
                    Expanded(
                      flex: balanced,
                      child: Container(color: palette.secondary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _LegendItem(label: 'Faltantes', value: missing, color: Colors.redAccent),
              _LegendItem(label: 'Sobrantes', value: surplus, color: palette.success),
              _LegendItem(label: 'Cuadran', value: balanced, color: palette.secondary),
            ],
          ),
        ],
      ),
    );

    final impact = Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: netUnits < 0 ? Colors.redAccent : palette.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impacto estimado',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valor calculado con el último costo de compra registrado.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _ImpactRow(
            icon: Icons.trending_down_rounded,
            label: 'Valor de faltantes',
            value: CurrencyUtils.format(missingValue),
            color: Colors.redAccent,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _ImpactRow(
            icon: Icons.trending_up_rounded,
            label: 'Valor de sobrantes',
            value: CurrencyUtils.format(surplusValue),
            color: palette.success,
            palette: palette,
          ),
          const Divider(height: 24),
          _ImpactRow(
            icon: Icons.balance_rounded,
            label: 'Balance neto en unidades',
            value: _displayValue(netUnits),
            color: netUnits < 0 ? Colors.redAccent : palette.secondary,
            palette: palette,
            emphasized: true,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(children: [distribution, const SizedBox(height: 12), impact]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: distribution),
            const SizedBox(width: 14),
            Expanded(flex: 4, child: impact),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label $value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppPalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                color: emphasized ? color : palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: emphasized ? 17 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReconciliationFilterBar extends StatelessWidget {
  const _ReconciliationFilterBar({
    required this.selected,
    required this.rows,
    required this.palette,
    required this.onChanged,
  });

  final _ReconciliationFilter selected;
  final List<Map<String, dynamic>> rows;
  final AppPalette palette;
  final ValueChanged<_ReconciliationFilter> onChanged;

  int _count(_ReconciliationFilter filter) {
    return rows.where((row) {
      final status = (row['estado_conteo'] ?? '').toString().toUpperCase();
      return switch (filter) {
        _ReconciliationFilter.diferencias => status == 'FALTANTE' || status == 'SOBRANTE',
        _ReconciliationFilter.faltantes => status == 'FALTANTE',
        _ReconciliationFilter.sobrantes => status == 'SOBRANTE',
        _ReconciliationFilter.cuadran => status == 'CUADRA',
        _ReconciliationFilter.todos => true,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    const values = _ReconciliationFilter.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            _FilterPill(
              label: switch (values[index]) {
                _ReconciliationFilter.diferencias => 'Con diferencia',
                _ReconciliationFilter.faltantes => 'Faltantes',
                _ReconciliationFilter.sobrantes => 'Sobrantes',
                _ReconciliationFilter.cuadran => 'Cuadran',
                _ReconciliationFilter.todos => 'Todos',
              },
              count: _count(values[index]),
              selected: selected == values[index],
              palette: palette,
              color: switch (values[index]) {
                _ReconciliationFilter.faltantes => Colors.redAccent,
                _ReconciliationFilter.sobrantes => palette.success,
                _ReconciliationFilter.cuadran => palette.secondary,
                _ => palette.actionColor,
              },
              onTap: () => onChanged(values[index]),
            ),
            if (index < values.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.palette,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final AppPalette palette;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.16) : palette.background.withOpacity(0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color.withOpacity(0.55) : palette.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.18) : palette.surface.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? color : palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReconciliationHighlights extends StatelessWidget {
  const _ReconciliationHighlights({
    required this.rows,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _PositiveEmptyState(
        palette: palette,
        message: 'Todos los productos contados coinciden con el stock esperado.',
      );
    }

    final sorted = [...rows]
      ..sort((a, b) => _toDouble(b['diferencia_unidades']).abs().compareTo(
            _toDouble(a['diferencia_unidades']).abs(),
          ));
    final visible = sorted.take(6).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 660
            ? 1
            : constraints.maxWidth < 1080
                ? 2
                : 3;
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final row in visible)
              SizedBox(
                width: cardWidth,
                child: _ReconciliationHighlightCard(
                  row: row,
                  palette: palette,
                  currencyKeys: currencyKeys,
                  percentageKeys: percentageKeys,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReconciliationHighlightCard extends StatelessWidget {
  const _ReconciliationHighlightCard({
    required this.row,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final Map<String, dynamic> row;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  Widget build(BuildContext context) {
    final status = (row['estado_conteo'] ?? '').toString().toUpperCase();
    final tone = _statusColor(status, palette);
    final expected = _toDouble(row['stock_esperado']);
    final counted = _toDouble(row['conteo_fisico']);
    final maximum = math.max(1.0, math.max(expected.abs(), counted.abs())).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: palette.panelGradient(tint: tone),
        borderRadius: BorderRadius.circular(palette.radius(20)),
        border: Border.all(color: tone.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _displayValue(row['producto']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status, palette: palette),
            ],
          ),
          const SizedBox(height: 14),
          _ComparisonBar(
            label: 'Esperado',
            value: expected,
            maximum: maximum,
            color: palette.secondary,
            palette: palette,
          ),
          const SizedBox(height: 9),
          _ComparisonBar(
            label: 'Contado',
            value: counted,
            maximum: maximum,
            color: tone,
            palette: palette,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _MiniValue(
                  label: 'Diferencia',
                  value: _displayValue(row['diferencia_unidades']),
                  color: tone,
                  palette: palette,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniValue(
                  label: 'Impacto',
                  value: _displayValue(
                    row['diferencia_valor_compra'],
                    currency: true,
                  ),
                  color: tone,
                  palette: palette,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.color,
    required this.palette,
  });

  final String label;
  final double value;
  final double maximum;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final factor = (value.abs() / maximum).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: palette.background.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * factor,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            _displayValue(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositiveEmptyState extends StatelessWidget {
  const _PositiveEmptyState({required this.palette, required this.message});

  final AppPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.success.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: palette.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.payload,
    required this.metrics,
    required this.palette,
  });

  final _ReportPayload payload;
  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final operationMetrics = <String, dynamic>{
      for (final key in const [
        'numero_ventas',
        'total_vendido',
        'total_propinas',
        'ticket_promedio',
        'unidades_vendidas',
        'productos_con_stock',
        'unidades_en_stock',
        'productos_agotados',
        'productos_stock_negativo',
        'productos_stock_bajo',
      ])
        if (metrics.containsKey(key)) key: metrics[key],
    };

    final financialMetrics = <String, dynamic>{
      for (final key in const [
        'ingresos_periodo',
        'costo_ventas_periodo',
        'ganancia_bruta_periodo',
        'gastos_fijos_periodo',
        'gastos_turno_periodo',
        'gastos_variables_periodo',
        'mano_obra_periodo',
        'gastos_operativos_periodo',
        'ganancia_neta_estimada_periodo',
        'margen_bruto_porcentaje',
        'margen_neto_porcentaje',
      ])
        if (metrics.containsKey(key)) key: metrics[key],
    };

    final cashMetrics = <String, dynamic>{
      for (final key in const [
        'salidas_caja_periodo',
        'gastos_turno_periodo',
        'pagos_pedidos_periodo',
        'pagos_gastos_configurados_periodo',
      ])
        if (metrics.containsKey(key)) key: metrics[key],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReportSectionTitle(
                  title: 'Pulso del negocio',
                  subtitle:
                      'Indicadores principales para saber cuánto se vendió, cuánto se movió y cómo está el inventario.',
                  icon: Icons.monitor_heart_rounded,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _MetricsGrid(
                  metrics: operationMetrics,
                  palette: palette,
                  currencyKeys: const [
                    'total_vendido',
                    'total_propinas',
                    'ticket_promedio',
                  ],
                  percentageKeys: const [],
                ),
                if (financialMetrics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReportSectionTitle(
                    title: 'Resultado financiero',
                    subtitle:
                        'Rentabilidad después de costo de venta, gastos fijos, variables y mano de obra.',
                    icon: Icons.account_balance_rounded,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _ExecutiveFinanceOverview(
                    metrics: financialMetrics,
                    palette: palette,
                  ),
                ],
                if (cashMetrics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReportSectionTitle(
                    title: 'Flujo de caja',
                    subtitle:
                        'Dinero que salió físicamente de caja, separado de los valores que realmente afectan la utilidad.',
                    icon: Icons.swap_vert_circle_rounded,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _MetricsGrid(
                    metrics: cashMetrics,
                    palette: palette,
                    currencyKeys: const [
                      'salidas_caja_periodo',
                      'gastos_turno_periodo',
                      'pagos_pedidos_periodo',
                      'pagos_gastos_configurados_periodo',
                    ],
                    percentageKeys: const [],
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final sales = _Panel(
                      title: 'Ventas por día',
                      subtitle:
                          'Detecta picos y días débiles para ajustar personal, inventario y promociones.',
                      icon: Icons.show_chart_rounded,
                      palette: palette,
                      child: _ReportTimeSeriesChart(
                        rows: payload.chartRows,
                        dateKey: 'fecha',
                        valueKey: 'total',
                        palette: palette,
                        currency: true,
                      ),
                    );
                    final payments = _Panel(
                      title: 'Cómo entra el dinero',
                      subtitle:
                          'Participación del recaudo por medio de pago para controlar concentración y conciliación.',
                      icon: Icons.account_balance_wallet_rounded,
                      palette: palette,
                      child: _HorizontalBarChart(
                        rows: payload.paymentRows,
                        labelKey: 'medio_pago',
                        valueKey: 'total',
                        palette: palette,
                        currency: true,
                      ),
                    );
                    if (compact) {
                      return Column(
                        children: [
                          sales,
                          const SizedBox(height: 14),
                          payments,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sales),
                        const SizedBox(width: 14),
                        Expanded(child: payments),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final products = _Panel(
                      title: 'Productos que mueven la caja',
                      subtitle:
                          'Ranking de los productos que más unidades e ingresos aportaron.',
                      icon: Icons.emoji_events_rounded,
                      palette: palette,
                      child: payload.rows.isEmpty
                          ? _PositiveEmptyState(
                              palette: palette,
                              message:
                                  'No hay productos vendidos en el periodo seleccionado.',
                            )
                          : Column(
                              children: [
                                _HorizontalBarChart(
                                  rows: payload.rows,
                                  labelKey: 'producto',
                                  valueKey: 'cantidad',
                                  palette: palette,
                                ),
                                const SizedBox(height: 12),
                                _ReportTable(
                                  rows: payload.rows,
                                  palette: palette,
                                  currencyKeys: const [
                                    'total',
                                    'precio_promedio',
                                  ],
                                  percentageKeys: const [],
                                ),
                              ],
                            ),
                    );

                    final alerts = _Panel(
                      title: 'Alertas que requieren acción',
                      subtitle:
                          'Productos que conviene revisar físicamente o reponer antes de afectar ventas.',
                      icon: Icons.warning_amber_rounded,
                      palette: palette,
                      child: payload.alertRows.isEmpty
                          ? _PositiveEmptyState(
                              palette: palette,
                              message:
                                  'No se encontraron alertas críticas de inventario en el periodo.',
                            )
                          : Column(
                              children: [
                                _ExecutiveAlertSummary(
                                  rows: payload.alertRows,
                                  palette: palette,
                                ),
                                const SizedBox(height: 12),
                                _ReportTable(
                                  rows: payload.alertRows,
                                  palette: palette,
                                  currencyKeys: const ['valor_vendido'],
                                  percentageKeys: const [
                                    'rotacion_porcentaje',
                                  ],
                                ),
                              ],
                            ),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          products,
                          const SizedBox(height: 14),
                          alerts,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: products),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: alerts),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: palette.secondary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ExecutiveFinanceOverview extends StatelessWidget {
  const _ExecutiveFinanceOverview({
    required this.metrics,
    required this.palette,
  });

  final Map<String, dynamic> metrics;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final ingresos = _toDouble(metrics['ingresos_periodo']);
    final costo = _toDouble(metrics['costo_ventas_periodo']);
    final bruta = _toDouble(metrics['ganancia_bruta_periodo']);
    final fijos = _toDouble(metrics['gastos_fijos_periodo']);
    final gastosTurno = _toDouble(metrics['gastos_turno_periodo']);
    final variables = _toDouble(metrics['gastos_variables_periodo']);
    final variablesConfiguradas =
        (variables - gastosTurno).clamp(0.0, double.infinity).toDouble();
    final manoObra = _toDouble(metrics['mano_obra_periodo']);
    final operativos = _toDouble(metrics['gastos_operativos_periodo']);
    final neta = _toDouble(metrics['ganancia_neta_estimada_periodo']);
    final margenNeto = _toDouble(metrics['margen_neto_porcentaje']);

    final cards = <String, dynamic>{
      'ingresos_periodo': ingresos,
      'costo_ventas_periodo': costo,
      'ganancia_bruta_periodo': bruta,
      'gastos_operativos_periodo': operativos,
      'ganancia_neta_estimada_periodo': neta,
      'margen_neto_porcentaje': margenNeto,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsGrid(
          metrics: cards,
          palette: palette,
          currencyKeys: const [
            'ingresos_periodo',
            'costo_ventas_periodo',
            'ganancia_bruta_periodo',
            'gastos_operativos_periodo',
            'ganancia_neta_estimada_periodo',
          ],
          percentageKeys: const ['margen_neto_porcentaje'],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'De la venta a la utilidad',
          subtitle:
              'Descomposición de lo vendido para entender qué está consumiendo el margen.',
          icon: Icons.stacked_bar_chart_rounded,
          palette: palette,
          child: Column(
            children: [
              _FinanceFlowRow(
                label: 'Ingresos por productos',
                value: ingresos,
                reference: ingresos,
                color: palette.secondary,
                palette: palette,
              ),
              const SizedBox(height: 9),
              _FinanceFlowRow(
                label: 'Costo de productos vendidos',
                value: costo,
                reference: ingresos,
                color: Colors.orange,
                palette: palette,
              ),
              const SizedBox(height: 9),
              _FinanceFlowRow(
                label: 'Gastos fijos',
                value: fijos,
                reference: ingresos,
                color: Colors.blueAccent,
                palette: palette,
              ),
              const SizedBox(height: 9),
              _FinanceFlowRow(
                label: 'Variables configurados',
                value: variablesConfiguradas,
                reference: ingresos,
                color: Colors.amber,
                palette: palette,
              ),
              const SizedBox(height: 9),
              _FinanceFlowRow(
                label: 'Gastos del turno',
                value: gastosTurno,
                reference: ingresos,
                color: Colors.orangeAccent,
                palette: palette,
              ),
              const SizedBox(height: 9),
              _FinanceFlowRow(
                label: 'Mano de obra',
                value: manoObra,
                reference: ingresos,
                color: Colors.deepPurpleAccent,
                palette: palette,
              ),
              const Divider(height: 24),
              _FinanceFlowRow(
                label: 'Ganancia neta estimada',
                value: neta,
                reference: ingresos,
                color: neta >= 0 ? palette.success : Colors.redAccent,
                palette: palette,
                emphasized: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinanceFlowRow extends StatelessWidget {
  const _FinanceFlowRow({
    required this.label,
    required this.value,
    required this.reference,
    required this.color,
    required this.palette,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final double reference;
  final Color color;
  final AppPalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ratio = reference <= 0
        ? 0.0
        : (value.abs() / reference.abs()).clamp(0.0, 1.0).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                  fontSize: emphasized ? 12.5 : 11.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyUtils.format(value),
              style: TextStyle(
                color: emphasized ? color : palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: emphasized ? 13.5 : 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: emphasized ? 10 : 7,
            backgroundColor: palette.cardBorder.withOpacity(.35),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ExecutiveAlertSummary extends StatelessWidget {
  const _ExecutiveAlertSummary({
    required this.rows,
    required this.palette,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final negativos =
        rows.where((row) => _toDouble(row['stock_actual']) < 0).length;
    final agotados =
        rows.where((row) => row['estado'] == 'AGOTADO_CON_ROTACION').length;
    final ventasRiesgo = _sum(rows, 'valor_vendido');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ExecutiveAlertChip(
          label: 'Stock negativo',
          value: '$negativos',
          color: Colors.redAccent,
          palette: palette,
        ),
        _ExecutiveAlertChip(
          label: 'Agotados con demanda',
          value: '$agotados',
          color: Colors.orangeAccent,
          palette: palette,
        ),
        _ExecutiveAlertChip(
          label: 'Ventas asociadas',
          value: CurrencyUtils.format(ventasRiesgo),
          color: palette.warning,
          palette: palette,
        ),
      ],
    );
  }
}

class _ExecutiveAlertChip extends StatelessWidget {
  const _ExecutiveAlertChip({
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.metrics,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final Map<String, dynamic> metrics;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth < 310
            ? 1
            : maxWidth < 700
                ? 2
                : maxWidth < 1040
                    ? 3
                    : 4;
        const spacing = 10.0;
        final cardWidth = (maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.entries.map((entry) {
            final appearance = _metricAppearance(entry.key, palette);
            return SizedBox(
              width: cardWidth,
              height: 112,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: palette.panelDecoration(
                  baseRadius: 20,
                  tint: appearance.color,
                  elevated: false,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: appearance.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            appearance.icon,
                            color: appearance.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _humanize(entry.key),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _displayValue(
                          entry.value,
                          currency: currencyKeys.contains(entry.key),
                          percentage: percentageKeys.contains(entry.key),
                        ),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.child,
    this.icon = Icons.analytics_outlined,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final AppPalette palette;
  final Widget child;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: palette.panelDecoration(
            baseRadius: 24,
            tint: palette.secondary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: palette.secondary, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 15 : 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              SizedBox(height: compact ? 14 : 18),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _ReportTimeSeriesChart extends StatelessWidget {
  const _ReportTimeSeriesChart({
    required this.rows,
    required this.dateKey,
    required this.valueKey,
    required this.palette,
    this.currency = false,
  });

  final List<Map<String, dynamic>> rows;
  final String dateKey;
  final String valueKey;
  final AppPalette palette;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        'No hay datos suficientes para construir la tendencia.',
        style: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final ordered = [...rows]
      ..sort((a, b) {
        final ad = DateTime.tryParse(a[dateKey]?.toString() ?? '');
        final bd = DateTime.tryParse(b[dateKey]?.toString() ?? '');
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

    final values =
        ordered.map((row) => _toDouble(row[valueKey])).toList(growable: false);
    final maxValue = values.fold<double>(
      0,
      (current, value) => math.max(current, value).toDouble(),
    );
    final average =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

    return SizedBox(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _TrendBadge(
                label: 'Pico',
                value: _displayValue(maxValue, currency: currency),
                color: palette.secondary,
                palette: palette,
              ),
              _TrendBadge(
                label: 'Promedio',
                value: _displayValue(average, currency: currency),
                color: palette.accent,
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _ReportLinePainter(
                values: values,
                lineColor: palette.secondary,
                gridColor: palette.cardBorder.withOpacity(.55),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < ordered.length; i++)
                if (i == 0 ||
                    i == ordered.length - 1 ||
                    i % math.max(1, ordered.length ~/ 5) == 0)
                  Expanded(
                    child: Text(
                      _compactDateLabel(ordered[i][dateKey]),
                      textAlign: i == 0
                          ? TextAlign.left
                          : i == ordered.length - 1
                              ? TextAlign.right
                              : TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.palette,
  });

  final String label;
  final String value;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.16)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      );
}

class _ReportLinePainter extends CustomPainter {
  const _ReportLinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final maxValue = math.max(
      1.0,
      values.fold<double>(
        0,
        (current, value) => math.max(current, value).toDouble(),
      ),
    ).toDouble();

    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y =
          size.height - (values[i] / maxValue) * (size.height - 14) - 7;
      final point = Offset(x, y);
      points.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fill = Path.from(path);
    if (points.isNotEmpty) {
      fill
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = lineColor.withOpacity(.09),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 3.1, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportLinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

String _compactDateLabel(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return _displayValue(value);
  return DateFormat('d MMM', 'es_CO').format(date);
}

class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({
    required this.rows,
    required this.labelKey,
    required this.valueKey,
    required this.palette,
    this.currency = false,
    this.percentage = false,
    this.signed = false,
  });

  final List<Map<String, dynamic>> rows;
  final String? labelKey;
  final String? valueKey;
  final AppPalette palette;
  final bool currency;
  final bool percentage;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    if (labelKey == null || valueKey == null || rows.isEmpty) {
      return Text(
        'Este reporte no tiene valores suficientes para construir un gráfico.',
        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
      );
    }
    final grouped = <String, double>{};
    for (final row in rows) {
      final label = _displayValue(row[labelKey]);
      grouped[label] = (grouped[label] ?? 0) + _toDouble(row[valueKey]);
    }
    final values = grouped.entries.toList(growable: false)
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final visible = values.take(12).toList(growable: false);
    final maxValue = visible.fold<double>(
      0,
      (currentMax, item) => currentMax > item.value.abs() ? currentMax : item.value.abs(),
    );

    return Column(
      children: visible.map((item) {
        final factor = maxValue <= 0 ? 0.0 : (item.value.abs() / maxValue).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _displayValue(item.value, currency: currency, percentage: percentage),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette.background.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: constraints.maxWidth * factor,
                      height: 10,
                      decoration: BoxDecoration(
                        color: signed
                            ? (item.value < 0 ? Colors.redAccent : Colors.green)
                            : palette.secondary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

enum _ReportDataView { cards, table }

class _ReportTable extends StatefulWidget {
  const _ReportTable({
    super.key,
    required this.rows,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  State<_ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<_ReportTable> {
  final TextEditingController _searchController = TextEditingController();
  _ReportDataView? _selectedView;
  int _visibleCount = 24;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.rows;
    return widget.rows.where((row) {
      return row.entries.any((entry) {
        final label = _humanize(entry.key).toLowerCase();
        final value = _displayValue(entry.value).toLowerCase();
        return label.contains(query) || value.contains(query);
      });
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Text(
        'Sin registros para mostrar.',
        style: TextStyle(color: widget.palette.textSecondary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final selectedView =
            _selectedView ?? (compact ? _ReportDataView.cards : _ReportDataView.table);
        final filteredRows = _filteredRows;
        final visibleRows = filteredRows.take(_visibleCount).toList(growable: false);
        final columns = _resolveColumns(filteredRows.isEmpty ? widget.rows : filteredRows);

        final search = TextField(
          maxLength: 120,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          controller: _searchController,
          onChanged: (_) => setState(() {
            _visibleCount = 24;
          }),
          decoration: InputDecoration(
            hintText: 'Buscar en el reporte',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _visibleCount = 24;
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            isDense: true,
          ).compactFilter(),
        );

        final toolbar = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DataViewSelector(
                          selected: selectedView,
                          palette: widget.palette,
                          onChanged: (value) => setState(() => _selectedView = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RecordsBadge(
                        visible: visibleRows.length,
                        total: filteredRows.length,
                        palette: widget.palette,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  _DataViewSelector(
                    selected: selectedView,
                    palette: widget.palette,
                    onChanged: (value) => setState(() => _selectedView = value),
                  ),
                  const SizedBox(width: 10),
                  _RecordsBadge(
                    visible: visibleRows.length,
                    total: filteredRows.length,
                    palette: widget.palette,
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toolbar,
            const SizedBox(height: 12),
            if (filteredRows.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: widget.palette.background.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.palette.cardBorder),
                ),
                child: Text(
                  'No hay registros que coincidan con la búsqueda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selectedView == _ReportDataView.table
                    ? _CompleteReportTable(
                        key: const ValueKey('complete-table'),
                        rows: visibleRows,
                        columns: columns,
                        palette: widget.palette,
                        currencyKeys: widget.currencyKeys,
                        percentageKeys: widget.percentageKeys,
                      )
                    : _ReportCardsGrid(
                        key: const ValueKey('report-cards'),
                        rows: visibleRows,
                        columns: columns,
                        palette: widget.palette,
                        currencyKeys: widget.currencyKeys,
                        percentageKeys: widget.percentageKeys,
                      ),
              ),
            if (filteredRows.length > visibleRows.length) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _visibleCount = math.min(_visibleCount + 24, filteredRows.length).toInt();
                }),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  'Mostrar más (${filteredRows.length - visibleRows.length} pendientes)',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DataViewSelector extends StatelessWidget {
  const _DataViewSelector({
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final _ReportDataView selected;
  final AppPalette palette;
  final ValueChanged<_ReportDataView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.48),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewOption(
            icon: Icons.view_agenda_rounded,
            label: 'Tarjetas',
            selected: selected == _ReportDataView.cards,
            palette: palette,
            onTap: () => onChanged(_ReportDataView.cards),
          ),
          _ViewOption(
            icon: Icons.table_chart_rounded,
            label: 'Tabla',
            selected: selected == _ReportDataView.table,
            palette: palette,
            onTap: () => onChanged(_ReportDataView.table),
          ),
        ],
      ),
    );
  }
}

class _ViewOption extends StatelessWidget {
  const _ViewOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.actionColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? palette.onAction : palette.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.onAction : palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsBadge extends StatelessWidget {
  const _RecordsBadge({
    required this.visible,
    required this.total,
    required this.palette,
  });

  final int visible;
  final int total;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Text(
        '$visible de $total',
        style: TextStyle(
          color: palette.secondary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CompleteReportTable extends StatefulWidget {
  const _CompleteReportTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  State<_CompleteReportTable> createState() => _CompleteReportTableState();
}

class _CompleteReportTableState extends State<_CompleteReportTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final calculatedWidth = widget.columns.fold<double>(
              28,
              (total, column) => total + _reportColumnWidth(column) + 20,
            );
        final tableWidth = math.max(constraints.maxWidth, calculatedWidth).toDouble();
        final needsHorizontalScroll = tableWidth > constraints.maxWidth + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsHorizontalScroll) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.palette.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 17,
                      color: widget.palette.secondary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Desliza horizontalmente para consultar todas las columnas.',
                        style: TextStyle(
                          color: widget.palette.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 18,
                      color: widget.palette.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: tableWidth,
                  child: DataTable(
                    dataRowMinHeight: 54,
                    dataRowMaxHeight: 96,
                    headingRowHeight: 50,
                    columnSpacing: 20,
                    horizontalMargin: 14,
                    dividerThickness: 0.55,
                    headingRowColor: WidgetStatePropertyAll(
                      widget.palette.secondary.withOpacity(0.11),
                    ),
                    headingTextStyle: TextStyle(
                      color: widget.palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                    dataTextStyle: TextStyle(
                      color: widget.palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                    columns: widget.columns
                        .map(
                          (column) => DataColumn(
                            numeric: _isNumericColumn(column),
                            label: SizedBox(
                              width: _reportColumnWidth(column),
                              child: Text(
                                _humanize(column),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: _isNumericColumn(column)
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    rows: [
                      for (var rowIndex = 0; rowIndex < widget.rows.length; rowIndex++)
                        DataRow(
                          color: WidgetStatePropertyAll(
                            rowIndex.isOdd
                                ? widget.palette.background.withOpacity(0.22)
                                : Colors.transparent,
                          ),
                          cells: widget.columns
                              .map(
                                (column) => DataCell(
                                  SizedBox(
                                    width: _reportColumnWidth(column),
                                    child: _ReportCellValue(
                                      column: column,
                                      value: widget.rows[rowIndex][column],
                                      palette: widget.palette,
                                      currency: widget.currencyKeys.contains(column),
                                      percentage: widget.percentageKeys.contains(column),
                                      textAlign: _isNumericColumn(column)
                                          ? TextAlign.right
                                          : TextAlign.left,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportCardsGrid extends StatelessWidget {
  const _ReportCardsGrid({
    super.key,
    required this.rows,
    required this.columns,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 680
            ? 1
            : constraints.maxWidth < 1080
                ? 2
                : 3;
        const spacing = 10.0;
        final width = (constraints.maxWidth - (count - 1) * spacing) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < rows.length; index++)
              SizedBox(
                width: width,
                child: _OperationalReportCard(
                  index: index,
                  row: rows[index],
                  columns: columns,
                  palette: palette,
                  currencyKeys: currencyKeys,
                  percentageKeys: percentageKeys,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OperationalReportCard extends StatelessWidget {
  const _OperationalReportCard({
    required this.index,
    required this.row,
    required this.columns,
    required this.palette,
    required this.currencyKeys,
    required this.percentageKeys,
  });

  final int index;
  final Map<String, dynamic> row;
  final List<String> columns;
  final AppPalette palette;
  final List<String> currencyKeys;
  final List<String> percentageKeys;

  String get _primaryColumn {
    const preferred = [
      'producto',
      'medio_pago',
      'responsable',
      'fecha',
      'fecha_conteo',
      'tipo_movimiento',
      'sucursal',
    ];
    for (final column in preferred) {
      if (columns.contains(column) && row[column] != null) return column;
    }
    if (columns.isNotEmpty) return columns.first;
    return row.keys.first;
  }

  String? get _statusColumn {
    for (final column in columns) {
      if (column.contains('estado') && row[column] != null) return column;
    }
    return null;
  }

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.84,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: palette.secondary),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayValue(row[_primaryColumn]),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Detalle completo del registro',
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
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: columns.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, itemIndex) {
                        final column = columns[itemIndex];
                        return _FullFieldRow(
                          label: _humanize(column),
                          value: row[column],
                          column: column,
                          palette: palette,
                          currency: currencyKeys.contains(column),
                          percentage: percentageKeys.contains(column),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primaryColumn;
    final status = _statusColumn;
    final tone = status == null
        ? palette.secondary
        : _statusColor((row[status] ?? '').toString(), palette);
    final visibleColumns = _cardColumns(columns, primary, status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: tone,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _displayValue(row[primary]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1.18,
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                _StatusBadge(status: _displayValue(row[status]), palette: palette),
              ],
            ],
          ),
          const SizedBox(height: 13),
          for (var itemIndex = 0; itemIndex < visibleColumns.length; itemIndex++) ...[
            _CompactFieldRow(
              label: _humanize(visibleColumns[itemIndex]),
              column: visibleColumns[itemIndex],
              value: row[visibleColumns[itemIndex]],
              palette: palette,
              currency: currencyKeys.contains(visibleColumns[itemIndex]),
              percentage: percentageKeys.contains(visibleColumns[itemIndex]),
            ),
            if (itemIndex < visibleColumns.length - 1) const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showDetails(context),
            icon: const Icon(Icons.open_in_full_rounded, size: 17),
            label: const Text('Ver detalle completo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tone,
              side: BorderSide(color: tone.withOpacity(0.28)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactFieldRow extends StatelessWidget {
  const _CompactFieldRow({
    required this.label,
    required this.column,
    required this.value,
    required this.palette,
    required this.currency,
    required this.percentage,
  });

  final String label;
  final String column;
  final dynamic value;
  final AppPalette palette;
  final bool currency;
  final bool percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: _ReportCellValue(
            column: column,
            value: value,
            palette: palette,
            currency: currency,
            percentage: percentage,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _FullFieldRow extends StatelessWidget {
  const _FullFieldRow({
    required this.label,
    required this.value,
    required this.column,
    required this.palette,
    required this.currency,
    required this.percentage,
  });

  final String label;
  final dynamic value;
  final String column;
  final AppPalette palette;
  final bool currency;
  final bool percentage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 460;
        final valueWidget = _ReportCellValue(
          column: column,
          value: value,
          palette: palette,
          currency: currency,
          percentage: percentage,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              valueWidget,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: valueWidget),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.palette});

  final String status;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ReportCellValue extends StatelessWidget {
  const _ReportCellValue({
    required this.column,
    required this.value,
    required this.palette,
    required this.currency,
    required this.percentage,
    this.textAlign = TextAlign.left,
  });

  final String column;
  final dynamic value;
  final AppPalette palette;
  final bool currency;
  final bool percentage;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = column == 'stock_maximo' && value == null
        ? 'Sin límite'
        : _displayValue(value, currency: currency, percentage: percentage);
    if (column.contains('estado')) {
      return Align(
        alignment: textAlign == TextAlign.right
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: _StatusBadge(status: text, palette: palette),
      );
    }
    return SelectableText(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: _isNumericColumn(column) ? FontWeight.w800 : FontWeight.w600,
        fontSize: 11.5,
        height: 1.25,
      ),
    );
  }
}

class _MetricAppearance {
  const _MetricAppearance(this.icon, this.color);

  final IconData icon;
  final Color color;
}

_MetricAppearance _metricAppearance(String key, AppPalette palette) {
  final normalized = key.toLowerCase();
  if (normalized.contains('mano_obra')) {
    return const _MetricAppearance(
      Icons.groups_2_rounded,
      Colors.deepPurpleAccent,
    );
  }
  if (normalized.contains('gasto')) {
    return _MetricAppearance(
      Icons.receipt_long_rounded,
      palette.warning,
    );
  }
  if (normalized.contains('ingreso')) {
    return _MetricAppearance(
      Icons.point_of_sale_rounded,
      palette.secondary,
    );
  }
  if (normalized.contains('balance')) {
    return _MetricAppearance(
      Icons.balance_rounded,
      palette.accent,
    );
  }
  if (normalized.contains('concentracion')) {
    return _MetricAppearance(
      Icons.pie_chart_outline_rounded,
      palette.secondary,
    );
  }
  if (normalized.contains('rotacion')) {
    return _MetricAppearance(
      Icons.sync_alt_rounded,
      palette.accent,
    );
  }
  if (normalized.contains('falt') ||
      normalized.contains('negativ') ||
      normalized.contains('agotad') ||
      normalized.contains('alert')) {
    return const _MetricAppearance(Icons.warning_amber_rounded, Colors.redAccent);
  }
  if (normalized.contains('sobrant') ||
      normalized.contains('cuadr') ||
      normalized.contains('entrada')) {
    return _MetricAppearance(Icons.check_circle_rounded, palette.success);
  }
  if (normalized.contains('ganancia') || normalized.contains('margen')) {
    return _MetricAppearance(Icons.savings_rounded, palette.success);
  }
  if (normalized.contains('costo')) {
    return const _MetricAppearance(
      Icons.shopping_cart_checkout_rounded,
      Colors.orange,
    );
  }
  if (normalized.contains('total') ||
      normalized.contains('valor') ||
      normalized.contains('ticket') ||
      normalized.contains('pago')) {
    return _MetricAppearance(Icons.payments_rounded, palette.actionColor);
  }
  if (normalized.contains('producto') || normalized.contains('stock')) {
    return _MetricAppearance(Icons.inventory_2_rounded, palette.secondary);
  }
  if (normalized.contains('venta') || normalized.contains('unidades')) {
    return _MetricAppearance(Icons.trending_up_rounded, palette.accent);
  }
  if (normalized.contains('responsable') || normalized.contains('usuario')) {
    return _MetricAppearance(Icons.person_rounded, palette.primary);
  }
  return _MetricAppearance(Icons.analytics_rounded, palette.secondary);
}

Color _statusColor(String value, AppPalette palette) {
  final normalized = value.toUpperCase();
  if (normalized.contains('SIN_CONFIG') ||
      normalized.contains('FALT') ||
      normalized.contains('NEGAT') ||
      normalized.contains('AGOT') ||
      normalized.contains('ERROR')) {
    return Colors.redAccent;
  }
  if (normalized.contains('SUFICIENTE') ||
      normalized.contains('SOBR') ||
      normalized.contains('DISPON') ||
      normalized.contains('CUADRA') ||
      normalized.contains('COMPLET')) {
    return palette.success;
  }
  if (normalized.contains('PEDIR') ||
      normalized.contains('BAJO') ||
      normalized.contains('PENDIENT') ||
      normalized.contains('ALERTA')) {
    return palette.warning;
  }
  return palette.secondary;
}

List<String> _cardColumns(
  List<String> columns,
  String primary,
  String? status,
) {
  const preferred = [
    'stock_actual',
    'stock_minimo',
    'stock_maximo',
    'unidades_pedir',
    'costo_pedido_estimado',
    'ganancia_bruta_periodo',
    'margen_bruto_porcentaje',
    'stock_esperado',
    'conteo_fisico',
    'diferencia_unidades',
    'diferencia_valor_compra',
    'total',
    'cantidad',
    'unidades',
    'ventas',
    'fecha',
    'fecha_conteo',
    'responsable',
    'sucursal',
  ];
  final available = columns
      .where((column) => column != primary && column != status)
      .toList(growable: false);
  return <String>[
    ...preferred.where(available.contains),
    ...available.where((column) => !preferred.contains(column)),
  ].take(5).toList(growable: false);
}

bool _isNumericColumn(String column) {
  final value = column.toLowerCase();
  const keys = [
    'cantidad',
    'unidades',
    'stock',
    'total',
    'valor',
    'precio',
    'porcentaje',
    'ventas',
    'pagos',
    'movimientos',
    'productos',
    'diferencia',
    'propina',
    'ticket',
  ];
  return keys.any(value.contains);
}

double _reportColumnWidth(String column) {
  final value = column.toLowerCase();
  if (value == 'producto') return 220;
  if (value.contains('descripcion') || value.contains('motivo')) return 230;
  if (value.contains('responsable') || value.contains('sucursal')) return 170;
  if (value.contains('fecha')) return 150;
  if (value.contains('estado')) return 132;
  if (value.contains('diferencia')) return 156;
  if (value.contains('valor') || value.contains('precio') || value.contains('costo')) return 148;
  if (_isNumericColumn(value)) return 128;
  return 150;
}

String _monthYearLabel(DateTime date) {
  const months = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

enum _ReportKind { standard, profit, nextOrder }

class _ReportDefinition {
  const _ReportDefinition({
    required this.keyName,
    required this.title,
    required this.description,
    required this.path,
    required this.icon,
    this.requiresDates = false,
    this.showDateFilter = true,
    this.summary = false,
    this.kind = _ReportKind.standard,
    this.chartLabelKey,
    this.chartValueKey,
    this.currencyKeys = const [],
    this.percentageKeys = const [],
    this.signedChart = false,
  });

  final String keyName;
  final String title;
  final String description;
  final String path;
  final IconData icon;
  final bool requiresDates;
  final bool showDateFilter;
  final bool summary;
  final _ReportKind kind;
  final String? chartLabelKey;
  final String? chartValueKey;
  final List<String> currencyKeys;
  final List<String> percentageKeys;
  final bool signedChart;
}

class _ReportPayload {
  const _ReportPayload({
    this.summary = const {},
    this.rows = const [],
    this.chartRows = const [],
    this.paymentRows = const [],
    this.alertRows = const [],
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> chartRows;
  final List<Map<String, dynamic>> paymentRows;
  final List<Map<String, dynamic>> alertRows;

  bool get isEmpty => summary.isEmpty && rows.isEmpty && chartRows.isEmpty;

  List<Map<String, dynamic>> get pdfRows => chartRows.isNotEmpty ? chartRows : rows;

  factory _ReportPayload.fromRaw(Object? raw, {required bool summary}) {
    if (summary && raw is Map) {
      final values = Map<String, dynamic>.from(raw);
      return _ReportPayload(
        summary: values,
        rows: _asRows(values['productos_mas_vendidos']),
        chartRows: _asRows(values['ventas_por_fecha']),
        paymentRows: _asRows(values['medios_pago']),
        alertRows: _asRows(values['alertas_inventario']),
      );
    }
    return _ReportPayload(rows: _asRows(raw));
  }
}

Map<String, dynamic> _buildMetrics(
  _ReportDefinition definition,
  _ReportPayload payload,
) {
  if (definition.summary) {
    const keys = [
      'numero_ventas',
      'total_vendido',
      'total_propinas',
      'ticket_promedio',
      'unidades_vendidas',
      'productos_con_stock',
      'unidades_en_stock',
      'productos_agotados',
      'productos_stock_negativo',
      'productos_stock_bajo',
      'ingresos_periodo',
      'costo_ventas_periodo',
      'ganancia_bruta_periodo',
      'gastos_fijos_periodo',
      'gastos_turno_periodo',
      'salidas_caja_periodo',
      'pagos_pedidos_periodo',
      'pagos_gastos_configurados_periodo',
      'gastos_variables_periodo',
      'mano_obra_periodo',
      'gastos_operativos_periodo',
      'ganancia_neta_estimada_periodo',
      'margen_bruto_porcentaje',
      'margen_neto_porcentaje',
    ];
    return {
      for (final key in keys)
        if (payload.summary.containsKey(key)) key: payload.summary[key],
    };
  }

  final rows = payload.rows;
  if (definition.path.endsWith('/ventas')) {
    final ventas = _sum(rows, 'ventas');
    final total = _sum(rows, 'total');
    return {
      'días_con_ventas': rows.length,
      'ventas': ventas,
      'total': total,
      'propinas': _sum(rows, 'propinas'),
      'ticket_promedio': ventas == 0 ? 0 : total / ventas,
    };
  }
  if (definition.path.contains('medio-pago')) {
    return {
      'medios_utilizados': rows.length,
      'pagos': _sum(rows, 'pagos'),
      'total': _sum(rows, 'total'),
    };
  }
  if (definition.path.contains('cruce-conteo')) {
    final faltantes = rows.where((row) => row['estado_conteo'] == 'FALTANTE').toList();
    final sobrantes = rows.where((row) => row['estado_conteo'] == 'SOBRANTE').toList();
    return {
      'productos_contados': rows.length,
      'productos_con_diferencia': faltantes.length + sobrantes.length,
      'faltantes': faltantes.length,
      'sobrantes': sobrantes.length,
      'cuadran': rows.where((row) => row['estado_conteo'] == 'CUADRA').length,
      'unidades_faltantes': faltantes.fold<double>(0, (sum, row) => sum + _toDouble(row['diferencia_unidades']).abs()),
      'unidades_sobrantes': _sum(sobrantes, 'diferencia_unidades'),
      'valor_faltantes': faltantes.fold<double>(0, (sum, row) => sum + _toDouble(row['diferencia_valor_compra']).abs()),
      'valor_sobrantes': _sum(sobrantes, 'diferencia_valor_compra'),
    };
  }
  if (definition.kind == _ReportKind.profit) {
    final ingresos = _sum(rows, 'ingresos_periodo');
    final ganancia = _sum(rows, 'ganancia_bruta_periodo');
    final metadata = payload.summary.isNotEmpty
        ? payload.summary
        : (rows.isEmpty ? const <String, dynamic>{} : rows.first);
    final gastosFijos = _toDouble(metadata['gastos_fijos_periodo']);
    final gastosVariables = _toDouble(metadata['gastos_variables_periodo']);
    final manoObra = _toDouble(metadata['mano_obra_periodo']);
    final gastosOperativos = _toDouble(metadata['gastos_operativos_periodo']);
    final gananciaNeta = metadata.containsKey('ganancia_neta_estimada_periodo')
        ? _toDouble(metadata['ganancia_neta_estimada_periodo'])
        : ganancia - gastosOperativos;
    return {
      'ingresos_periodo': ingresos,
      'costo_ventas_periodo': _sum(rows, 'costo_ventas_periodo'),
      'ganancia_bruta_periodo': ganancia,
      'gastos_fijos_periodo': gastosFijos,
      'gastos_variables_periodo': gastosVariables,
      'mano_obra_periodo': manoObra,
      'gastos_operativos_periodo': gastosOperativos,
      'ganancia_neta_estimada_periodo': gananciaNeta,
      'margen_bruto_porcentaje':
          ingresos == 0 ? 0 : (ganancia * 100 / ingresos),
      'productos_con_ventas': rows
          .where((row) => _toDouble(row['unidades_vendidas_periodo']) > 0)
          .length,
    };
  }
  if (definition.kind == _ReportKind.nextOrder) {
    final pedidos = rows
        .where((row) => _toDouble(row['unidades_pedir']) > 0)
        .toList(growable: false);
    return {
      'productos_pedir': pedidos.length,
      'unidades_pedir': _sum(pedidos, 'unidades_pedir'),
      'presentaciones_pedir': _sum(pedidos, 'presentaciones_pedir'),
      'costo_pedido_estimado': _sum(pedidos, 'costo_pedido_estimado'),
      'productos_sin_configurar': rows
          .where((row) => row['estado_reposicion'] == 'SIN_CONFIGURAR')
          .length,
      'productos_sobrestock': rows
          .where((row) => row['estado_reposicion'] == 'SOBRESTOCK')
          .length,
    };
  }
  if (definition.path.contains('stock-actual')) {
    final disponibles =
        rows.where((row) => row['estado'] == 'DISPONIBLE').length;
    final sinConfigurar =
        rows.where((row) => row['estado'] == 'SIN_CONFIGURAR').length;
    final sobrestock =
        rows.where((row) => row['estado'] == 'SOBRESTOCK').length;
    return {
      'productos': rows.length,
      'unidades': _sum(rows, 'unidades'),
      'disponibles': disponibles,
      'agotados': rows.where((row) => row['estado'] == 'AGOTADO').length,
      'stock_bajo': rows.where((row) => row['estado'] == 'STOCK_BAJO').length,
      'stock_negativo':
          rows.where((row) => row['estado'] == 'STOCK_NEGATIVO').length,
      'sin_configurar': sinConfigurar,
      'sobrestock': sobrestock,
      'salud_inventario_porcentaje':
          rows.isEmpty ? 0 : disponibles * 100 / rows.length,
    };
  }
  if (definition.path.contains('productos-mas-vendidos')) {
    final totalUnits = _sum(rows, 'cantidad');
    final ranked = [...rows]
      ..sort((a, b) =>
          _toDouble(b['cantidad']).compareTo(_toDouble(a['cantidad'])));
    final top3Units = ranked
        .take(3)
        .fold<double>(0, (sum, row) => sum + _toDouble(row['cantidad']));
    return {
      'productos': rows.length,
      'unidades_vendidas': totalUnits,
      'total': _sum(rows, 'total'),
      'concentracion_top_3_porcentaje':
          totalUnits == 0 ? 0 : top3Units * 100 / totalUnits,
    };
  }
  if (definition.path.contains('movimientos-inventario')) {
    final entradaRows =
        rows.where((row) => row['operacion'] == 'ENTRADA').toList();
    final salidaRows =
        rows.where((row) => row['operacion'] == 'SALIDA').toList();
    final ajusteRows =
        rows.where((row) => row['operacion'] == 'AJUSTE').toList();
    final unidadesEntrada = _sum(entradaRows, 'cantidad_unidades');
    final unidadesSalida = _sum(salidaRows, 'cantidad_unidades');
    return {
      'movimientos': rows.length,
      'unidades_movidas': _sum(rows, 'cantidad_unidades'),
      'entradas': entradaRows.length,
      'salidas': salidaRows.length,
      'ajustes': ajusteRows.length,
      'unidades_entrada': unidadesEntrada,
      'unidades_salida': unidadesSalida,
      'balance_unidades': unidadesEntrada - unidadesSalida,
    };
  }
  if (definition.path.contains('/persona')) {
    final totalSalidas = _sum(rows, 'unidades_salida');
    final top = rows.isEmpty
        ? const <String, dynamic>{}
        : ([...rows]
              ..sort((a, b) => _toDouble(b['unidades_salida'])
                  .compareTo(_toDouble(a['unidades_salida']))))
            .first;
    return {
      'responsables': rows.length,
      'movimientos': _sum(rows, 'movimientos'),
      'unidades_salida': totalSalidas,
      'productos': _sum(rows, 'productos'),
      'concentracion_principal_porcentaje': totalSalidas == 0
          ? 0
          : _toDouble(top['unidades_salida']) * 100 / totalSalidas,
    };
  }
  if (definition.path.contains('productos-desfalcados')) {
    return {
      'alertas': rows.length,
      'stock_negativo':
          rows.where((row) => _toDouble(row['stock_actual']) < 0).length,
      'agotados_con_rotación':
          rows.where((row) => row['estado'] == 'AGOTADO_CON_ROTACION').length,
      'ventas_periodo': _sum(rows, 'ventas_periodo'),
      'valor_vendido_en_riesgo': _sum(rows, 'valor_vendido'),
    };
  }
  if (definition.path.contains('cruce-ventas')) {
    final withRotation = rows
        .where((row) => _toDouble(row['rotacion_porcentaje']) > 0)
        .toList();
    final rotationAverage = withRotation.isEmpty
        ? 0
        : _sum(withRotation, 'rotacion_porcentaje') / withRotation.length;
    return {
      'productos': rows.length,
      'stock_actual': _sum(rows, 'stock_actual'),
      'ventas_periodo': _sum(rows, 'ventas_periodo'),
      'entradas_periodo': _sum(rows, 'entradas_periodo'),
      'salidas_periodo': _sum(rows, 'salidas_periodo'),
      'sin_rotacion':
          rows.where((row) => row['estado'] == 'SIN_ROTACION').length,
      'rotacion_promedio_porcentaje': rotationAverage,
    };
  }
  return {'registros': rows.length};
}

List<Map<String, dynamic>> _asRows(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

const _profitReportColumns = <String>[
  'producto',
  'sucursal',
  'unidades_vendidas_periodo',
  'ingresos_periodo',
  'costo_ventas_periodo',
  'ganancia_bruta_periodo',
  'margen_bruto_porcentaje',
  'precio_venta_actual',
  'costo_unitario_actual',
  'ganancia_unitaria_actual',
];

const _nextOrderReportColumns = <String>[
  'producto',
  'sucursal',
  'estado_reposicion',
  'stock_actual',
  'stock_minimo',
  'stock_maximo',
  'faltante_hasta_maximo',
  'presentacion_compra',
  'unidades_por_presentacion',
  'presentaciones_pedir',
  'unidades_pedir',
  'stock_proyectado',
  'costo_presentacion_actual',
  'costo_pedido_estimado',
  'fecha_actualizacion',
];

List<Map<String, dynamic>> _rowsForDefinition(
  _ReportDefinition definition,
  List<Map<String, dynamic>> rows,
) {
  final columns = switch (definition.kind) {
    _ReportKind.profit => _profitReportColumns,
    _ReportKind.nextOrder => _nextOrderReportColumns,
    _ReportKind.standard => const <String>[],
  };
  if (columns.isEmpty) return rows;
  return rows
      .map(
        (row) => <String, dynamic>{
          for (final column in columns)
            if (row.containsKey(column))
              column: column == 'stock_maximo' && row[column] == null
                  ? 'Sin límite'
                  : row[column],
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> _pdfRowsForDefinition(
  _ReportDefinition definition,
  List<Map<String, dynamic>> rows,
) {
  var selected = rows;
  if (definition.kind == _ReportKind.profit) {
    selected = rows
        .where((row) => _toDouble(row['unidades_vendidas_periodo']) > 0)
        .toList(growable: false);
  } else if (definition.kind == _ReportKind.nextOrder) {
    selected = rows.where((row) {
      final status = (row['estado_reposicion'] ?? '').toString();
      return _toDouble(row['unidades_pedir']) > 0 ||
          status == 'SIN_CONFIGURAR';
    }).toList(growable: false);
  }
  return _rowsForDefinition(definition, selected);
}

List<String> _resolveColumns(List<Map<String, dynamic>> rows) {
  const hidden = <String>{
    'estado_prioridad',
    'diferencia_absoluta',
  };
  const preferred = <String>[
    'producto',
    'sucursal',
    'estado_reposicion',
    'stock_actual',
    'stock_minimo',
    'stock_maximo',
    'presentacion_compra',
    'unidades_por_presentacion',
    'presentaciones_pedir',
    'unidades_pedir',
    'stock_proyectado',
    'costo_pedido_estimado',
    'unidades_vendidas_periodo',
    'ingresos_periodo',
    'costo_ventas_periodo',
    'ganancia_bruta_periodo',
    'margen_bruto_porcentaje',
    'ganancia_potencial_stock',
    'fecha_actualizacion',
    'fecha_conteo',
    'stock_esperado',
    'conteo_fisico',
    'diferencia_unidades',
    'unidades_por_presentacion',
    'diferencia_presentaciones',
    'estado_conteo',
    'diferencia_porcentaje',
    'costo_unitario',
    'diferencia_valor_compra',
    'responsable',
  ];
  final available = <String>[];
  for (final row in rows.take(20)) {
    for (final key in row.keys) {
      if (key.endsWith('_id') || key.startsWith('_') || hidden.contains(key)) {
        continue;
      }
      if (!available.contains(key)) available.add(key);
    }
  }
  final result = <String>[
    ...preferred.where(available.contains),
    ...available.where((key) => !preferred.contains(key)),
  ];
  return result;
}

double _orderPresentationCost(Map<String, dynamic> row) {
  final direct = _firstNumber(
    row,
    const <String>[
      'costo_presentacion_actual',
      'costoPresentacion',
      'depeCostoPresentacion',
      'precValorCompra',
    ],
  );
  if (direct > 0) return direct;

  final unitCost = _firstNumber(
    row,
    const <String>[
      'costo_unitario_actual',
      'costoUnitarioActual',
      'costo_unitario',
      'costoUnitario',
    ],
  );
  final factor = math.max(
    1.0,
    _firstNumber(
      row,
      const <String>[
        'unidades_por_presentacion',
        'unidadesPorPresentacion',
        'depeUnidadesPresentacion',
      ],
    ),
  );
  return unitCost > 0 ? unitCost * factor : 0;
}

double _orderSubtotal(
  Map<String, dynamic> row, {
  double? presentations,
}) {
  final count = presentations ??
      _firstNumber(
        row,
        const <String>[
          'presentaciones_pedir',
          'presentaciones',
          'depePresentaciones',
        ],
      );
  final cost = _orderPresentationCost(row);
  if (presentations != null) {
    return count > 0 && cost > 0 ? count * cost : 0;
  }
  if (count > 0 && cost > 0) return count * cost;

  return _firstNumber(
    row,
    const <String>[
      'costo_pedido_estimado',
      'subtotal',
      'depeSubtotal',
      'totalEstimado',
    ],
  );
}

double _firstNumber(
  Map<String, dynamic> row,
  List<String> keys,
) {
  for (final key in keys) {
    if (!row.containsKey(key)) continue;
    final value = _toDouble(row[key]);
    if (value != 0) return value;
  }
  return 0;
}

double _sum(List<Map<String, dynamic>> rows, String key) =>
    rows.fold<double>(0, (sum, row) => sum + _toDouble(row[key]));

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  var text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 0;
  text = text.replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (text.isEmpty || text == '-' || text == ',' || text == '.') return 0;

  final comma = text.lastIndexOf(',');
  final dot = text.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    if (comma > dot) {
      text = text.replaceAll('.', '').replaceFirst(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (comma >= 0) {
    text = text.replaceAll('.', '').replaceFirst(',', '.');
  } else if (text.split('.').length > 2) {
    final last = text.lastIndexOf('.');
    text = '${text.substring(0, last).replaceAll('.', '')}${text.substring(last)}';
  }
  return double.tryParse(text) ?? 0;
}

String _humanize(String value) {
  const labels = <String, String>{
    'gastos_turno_periodo': 'Gastos del turno',
    'salidas_caja_periodo': 'Salidas de caja',
    'pagos_pedidos_periodo': 'Pagos de pedidos',
    'pagos_gastos_configurados_periodo': 'Pagos de facturas/gastos',
    'gastos_variables_periodo': 'Gastos variables',
    'gastos_fijos_periodo': 'Gastos fijos',
    'mano_obra_periodo': 'Mano de obra',
    'gastos_operativos_periodo': 'Gastos operativos',
    'ganancia_neta_estimada_periodo': 'Ganancia neta estimada',
    'ganancia_bruta_periodo': 'Ganancia bruta',
    'costo_ventas_periodo': 'Costo de ventas',
    'ingresos_periodo': 'Ingresos por productos',
  };
  if (labels.containsKey(value)) return labels[value]!;
  final spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return 'Dato';
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _stockMaximumText(dynamic value) =>
    value == null ? 'Sin límite' : _displayValue(value);

String _displayValue(
  dynamic value, {
  bool currency = false,
  bool percentage = false,
}) {
  if (value == null) return '—';
  if (currency && value is num) return CurrencyUtils.format(value);
  if (percentage && value is num) return '${value.toStringAsFixed(1)} %';
  if (value is num) {
    if (value % 1 == 0) return NumberFormat.decimalPattern('es_CO').format(value.toInt());
    return NumberFormat.decimalPatternDigits(locale: 'es_CO', decimalDigits: 2).format(value);
  }
  if (value is bool) return value ? 'Sí' : 'No';
  final text = value.toString().trim();
  if (text.isEmpty) return '—';
  final date = DateTime.tryParse(text);
  if (date != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
    return text.length <= 10
        ? DateFormat('dd/MM/yyyy').format(date)
        : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }
  return text;
}

String _safeFileName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúñ]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
