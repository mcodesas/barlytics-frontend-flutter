import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late DateTime _month;
  int? _branchId;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _profitRows = const [];
  List<Map<String, dynamic>> _liveSales = const [];
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _branchId = ref.read(branchScopeProvider).activeBranchId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _periodStart => DateTime(_month.year, _month.month);

  DateTime get _periodEnd {
    final natural = DateTime(_month.year, _month.month + 1, 0);
    final today = _today;
    if (_month.year == today.year && _month.month == today.month) {
      return today;
    }
    return natural;
  }

  bool get _canGoNext {
    final today = _today;
    return _month.year < today.year ||
        (_month.year == today.year && _month.month < today.month);
  }

  Future<void> _load() async {
    final branchId = _branchId ?? ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Selecciona una sucursal para consultar el Dashboard.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final query = <String, dynamic>{
      'inicio': DateFormat('yyyy-MM-dd').format(_periodStart),
      'fin': DateFormat('yyyy-MM-dd').format(_periodEnd),
      'sucursalId': branchId,
    };

    try {
      final api = ref.read(apiClientProvider);
      final responses = await Future.wait([
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _map,
          queryParameters: query,
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/inventario/ganancias-pedido',
          _list,
          queryParameters: query,
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/ventas/tiempo-real',
          _list,
          queryParameters: {'sucursalId': branchId},
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = responses[0].data as Map<String, dynamic>? ?? const {};
        _profitRows =
            responses[1].data as List<Map<String, dynamic>>? ?? const [];
        _liveSales =
            responses[2].data as List<Map<String, dynamic>>? ?? const [];
        _branchId = branchId;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final today = _today;
    if (next.isAfter(DateTime(today.year, today.month))) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branches = ref.watch(branchScopeProvider).branches;

    ref.listen<BranchScopeState>(branchScopeProvider, (previous, next) {
      final nextId = next.activeBranchId;
      if (nextId != null && nextId != _branchId && mounted) {
        setState(() => _branchId = nextId);
        _load();
      }
    });

    if (_loading && _summary.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: AppLoader(message: 'Construyendo el panorama completo del negocio...'),
      );
    }

    if (_error != null && _summary.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppErrorView(message: _error!, onRetry: _load),
      );
    }

    final sales = _num(_summary['total_vendido']);
    final salesCount = _int(_summary['numero_ventas']);
    final ticket = _num(_summary['ticket_promedio']);
    final units = _num(_summary['unidades_vendidas']);
    final stockUnits = _num(_summary['unidades_en_stock']);
    final stockProducts = _int(_summary['productos_con_stock']);
    final out = _int(_summary['productos_agotados']);
    final negative = _int(_summary['productos_stock_negativo']);
    final low = _int(_summary['productos_stock_bajo']);

    final salesRows = _rows(_summary['ventas_por_fecha']);
    final paymentRows = _rows(_summary['medios_pago']);
    final topRows = _rows(_summary['productos_mas_vendidos']);
    final alertRows = _rows(_summary['alertas_inventario']);

    final gross = _profitRows.fold<double>(
      0,
      (sum, row) => sum + _num(row['ganancia_bruta_periodo']),
    );

    final financialRow =
        _profitRows.isNotEmpty ? _profitRows.first : const <String, dynamic>{};
    final fixed = _num(financialRow['gastos_fijos_periodo']);
    final variable = _num(financialRow['gastos_variables_periodo']);
    final labor = _num(financialRow['mano_obra_periodo']);
    final operating = _num(financialRow['gastos_operativos_periodo']);
    final net = _num(financialRow['ganancia_neta_estimada_periodo']);
    final costOfSales = math.max(0, sales - gross);
    final netMargin = sales == 0 ? 0.0 : (net / sales) * 100;

    final productsToOrder = _profitRows
        .where((row) => _num(row['unidades_pedir']) > 0)
        .length;
    final unitsToOrder = _profitRows.fold<double>(
      0,
      (sum, row) => sum + _num(row['unidades_pedir']),
    );
    final nextOrderCost = _profitRows.fold<double>(
      0,
      (sum, row) => sum + _num(row['costo_pedido_estimado']),
    );

    final openTotal = _liveSales.fold<double>(
      0,
      (sum, row) => sum + _num(row['total']),
    );
    final openBalance = _liveSales.fold<double>(
      0,
      (sum, row) => sum + _num(row['saldo_pendiente']),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            color: palette.secondary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _DashboardHeader(
                    palette: palette,
                    month: _month,
                    canGoNext: _canGoNext,
                    updatedAt: _updatedAt,
                    branches: branches,
                    branchId: _branchId,
                    onPrevious: () => _moveMonth(-1),
                    onNext: () => _moveMonth(1),
                    onRefresh: _load,
                    onBranchChanged: (value) {
                      if (value == null || value == _branchId) return;
                      setState(() => _branchId = value);
                      _load();
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    child: _KpiGrid(
                      palette: palette,
                      items: [
                        _Kpi(
                          'Ventas',
                          CurrencyUtils.format(sales),
                          '$salesCount ventas finalizadas',
                          Icons.point_of_sale_rounded,
                          palette.secondary,
                        ),
                        _Kpi(
                          'Ganancia neta',
                          CurrencyUtils.format(net),
                          'Margen neto ${netMargin.toStringAsFixed(1)} %',
                          Icons.trending_up_rounded,
                          net >= 0 ? palette.actionColor : Colors.redAccent,
                        ),
                        _Kpi(
                          'Ticket promedio',
                          CurrencyUtils.format(ticket),
                          '${_compact(units)} unidades vendidas',
                          Icons.receipt_long_rounded,
                          palette.primary,
                        ),
                        _Kpi(
                          'Operación abierta',
                          CurrencyUtils.format(openTotal),
                          '${_liveSales.length} ventas · ${CurrencyUtils.format(openBalance)} pendientes',
                          Icons.table_bar_rounded,
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    child: _ResponsivePair(
                      leftFlex: 7,
                      rightFlex: 5,
                      left: _Panel(
                        palette: palette,
                        title: 'Ventas del periodo',
                        subtitle:
                            'Comportamiento diario de ${_monthLabel(_month).toLowerCase()}.',
                        icon: Icons.show_chart_rounded,
                        child: _SalesTrendChart(
                          rows: salesRows,
                          palette: palette,
                        ),
                      ),
                      right: _Panel(
                        palette: palette,
                        title: 'Rentabilidad',
                        subtitle:
                            'De cada peso vendido, cuánto termina como utilidad.',
                        icon: Icons.account_balance_rounded,
                        child: _ProfitabilityChart(
                          sales: sales,
                          costOfSales: costOfSales,
                          fixed: fixed,
                          variable: variable,
                          labor: labor,
                          net: net,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    child: _KpiGrid(
                      palette: palette,
                      items: [
                        _Kpi(
                          'Costo de lo vendido',
                          CurrencyUtils.format(costOfSales),
                          'Productos consumidos en ventas',
                          Icons.shopping_cart_checkout_rounded,
                          Colors.orange,
                        ),
                        _Kpi(
                          'Gastos operativos',
                          CurrencyUtils.format(operating),
                          'Fijos + variables + mano de obra',
                          Icons.payments_outlined,
                          Colors.amber,
                        ),
                        _Kpi(
                          'Mano de obra',
                          CurrencyUtils.format(labor),
                          'Según cargos, días y vigencias',
                          Icons.groups_rounded,
                          Colors.deepPurpleAccent,
                        ),
                        _Kpi(
                          'Próximo pedido',
                          CurrencyUtils.format(nextOrderCost),
                          '$productsToOrder productos · ${_compact(unitsToOrder)} unidades',
                          Icons.local_shipping_rounded,
                          Colors.tealAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    child: _ResponsivePair(
                      left: _Panel(
                        palette: palette,
                        title: 'Medios de pago',
                        subtitle: 'Cómo se distribuyó el recaudo del periodo.',
                        icon: Icons.account_balance_wallet_rounded,
                        child: _HorizontalBars(
                          rows: paymentRows,
                          labelKey: 'medio_pago',
                          valueKey: 'total',
                          palette: palette,
                          currency: true,
                          emptyText: 'No hay pagos registrados en el periodo.',
                        ),
                      ),
                      right: _Panel(
                        palette: palette,
                        title: 'Productos más vendidos',
                        subtitle: 'Productos que más mueven la operación.',
                        icon: Icons.emoji_events_rounded,
                        child: _HorizontalBars(
                          rows: topRows.take(7).toList(growable: false),
                          labelKey: 'producto',
                          valueKey: 'cantidad',
                          palette: palette,
                          emptyText: 'No hay ventas de productos en el periodo.',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    child: _ResponsivePair(
                      leftFlex: 5,
                      rightFlex: 7,
                      left: _Panel(
                        palette: palette,
                        title: 'Salud del inventario',
                        subtitle: '$stockProducts productos con inventario registrado.',
                        icon: Icons.inventory_2_rounded,
                        child: _InventoryHealth(
                          units: stockUnits,
                          low: low,
                          out: out,
                          negative: negative,
                          palette: palette,
                        ),
                      ),
                      right: _Panel(
                        palette: palette,
                        title: 'Alertas que requieren atención',
                        subtitle:
                            'Stock, faltantes y señales operativas detectadas.',
                        icon: Icons.warning_amber_rounded,
                        child: _AlertsList(
                          rows: alertRows,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DashboardWidth(
                    bottom: 34,
                    child: _Panel(
                      palette: palette,
                      title: 'Radiografía financiera del periodo',
                      subtitle:
                          'Detalle consolidado de ingresos, costos y gastos.',
                      icon: Icons.analytics_rounded,
                      child: _FinancialBreakdown(
                        sales: sales,
                        costOfSales: costOfSales,
                        gross: gross,
                        fixed: fixed,
                        variable: variable,
                        labor: labor,
                        net: net,
                        palette: palette,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading && _summary.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: palette.secondary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.palette,
    required this.month,
    required this.canGoNext,
    required this.updatedAt,
    required this.branches,
    required this.branchId,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
    required this.onBranchChanged,
  });

  final AppPalette palette;
  final DateTime month;
  final bool canGoNext;
  final DateTime? updatedAt;
  final List<dynamic> branches;
  final int? branchId;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final ValueChanged<int?> onBranchChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard del negocio',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Una sola vista para entender ventas, rentabilidad, gastos, inventario, pagos y operación.',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: onPrevious,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 118),
                child: Text(
                  _monthLabel(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: canGoNext ? onNext : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 220,
          height: 42,
          child: DropdownButtonFormField<int?>(
            value: branches.any((item) => item.sucuId == branchId)
                ? branchId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              ...branches.where((item) => item.sucuId != null).map(
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
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Actualizar Dashboard',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );

    return _DashboardWidth(
      top: 16,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: palette.panelDecoration(
          baseRadius: 26,
          tint: palette.secondary,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 14),
                  filters,
                  if (updatedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Actualizado ${DateFormat('HH:mm').format(updatedAt!)}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 18),
                  filters,
                ],
              ),
      ),
    );
  }
}

class _DashboardWidth extends StatelessWidget {
  const _DashboardWidth({
    required this.child,
    this.top = 12,
    this.bottom = 0,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
            child: child,
          ),
        ),
      );
}

class _Kpi {
  const _Kpi(this.title, this.value, this.subtitle, this.icon, this.color);

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items, required this.palette});

  final List<_Kpi> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620
              ? 1
              : constraints.maxWidth < 1050
                  ? 2
                  : 4;
          const spacing = 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 112),
                    padding: const EdgeInsets.all(15),
                    decoration: palette.panelDecoration(
                      baseRadius: 20,
                      tint: item.color,
                      elevated: false,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(.13),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(item.icon, color: item.color, size: 23),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
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

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                left,
                const SizedBox(height: 12),
                right,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: 12),
              Expanded(flex: rightFlex, child: right),
            ],
          );
        },
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final AppPalette palette;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: palette.panelDecoration(
          baseRadius: 22,
          tint: palette.secondary,
          elevated: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyChart(
        palette: palette,
        message: 'No hay ventas para construir la tendencia.',
      );
    }

    final values = rows.map((row) => _num(row['total'])).toList(growable: false);
    final maxValue = values.fold<double>(0, math.max);
    return SizedBox(
      height: 245,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(
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
              for (var i = 0; i < rows.length; i++)
                if (i == 0 ||
                    i == rows.length - 1 ||
                    i % math.max(1, rows.length ~/ 5) == 0)
                  Expanded(
                    child: Text(
                      _dayLabel(rows[i]['fecha']),
                      textAlign: i == 0
                          ? TextAlign.left
                          : i == rows.length - 1
                              ? TextAlign.right
                              : TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Pico: ${CurrencyUtils.format(maxValue)}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
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
      values.fold<double>(0, math.max),
    );
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue) * (size.height - 12) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()..color = lineColor.withOpacity(.10),
    );
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
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue) * (size.height - 12) - 6;
      canvas.drawCircle(Offset(x, y), 3.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

class _ProfitabilityChart extends StatelessWidget {
  const _ProfitabilityChart({
    required this.sales,
    required this.costOfSales,
    required this.fixed,
    required this.variable,
    required this.labor,
    required this.net,
    required this.palette,
  });

  final double sales;
  final double costOfSales;
  final double fixed;
  final double variable;
  final double labor;
  final double net;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double, Color)>[
      ('Ingresos', sales, palette.secondary),
      ('Costo vendido', costOfSales, Colors.orange),
      ('Gastos fijos', fixed, Colors.blueAccent),
      ('Variables', variable, Colors.amber),
      ('Mano de obra', labor, Colors.deepPurpleAccent),
      ('Ganancia neta', net, net >= 0 ? Colors.greenAccent : Colors.redAccent),
    ];
    final maxValue = math.max(
      1.0,
      rows.fold<double>(0, (max, row) => math.max(max, row.$2.abs())),
    );

    return Column(
      children: [
        for (final row in rows) ...[
          _MetricBar(
            label: row.$1,
            value: row.$2,
            maxValue: maxValue,
            color: row.$3,
            palette: palette,
            currency: true,
          ),
          if (row != rows.last) const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({
    required this.rows,
    required this.labelKey,
    required this.valueKey,
    required this.palette,
    required this.emptyText,
    this.currency = false,
  });

  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final String valueKey;
  final AppPalette palette;
  final String emptyText;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyChart(palette: palette, message: emptyText);
    }
    final maxValue = math.max(
      1.0,
      rows.fold<double>(
        0,
        (max, row) => math.max(max, _num(row[valueKey]).abs()),
      ),
    );
    return Column(
      children: [
        for (final row in rows) ...[
          _MetricBar(
            label: row[labelKey]?.toString() ?? 'Sin dato',
            value: _num(row[valueKey]),
            maxValue: maxValue,
            color: palette.secondary,
            palette: palette,
            currency: currency,
          ),
          if (row != rows.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.palette,
    this.currency = false,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final AppPalette palette;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    final ratio = (value.abs() / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              currency ? CurrencyUtils.format(value) : _compact(value),
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: palette.cardBorder.withOpacity(.38),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _InventoryHealth extends StatelessWidget {
  const _InventoryHealth({
    required this.units,
    required this.low,
    required this.out,
    required this.negative,
    required this.palette,
  });

  final double units;
  final int low;
  final int out;
  final int negative;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final alerts = low + out + negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniValue(
                label: 'Unidades en stock',
                value: _compact(units),
                color: palette.secondary,
                palette: palette,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniValue(
                label: 'Alertas',
                value: '$alerts',
                color: alerts == 0 ? Colors.greenAccent : Colors.orangeAccent,
                palette: palette,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InventoryRow(
          label: 'Stock bajo',
          value: low,
          icon: Icons.low_priority_rounded,
          color: Colors.amber,
          palette: palette,
        ),
        const SizedBox(height: 8),
        _InventoryRow(
          label: 'Agotados',
          value: out,
          icon: Icons.remove_shopping_cart_rounded,
          color: Colors.orangeAccent,
          palette: palette,
        ),
        const SizedBox(height: 8),
        _InventoryRow(
          label: 'Stock negativo',
          value: negative,
          icon: Icons.error_outline_rounded,
          color: Colors.redAccent,
          palette: palette,
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.palette,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(.32),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.cardBorder.withOpacity(.55)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyChart(
        palette: palette,
        icon: Icons.check_circle_rounded,
        message: 'No hay alertas críticas de inventario en el periodo.',
      );
    }

    return Column(
      children: [
        for (final row in rows.take(8)) ...[
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(.32),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: palette.cardBorder.withOpacity(.55)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['producto']?.toString() ?? 'Producto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        'Stock ${_compact(_num(row['stock_actual']))} · '
                        'Ventas ${_compact(_num(row['ventas_periodo']))}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _humanize(row['estado']?.toString() ?? 'ALERTA'),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (row != rows.take(8).last) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _FinancialBreakdown extends StatelessWidget {
  const _FinancialBreakdown({
    required this.sales,
    required this.costOfSales,
    required this.gross,
    required this.fixed,
    required this.variable,
    required this.labor,
    required this.net,
    required this.palette,
  });

  final double sales;
  final double costOfSales;
  final double gross;
  final double fixed;
  final double variable;
  final double labor;
  final double net;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Ingresos', sales, Icons.point_of_sale_rounded),
      ('Costo vendido', costOfSales, Icons.shopping_cart_checkout_rounded),
      ('Ganancia bruta', gross, Icons.account_balance_wallet_rounded),
      ('Gastos fijos', fixed, Icons.lock_outline_rounded),
      ('Gastos variables', variable, Icons.tune_rounded),
      ('Mano de obra', labor, Icons.groups_rounded),
      ('Ganancia neta', net, Icons.trending_up_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 2
            : constraints.maxWidth < 1100
                ? 4
                : 7;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: palette.background.withOpacity(.30),
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: palette.cardBorder.withOpacity(.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, color: palette.secondary, size: 18),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyUtils.format(item.$2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w600,
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

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({
    required this.palette,
    required this.message,
    this.icon = Icons.insert_chart_outlined_rounded,
  });

  final AppPalette palette;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.secondary, size: 34),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

Map<String, dynamic> _map(Object? json) {
  if (json is Map) return Map<String, dynamic>.from(json);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(Object? json) => _rows(json);

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _compact(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) {
    return NumberFormat.decimalPattern('es_CO').format(number.toInt());
  }
  return NumberFormat.decimalPattern('es_CO').format(number);
}

String _monthLabel(DateTime date) {
  const months = [
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

String _dayLabel(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '';
  return DateFormat('d MMM', 'es_CO').format(date);
}

String _humanize(String value) {
  final text = value.toLowerCase().replaceAll('_', ' ');
  if (text.isEmpty) return value;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
