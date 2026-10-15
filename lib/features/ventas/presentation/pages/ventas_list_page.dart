import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

/// Centro de control de ventas orientado a GERENTE.
///
/// Reemplaza la tabla CRUD genérica por indicadores ejecutivos, comparación
/// contra el periodo anterior, comportamiento de recaudo y detalle operativo.
class VentasListPage extends ConsumerStatefulWidget {
  const VentasListPage({super.key});

  @override
  ConsumerState<VentasListPage> createState() => _VentasListPageState();
}

class _VentasListPageState extends ConsumerState<VentasListPage> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  late DateTime _inicio;
  late DateTime _fin;
  bool _loading = true;
  String? _error;
  int? _loadedBranchId;
  int _loadGeneration = 0;
  Map<String, dynamic> _summary = const {};
  Map<String, dynamic> _previousSummary = const {};
  List<_ManagerSale> _sales = const [];
  List<_LiveSale> _liveSales = const [];
  Timer? _realtimeTimer;
  DateTime? _liveUpdatedAt;
  bool _liveLoading = true;
  bool _autoRefresh = true;
  String? _liveError;
  String _status = 'TODOS';
  int _page = 0;
  static const _pageSize = 15;
  static const _realtimeInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _fin = today;
    _inicio = today.subtract(const Duration(days: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _startRealtimeTimer();
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final branchId = branchState.activeBranchId;

    ref.listen<int?>(
      branchScopeProvider.select((state) => state.activeBranchId),
      (previous, next) {
        if (previous == next || next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _summary = const {};
            _previousSummary = const {};
            _sales = const [];
            _liveSales = const [];
            _loadedBranchId = null;
            _liveError = null;
          });
          _load(force: true);
        });
      },
    );

    if (_loading && _summary.isEmpty) {
      return const AppLoader(message: 'Preparando el centro de control de ventas...');
    }
    if (_error != null && _summary.isEmpty) {
      return AppErrorView(message: _error!, onRetry: () => _load(force: true));
    }

    final filtered = _filteredSales();
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil()).toInt();
    if (_page >= pageCount) _page = pageCount - 1;
    final pageItems = filtered.skip(_page * _pageSize).take(_pageSize).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: () => _load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 34),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(palette, branchState.activeBranch?.sucuNombre),
                        if (_loading) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: const LinearProgressIndicator(minHeight: 3),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _InlineWarning(message: _error!, palette: palette),
                        ],
                        const SizedBox(height: 12),
                        _buildKpis(palette),
                        const SizedBox(height: 12),
                        _buildOperationalPulse(palette),
                        const SizedBox(height: 12),
                        _buildLiveTables(palette),
                        const SizedBox(height: 12),
                        _buildCharts(palette),
                        const SizedBox(height: 12),
                        _buildBusinessLists(palette),
                        const SizedBox(height: 12),
                        _buildSalesDetail(
                          palette: palette,
                          items: pageItems,
                          totalFiltered: filtered.length,
                          pageCount: pageCount,
                          branchId: branchId,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppPalette palette, String? branchName) {
    final rangeLabel = _inicio == _fin
        ? DateFormat('dd/MM/yyyy').format(_inicio)
        : '${DateFormat('dd/MM/yyyy').format(_inicio)} - ${DateFormat('dd/MM/yyyy').format(_fin)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 26, tint: palette.secondary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 930;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de ventas',
                      style: TextStyle(color: palette.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      branchName ?? 'Sucursal activa',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Facturación, recaudo, productos, responsables y detalle de cada operación.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PeriodControl(
                rangeLabel: rangeLabel,
                periodLabel: _periodName,
                palette: palette,
                onTap: _pickDateRange,
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  tooltip: 'Actualizar toda la información',
                  onPressed: _loading ? null : () => _load(force: true),
                  style: IconButton.styleFrom(
                    backgroundColor: palette.actionColor,
                    foregroundColor: palette.onAction,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            children: [Expanded(child: title), const SizedBox(width: 16), Flexible(child: actions)],
          );
        },
      ),
    );
  }

  Widget _buildKpis(AppPalette palette) {
    final total = _number(_summary, 'total_vendido');
    final propinas = _number(_summary, 'total_propinas');
    final productSales = (total - propinas).clamp(0, double.infinity).toDouble();
    final kpis = <_KpiData>[
      _KpiData(
        label: 'Ventas finalizadas',
        value: _formatInteger(_number(_summary, 'numero_ventas')),
        icon: Icons.receipt_long_rounded,
        tint: palette.secondary,
        variation: _variation(_number(_summary, 'numero_ventas'), _number(_previousSummary, 'numero_ventas')),
      ),
      _KpiData(
        label: 'Facturación total',
        value: CurrencyUtils.format(total),
        icon: Icons.payments_rounded,
        tint: AppColors.success,
        variation: _variation(total, _number(_previousSummary, 'total_vendido')),
      ),
      _KpiData(
        label: 'Venta de productos',
        value: CurrencyUtils.format(productSales),
        icon: Icons.local_bar_rounded,
        tint: AppColors.info,
        variation: _variation(
          productSales,
          (_number(_previousSummary, 'total_vendido') - _number(_previousSummary, 'total_propinas'))
              .clamp(0, double.infinity)
              .toDouble(),
        ),
      ),
      _KpiData(
        label: 'Ticket promedio',
        value: CurrencyUtils.format(_number(_summary, 'ticket_promedio')),
        icon: Icons.shopping_bag_rounded,
        tint: palette.primary,
        variation: _variation(_number(_summary, 'ticket_promedio'), _number(_previousSummary, 'ticket_promedio')),
      ),
      _KpiData(
        label: 'Propinas',
        value: CurrencyUtils.format(propinas),
        icon: Icons.volunteer_activism_rounded,
        tint: AppColors.warning,
        variation: _variation(propinas, _number(_previousSummary, 'total_propinas')),
      ),
      _KpiData(
        label: 'Unidades vendidas',
        value: _formatDecimal(_number(_summary, 'unidades_vendidas')),
        icon: Icons.inventory_rounded,
        tint: palette.accent,
        variation: _variation(_number(_summary, 'unidades_vendidas'), _number(_previousSummary, 'unidades_vendidas')),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 590
            ? 2
            : constraints.maxWidth < 980
                ? 3
                : 6;
        const spacing = 9.0;
        final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final kpi in kpis) SizedBox(width: width, child: _KpiCard(data: kpi, palette: palette)),
          ],
        );
      },
    );
  }

  Widget _buildOperationalPulse(AppPalette palette) {
    final finalized = _sales.where((sale) => sale.normalizedStatus == 'FINALIZADA').length;
    final open = _sales.where((sale) => sale.isOpen).length;
    final cancelled = _sales.where((sale) => sale.isCancelled).length;
    final balances = _sales.fold<double>(0, (sum, sale) => sum + sale.balance);
    final topSeller = _topSeller();
    final peakHour = _peakHour();

    final items = <_PulseData>[
      _PulseData('Finalizadas', '$finalized', Icons.check_circle_rounded, AppColors.success),
      _PulseData('Abiertas', '$open', Icons.pending_actions_rounded, AppColors.warning),
      _PulseData('Anuladas', '$cancelled', Icons.cancel_rounded, AppColors.danger),
      _PulseData('Saldo pendiente', CurrencyUtils.format(balances), Icons.account_balance_wallet_rounded, balances > 0 ? AppColors.danger : AppColors.success),
      _PulseData('Mejor responsable', topSeller.name, Icons.badge_rounded, palette.secondary, detail: CurrencyUtils.format(topSeller.total)),
      _PulseData('Hora más fuerte', peakHour.label, Icons.schedule_rounded, palette.accent, detail: CurrencyUtils.format(peakHour.total)),
    ];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width < 650
              ? (width - 8) / 2
              : width < 1080
                  ? (width - 16) / 3
                  : (width - 40) / 6;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in items) SizedBox(width: itemWidth, child: _PulseTile(data: item, palette: palette))],
          );
        },
      ),
    );
  }

  Widget _buildLiveTables(AppPalette palette) {
    final updatedLabel = _liveUpdatedAt == null
        ? 'Esperando actualización'
        : 'Actualizado ${DateFormat('HH:mm:ss').format(_liveUpdatedAt!)} · cada 5 s';

    return _DashboardPanel(
      title: 'Mesas en tiempo real',
      subtitle: '${_liveSales.length} mesas con venta activa · $updatedLabel',
      icon: Icons.table_restaurant_rounded,
      palette: palette,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: _autoRefresh ? 'Pausar actualización automática' : 'Reanudar actualización automática',
            child: Switch.adaptive(
              value: _autoRefresh,
              activeColor: AppColors.success,
              onChanged: (value) {
                setState(() => _autoRefresh = value);
                if (value) _refreshLiveSales();
              },
            ),
          ),
          IconButton(
            tooltip: 'Actualizar mesas ahora',
            onPressed: _liveLoading ? null : () => _refreshLiveSales(showLoading: true),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          if (_liveLoading && _liveSales.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_liveError != null && _liveSales.isEmpty) {
            return _InlineWarning(message: _liveError!, palette: palette);
          }
          if (_liveSales.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 48, color: AppColors.success.withOpacity(0.75)),
                  const SizedBox(height: 9),
                  Text(
                    'No hay mesas con pedidos activos',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cuando se abra una venta aparecerá aquí automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1220
                  ? 3
                  : constraints.maxWidth >= 760
                      ? 2
                      : 1;
              final gap = 10.0;
              final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final sale in _liveSales)
                    SizedBox(
                      width: width,
                      child: _LiveTableCard(
                        sale: sale,
                        palette: palette,
                        onTap: () => _showSaleDetail(sale.id),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCharts(AppPalette palette) {
    final trend = _mapList(_summary['ventas_por_fecha']);
    final paymentMethods = _mapList(_summary['medios_pago']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 900;
        final trendPanel = _DashboardPanel(
          title: 'Comportamiento de ventas',
          subtitle: 'Total vendido por día en el periodo seleccionado.',
          icon: Icons.show_chart_rounded,
          palette: palette,
          child: _SalesBars(rows: trend, palette: palette),
        );
        final paymentsPanel = _DashboardPanel(
          title: 'Medios de pago',
          subtitle: 'Cómo se distribuyó el recaudo registrado.',
          icon: Icons.account_balance_wallet_rounded,
          palette: palette,
          child: _PaymentDistribution(rows: paymentMethods, palette: palette),
        );
        if (vertical) {
          return Column(children: [trendPanel, const SizedBox(height: 12), paymentsPanel]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(flex: 3, child: trendPanel), const SizedBox(width: 12), Expanded(flex: 2, child: paymentsPanel)],
        );
      },
    );
  }

  Widget _buildBusinessLists(AppPalette palette) {
    final products = _mapList(_summary['productos_mas_vendidos']);
    final alerts = _mapList(_summary['alertas_inventario']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 900;
        final productsPanel = _DashboardPanel(
          title: 'Productos líderes',
          subtitle: 'Productos con mayor salida e ingreso.',
          icon: Icons.emoji_events_rounded,
          palette: palette,
          trailing: TextButton(onPressed: () => context.go('/reportes'), child: const Text('Ver reportes')),
          child: _TopProducts(rows: products, palette: palette),
        );
        final alertsPanel = _DashboardPanel(
          title: 'Alertas para decidir',
          subtitle: 'Inventario que puede afectar las próximas ventas.',
          icon: Icons.warning_amber_rounded,
          palette: palette,
          child: _InventoryAlerts(
            rows: alerts,
            exhausted: _number(_summary, 'productos_agotados').toInt(),
            low: _number(_summary, 'productos_stock_bajo').toInt(),
            negative: _number(_summary, 'productos_stock_negativo').toInt(),
            palette: palette,
          ),
        );
        if (vertical) return Column(children: [productsPanel, const SizedBox(height: 12), alertsPanel]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(flex: 3, child: productsPanel), const SizedBox(width: 12), Expanded(flex: 2, child: alertsPanel)],
        );
      },
    );
  }

  Widget _buildSalesDetail({
    required AppPalette palette,
    required List<_ManagerSale> items,
    required int totalFiltered,
    required int pageCount,
    required int? branchId,
  }) {
    return _DashboardPanel(
      title: 'Detalle de ventas',
      subtitle: '${_sales.length} operaciones consultadas · $totalFiltered coinciden con los filtros.',
      icon: Icons.manage_search_rounded,
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final search = SizedBox(
                height: 44,
                child: TextField(
                  maxLength: 120,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  controller: _searchController,
                  onChanged: (_) => setState(() => _page = 0),
                  decoration: InputDecoration(
                    hintText: 'Buscar ID, mesa, responsable o medio de pago',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _page = 0);
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              );
              final status = SizedBox(
                height: 44,
                width: compact ? double.infinity : 180,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Estado',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                    DropdownMenuItem(value: 'FINALIZADA', child: Text('Finalizadas')),
                    DropdownMenuItem(value: 'ABIERTA', child: Text('Abiertas')),
                    DropdownMenuItem(value: 'ANULADA', child: Text('Anuladas')),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value ?? 'TODOS';
                    _page = 0;
                  }),
                ),
              );
              if (compact) {
                return Column(children: [search, const SizedBox(height: 8), status]);
              }
              return Row(children: [Expanded(child: search), const SizedBox(width: 8), status]);
            },
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 46, color: palette.textSecondary.withOpacity(0.55)),
                  const SizedBox(height: 10),
                  Text('No hay ventas para mostrar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Cambia el periodo o limpia los filtros.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 860) {
                  return Column(children: [for (final sale in items) _MobileSaleCard(sale: sale, palette: palette, onOpen: () => _showSaleDetail(sale.id))]);
                }
                return _SalesDataTable(items: items, palette: palette, onOpen: (sale) => _showSaleDetail(sale.id));
              },
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Página ${_page + 1} de $pageCount',
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Página siguiente',
                  onPressed: _page + 1 < pageCount ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_loadGeneration;
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No hay una sucursal activa para consultar las ventas.';
        });
      }
      return;
    }
    if (_loading && !force && _loadedBranchId == branchId && _summary.isNotEmpty) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final days = _daysInRange;
    final previousEnd = _inicio.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: days - 1));
    final api = ref.read(apiClientProvider);

    try {
      final responses = await Future.wait([
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _parseMap,
          queryParameters: _params(_inicio, _fin, branchId),
        ),
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _parseMap,
          queryParameters: _params(previousStart, previousEnd, branchId),
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/ventas/detalle',
          _parseMapList,
          queryParameters: {..._params(_inicio, _fin, branchId), 'limite': 500},
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/ventas/tiempo-real',
          _parseMapList,
          queryParameters: {'sucursalId': branchId},
        ),
      ]);

      if (!mounted || generation != _loadGeneration ||
          ref.read(branchScopeProvider).activeBranchId != branchId) return;
      final current = responses[0].data as Map<String, dynamic>? ?? const <String, dynamic>{};
      final previous = responses[1].data as Map<String, dynamic>? ?? const <String, dynamic>{};
      final details = responses[2].data as List<Map<String, dynamic>>? ?? const <Map<String, dynamic>>[];
      final live = responses[3].data as List<Map<String, dynamic>>? ?? const <Map<String, dynamic>>[];
      setState(() {
        _summary = current;
        _previousSummary = previous;
        _sales = details.map(_ManagerSale.new).toList(growable: false);
        _liveSales = live.map(_LiveSale.fromJson).toList(growable: false);
        _liveUpdatedAt = DateTime.now();
        _liveLoading = false;
        _liveError = null;
        _loadedBranchId = branchId;
        _loading = false;
        _error = null;
        _page = 0;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration ||
          ref.read(branchScopeProvider).activeBranchId != branchId) return;
      final message = ErrorMapper.map(error).message;
      setState(() {
        _loading = false;
        _liveLoading = false;
        _error = message;
        _liveError ??= message;
      });
    }
  }

  void _startRealtimeTimer() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(_realtimeInterval, (_) {
      if (_autoRefresh && mounted) {
        _refreshLiveSales();
      }
    });
  }

  Future<void> _refreshLiveSales({bool showLoading = false}) async {
    if (_liveLoading) return;
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return;
    if (mounted) {
      setState(() {
        _liveLoading = true;
        if (showLoading) _liveError = null;
      });
    }
    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
            '${ApiPaths.reportes}/ventas/tiempo-real',
            _parseMapList,
            queryParameters: {'sucursalId': branchId},
          );
      if (!mounted || ref.read(branchScopeProvider).activeBranchId != branchId) return;
      final rows = response.data ?? const <Map<String, dynamic>>[];
      setState(() {
        _liveSales = rows.map(_LiveSale.fromJson).toList(growable: false);
        _liveUpdatedAt = DateTime.now();
        _liveLoading = false;
        _liveError = null;
      });
    } catch (error) {
      if (!mounted || ref.read(branchScopeProvider).activeBranchId != branchId) return;
      setState(() {
        _liveLoading = false;
        _liveError = ErrorMapper.map(error).message;
      });
    }
  }

  Future<void> _showSaleDetail(int? saleId) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (saleId == null || branchId == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (sheetContext) => _SaleDetailBottomSheet(
        saleId: saleId,
        branchId: branchId,
      ),
    );
    if (mounted && _autoRefresh) {
      await _refreshLiveSales();
    }
  }

  Future<void> _pickDateRange() async {
    final now = _dateOnly(DateTime.now());
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (sheetContext) => _PeriodPickerSheet(
        initialStart: _inicio,
        initialEnd: _fin,
        firstDate: now.subtract(const Duration(days: 366)),
        lastDate: now,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _inicio = _dateOnly(result.start);
      _fin = _dateOnly(result.end);
      _page = 0;
    });
    await _load(force: true);
  }

  Future<void> _applyPreset(_PeriodPreset preset) async {
    final today = _dateOnly(DateTime.now());
    setState(() {
      switch (preset) {
        case _PeriodPreset.today:
          _inicio = today;
          _fin = today;
          break;
        case _PeriodPreset.yesterday:
          _inicio = today.subtract(const Duration(days: 1));
          _fin = _inicio;
          break;
        case _PeriodPreset.sevenDays:
          _fin = today;
          _inicio = today.subtract(const Duration(days: 6));
          break;
        case _PeriodPreset.thirtyDays:
          _fin = today;
          _inicio = today.subtract(const Duration(days: 29));
          break;
        case _PeriodPreset.thisMonth:
          _fin = today;
          _inicio = DateTime(today.year, today.month, 1);
          break;
      }
      _page = 0;
    });
    await _load(force: true);
  }

  Map<String, dynamic> _params(DateTime start, DateTime end, int branchId) => {
        'inicio': _dateFormat.format(start),
        'fin': _dateFormat.format(end),
        'sucursalId': branchId,
      };

  List<_ManagerSale> _filteredSales() {
    final query = _searchController.text.trim().toLowerCase();
    return _sales.where((sale) {
      if (_status == 'FINALIZADA' && sale.normalizedStatus != 'FINALIZADA') return false;
      if (_status == 'ABIERTA' && !sale.isOpen) return false;
      if (_status == 'ANULADA' && !sale.isCancelled) return false;
      if (query.isEmpty) return true;
      return sale.searchText.contains(query);
    }).toList(growable: false);
  }

  _NamedAmount _topSeller() {
    final totals = <String, double>{};
    for (final sale in _sales.where((item) => item.normalizedStatus == 'FINALIZADA')) {
      totals.update(sale.responsible, (value) => value + sale.total, ifAbsent: () => sale.total);
    }
    if (totals.isEmpty) return const _NamedAmount('Sin datos', 0);
    final entry = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _NamedAmount(entry.key, entry.value);
  }

  _NamedAmount _peakHour() {
    final totals = <int, double>{};
    for (final sale in _sales.where((item) => item.normalizedStatus == 'FINALIZADA')) {
      final date = sale.date;
      if (date == null) continue;
      totals.update(date.hour, (value) => value + sale.total, ifAbsent: () => sale.total);
    }
    if (totals.isEmpty) return const _NamedAmount('Sin datos', 0);
    final entry = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _NamedAmount('${entry.key.toString().padLeft(2, '0')}:00', entry.value);
  }

  int get _daysInRange => _fin.difference(_inicio).inDays + 1;

  bool _isTodayRange() {
    final today = _dateOnly(DateTime.now());
    return _inicio == today && _fin == today;
  }

  bool _isYesterdayRange() {
    final yesterday = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    return _inicio == yesterday && _fin == yesterday;
  }

  String get _periodName {
    final today = _dateOnly(DateTime.now());
    if (_isTodayRange()) return 'Hoy';
    if (_isYesterdayRange()) return 'Ayer';
    if (_daysInRange == 7 && _fin == today) return 'Últimos 7 días';
    if (_daysInRange == 30 && _fin == today) return 'Últimos 30 días';
    if (_inicio == DateTime(today.year, today.month, 1) && _fin == today) return 'Este mes';
    return 'Periodo personalizado';
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}

enum _PeriodPreset { today, yesterday, sevenDays, thirtyDays, thisMonth }

class _ManagerSale {
  const _ManagerSale(this.data);

  final Map<String, dynamic> data;

  int? get id => _toInt(data['venta_id']);
  DateTime? get date => DateTime.tryParse(data['fecha']?.toString() ?? '');
  String get status => _value(data['estado'], 'SIN ESTADO');
  String get normalizedStatus => status.trim().toUpperCase();
  String get branch => _value(data['sucursal'], 'Sucursal');
  String get responsible => _value(data['responsable'], 'SIN_USUARIO');
  String get paymentMethods => _value(data['medios_pago'], 'SIN PAGO');
  int get tableNumber => _toInt(data['mesa_numero']) ?? 0;
  int get accounts => _toInt(data['cuentas']) ?? 0;
  int get distinctProducts => _toInt(data['productos_distintos']) ?? 0;
  double get units => _toDouble(data['unidades']);
  double get subtotal => _toDouble(data['subtotal_productos']);
  double get tip => _toDouble(data['propina']);
  double get total => _toDouble(data['total']);
  double get paid => _toDouble(data['total_pagado']);
  double get balance => _toDouble(data['saldo']);
  double get durationMinutes => _toDouble(data['duracion_minutos']);

  bool get isOpen => normalizedStatus.contains('ABIERT') || normalizedStatus.contains('ACTIV') || normalizedStatus.contains('PENDIENT');
  bool get isCancelled => normalizedStatus.contains('ANUL') || normalizedStatus.contains('CANCEL');

  String get searchText => '${id ?? ''} $tableNumber $responsible $paymentMethods $status $branch'.toLowerCase();

  static String _value(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _LiveSale {
  const _LiveSale({
    required this.id,
    required this.tableNumber,
    required this.tableDescription,
    required this.branch,
    required this.date,
    required this.status,
    required this.responsible,
    required this.total,
    required this.tip,
    required this.paid,
    required this.balance,
    required this.durationMinutes,
    required this.accounts,
  });

  final int id;
  final int tableNumber;
  final String tableDescription;
  final String branch;
  final DateTime? date;
  final String status;
  final String responsible;
  final double total;
  final double tip;
  final double paid;
  final double balance;
  final double durationMinutes;
  final List<_LiveAccount> accounts;

  factory _LiveSale.fromJson(Map<String, dynamic> json) => _LiveSale(
        id: _toInt(json['venta_id']) ?? 0,
        tableNumber: _toInt(json['mesa_numero']) ?? 0,
        tableDescription: _value(json['mesa_descripcion'], ''),
        branch: _value(json['sucursal'], 'Sucursal'),
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        status: _value(json['estado'], 'ABIERTA'),
        responsible: _value(json['responsable'], 'SIN_USUARIO'),
        total: _toDouble(json['total']),
        tip: _toDouble(json['propina']),
        paid: _toDouble(json['total_pagado']),
        balance: _toDouble(json['saldo_pendiente']),
        durationMinutes: _toDouble(json['duracion_minutos']),
        accounts: _mapList(json['cuentas']).map(_LiveAccount.fromJson).toList(growable: false),
      );

  String get normalizedStatus => status.trim().toUpperCase();
  bool get isOpen => normalizedStatus.contains('ABIERT') || normalizedStatus.contains('ACTIV') || normalizedStatus.contains('PENDIENT');
  int get productLines => accounts.fold(0, (sum, account) => sum + account.products.length);
  double get units => accounts.fold(0, (sum, account) => sum + account.units);
  int get paymentCount => accounts.fold(0, (sum, account) => sum + account.payments.length);
  List<_LiveProduct> get products => accounts.expand((account) => account.products).toList(growable: false);
  String get tableTitle => tableNumber > 0 ? 'Mesa $tableNumber' : 'Venta #$id';
}

class _LiveAccount {
  const _LiveAccount({
    required this.id,
    required this.number,
    required this.description,
    required this.total,
    required this.tip,
    required this.subtotal,
    required this.paid,
    required this.balance,
    required this.isPaid,
    required this.products,
    required this.payments,
  });

  final int id;
  final int number;
  final String description;
  final double total;
  final double tip;
  final double subtotal;
  final double paid;
  final double balance;
  final bool isPaid;
  final List<_LiveProduct> products;
  final List<_LivePayment> payments;

  factory _LiveAccount.fromJson(Map<String, dynamic> json) => _LiveAccount(
        id: _toInt(json['cuenta_id']) ?? 0,
        number: _toInt(json['numero']) ?? 0,
        description: _value(json['descripcion'], ''),
        total: _toDouble(json['total']),
        tip: _toDouble(json['propina']),
        subtotal: _toDouble(json['subtotal_productos']),
        paid: _toDouble(json['total_pagado']),
        balance: _toDouble(json['saldo_pendiente']),
        isPaid: _toBool(json['pagada']),
        products: _mapList(json['productos']).map(_LiveProduct.fromJson).toList(growable: false),
        payments: _mapList(json['pagos']).map(_LivePayment.fromJson).toList(growable: false),
      );

  double get units => products.fold(0, (sum, product) => sum + product.quantity);
  String get title {
    final base = number > 0 ? 'Cuenta $number' : 'Cuenta';
    return description.isEmpty ? base : '$base · $description';
  }
}

class _LiveProduct {
  const _LiveProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.paid,
  });

  final int id;
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool paid;

  factory _LiveProduct.fromJson(Map<String, dynamic> json) => _LiveProduct(
        id: _toInt(json['producto_id']) ?? 0,
        name: _value(json['producto_nombre'], 'Producto'),
        quantity: _toDouble(json['cantidad']),
        unitPrice: _toDouble(json['valor_unitario']),
        subtotal: _toDouble(json['subtotal']),
        paid: _toBool(json['pagado']),
      );
}

class _LivePayment {
  const _LivePayment({
    required this.id,
    required this.method,
    required this.value,
    required this.received,
    required this.change,
    required this.date,
    required this.responsible,
  });

  final int id;
  final String method;
  final double value;
  final double received;
  final double change;
  final DateTime? date;
  final String responsible;

  factory _LivePayment.fromJson(Map<String, dynamic> json) => _LivePayment(
        id: _toInt(json['pago_id']) ?? 0,
        method: _value(json['medio_pago_nombre'], 'Medio de pago'),
        value: _toDouble(json['valor']),
        received: _toDouble(json['valor_recibido']),
        change: _toDouble(json['cambio']),
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        responsible: _value(json['responsable'], 'SIN_USUARIO'),
      );
}

class _KpiData {
  const _KpiData({required this.label, required this.value, required this.icon, required this.tint, this.variation});

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final double? variation;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data, required this.palette});

  final _KpiData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final variation = data.variation;
    final positive = variation != null && variation >= 0;
    return Container(
      height: 126,
      padding: const EdgeInsets.all(12),
      decoration: palette.panelDecoration(baseRadius: 20, tint: data.tint, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: data.tint.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(data.icon, color: data.tint, size: 19),
              ),
              const Spacer(),
              if (variation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (positive ? AppColors.success : AppColors.danger).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${positive ? '+' : ''}${variation.toStringAsFixed(1)}%',
                    style: TextStyle(color: positive ? AppColors.success : AppColors.danger, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(data.label, maxLines: 2, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PulseData {
  const _PulseData(this.label, this.value, this.icon, this.tint, {this.detail});

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? detail;
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({required this.data, required this.palette});

  final _PulseData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: data.tint.withOpacity(palette.darkBackground ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: data.tint, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                if (data.detail != null)
                  Text(data.detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: data.tint, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.title, required this.subtitle, required this.icon, required this.palette, required this.child, this.trailing});

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 24, tint: palette.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: palette.secondary, size: 21),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SalesBars extends StatelessWidget {
  const _SalesBars({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _EmptyMini(message: 'No hay ventas finalizadas en el periodo.', palette: palette);
    final visible = rows.length > 20 ? rows.sublist(rows.length - 20) : rows;
    final maxValue = visible.fold<double>(0, (currentMax, row) {
      final value = _toDouble(row['total']);
      return value > currentMax ? value : currentMax;
    });
    return SizedBox(
      height: 210,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final row in visible)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: '${row['fecha'] ?? ''}\n${CurrencyUtils.format(_toDouble(row['total']))}\n${_formatInteger(_toDouble(row['ventas']))} ventas',
                  child: SizedBox(
                    width: 43,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _compactMoney(_toDouble(row['total'])),
                          maxLines: 1,
                          style: TextStyle(color: palette.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: maxValue <= 0
                              ? 4.0
                              : math.max(5.0, 132 * _toDouble(row['total']) / maxValue).toDouble(),
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [palette.primary, palette.secondary], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _shortDate(row['fecha']),
                          style: TextStyle(color: palette.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDistribution extends StatelessWidget {
  const _PaymentDistribution({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _EmptyMini(message: 'No hay recaudo registrado.', palette: palette);
    final total = rows.fold<double>(0, (sum, row) => sum + _toDouble(row['total']));
    return Column(
      children: [
        for (final row in rows.take(8)) ...[
          Row(
            children: [
              Expanded(child: Text(_value(row['medio_pago'], 'Sin medio'), style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w800))),
              Text(CurrencyUtils.format(_toDouble(row['total'])), style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total <= 0
                  ? 0.0
                  : (_toDouble(row['total']) / total).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: palette.secondary,
              backgroundColor: palette.textSecondary.withOpacity(0.13),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.rows, required this.palette});

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _EmptyMini(message: 'No hay productos vendidos en el periodo.', palette: palette);
    return Column(
      children: [
        for (var index = 0; index < math.min(8, rows.length); index++) ...[
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (index < 3 ? AppColors.warning : palette.secondary).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${index + 1}', style: TextStyle(color: index < 3 ? AppColors.warning : palette.secondary, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_value(rows[index]['producto'], 'Producto'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    Text('${_formatDecimal(_toDouble(rows[index]['cantidad']))} unidades', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(CurrencyUtils.format(_toDouble(rows[index]['total'])), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            ],
          ),
          if (index + 1 < math.min(8, rows.length))
            Divider(height: 17, color: palette.cardBorder.withOpacity(0.65)),
        ],
      ],
    );
  }
}

class _InventoryAlerts extends StatelessWidget {
  const _InventoryAlerts({required this.rows, required this.exhausted, required this.low, required this.negative, required this.palette});

  final List<Map<String, dynamic>> rows;
  final int exhausted;
  final int low;
  final int negative;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _AlertCount(label: 'Agotados', value: exhausted, tint: AppColors.danger, palette: palette),
            _AlertCount(label: 'Stock bajo', value: low, tint: AppColors.warning, palette: palette),
            _AlertCount(label: 'Negativos', value: negative, tint: AppColors.danger, palette: palette),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _EmptyMini(message: 'No hay alertas críticas asociadas a ventas.', palette: palette)
        else
          for (final row in rows.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: 7),
                  Expanded(child: Text(_value(row['producto'], 'Producto'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                  Text('${_formatDecimal(_toDouble(row['stock_actual']))} und.', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
      ],
    );
  }
}

class _AlertCount extends StatelessWidget {
  const _AlertCount({required this.label, required this.value, required this.tint, required this.palette});

  final String label;
  final int value;
  final Color tint;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: tint.withOpacity(0.11), borderRadius: BorderRadius.circular(12)),
      child: Text('$label: $value', style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _LiveTableCard extends StatelessWidget {
  const _LiveTableCard({required this.sale, required this.palette, required this.onTap});

  final _LiveSale sale;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = sale.products.take(3).toList(growable: false);
    final paidRatio = sale.total <= 0 ? 0.0 : (sale.paid / sale.total).clamp(0.0, 1.0).toDouble();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.66),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(color: AppColors.success.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.tableTitle, style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                        Text(
                          sale.tableDescription.isEmpty ? 'Venta #${sale.id}' : '${sale.tableDescription} · Venta #${sale.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const _LivePulse(),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _CompactInfo(icon: Icons.person_outline_rounded, value: sale.responsible, palette: palette)),
                  const SizedBox(width: 7),
                  _CompactInfo(icon: Icons.schedule_rounded, value: _durationLabel(sale.durationMinutes), palette: palette),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surface.withOpacity(palette.darkBackground ? 0.28 : 0.72),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: preview.isEmpty
                    ? Text('Sin productos pedidos todavía', style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700))
                    : Column(
                        children: [
                          for (var index = 0; index < preview.length; index++) ...[
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    _formatDecimal(preview[index].quantity),
                                    style: TextStyle(color: palette.secondary, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    preview[index].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(CurrencyUtils.format(preview[index].subtotal), style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            if (index + 1 < preview.length) const SizedBox(height: 6),
                          ],
                          if (sale.productLines > preview.length) ...[
                            const SizedBox(height: 7),
                            Text(
                              '+${sale.productLines - preview.length} productos más',
                              style: TextStyle(color: palette.secondary, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniCount(icon: Icons.layers_outlined, label: '${sale.accounts.length} cuentas', palette: palette),
                  const SizedBox(width: 7),
                  _MiniCount(icon: Icons.shopping_bag_outlined, label: '${_formatDecimal(sale.units)} und.', palette: palette),
                  const Spacer(),
                  Text(CurrencyUtils.format(sale.total), style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: paidRatio,
                  minHeight: 6,
                  backgroundColor: palette.cardBorder.withOpacity(0.45),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pagado ${CurrencyUtils.format(sale.paid)}',
                      style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'Saldo ${CurrencyUtils.format(sale.balance)}',
                    style: TextStyle(color: sale.balance > 0 ? AppColors.warning : AppColors.success, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_less_rounded, color: palette.textSecondary, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({required this.icon, required this.value, required this.palette});
  final IconData icon;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: palette.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.icon, required this.label, required this.palette});
  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(color: palette.secondary.withOpacity(0.09), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.secondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 9.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LivePulse extends StatelessWidget {
  const _LivePulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: AppColors.success, size: 8),
          SizedBox(width: 5),
          Text('EN VIVO', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SaleDetailBottomSheet extends ConsumerStatefulWidget {
  const _SaleDetailBottomSheet({required this.saleId, required this.branchId});

  final int saleId;
  final int branchId;

  @override
  ConsumerState<_SaleDetailBottomSheet> createState() => _SaleDetailBottomSheetState();
}

class _SaleDetailBottomSheetState extends ConsumerState<_SaleDetailBottomSheet> {
  _LiveSale? _sale;
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && (_sale?.isOpen ?? true)) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    if (mounted) {
      setState(() {
        _refreshing = true;
        if (!silent && _sale == null) _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '${ApiPaths.reportes}/ventas/${widget.saleId}/detalle-operativo',
            _parseMap,
            queryParameters: {'sucursalId': widget.branchId},
          );
      if (!mounted) return;
      final sale = _LiveSale.fromJson(response.data ?? const <String, dynamic>{});
      setState(() {
        _sale = sale;
        _updatedAt = DateTime.now();
        _loading = false;
        _refreshing = false;
        _error = null;
      });
      if (!sale.isOpen) _timer?.cancel();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.58,
      maxChildSize: 0.98,
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
                decoration: BoxDecoration(color: palette.textSecondary.withOpacity(0.30), borderRadius: BorderRadius.circular(99)),
              ),
              _buildHeader(palette),
              if (_refreshing && _sale != null)
                const LinearProgressIndicator(minHeight: 2),
              const Divider(height: 1),
              Expanded(child: _buildBody(palette, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppPalette palette) {
    final sale = _sale;
    final updatedLabel = _updatedAt == null ? '' : 'Actualizado ${DateFormat('HH:mm:ss').format(_updatedAt!)}';
    final subtitle = sale == null
        ? 'Consultando información...'
        : '${sale.status} · ${sale.responsible}${updatedLabel.isEmpty ? '' : ' · $updatedLabel'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 10, 11),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(15)),
            child: Icon(Icons.receipt_long_rounded, color: palette.secondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale == null ? 'Detalle de venta' : '${sale.tableTitle} · Venta #${sale.id}',
                  style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (sale?.isOpen ?? false) ...[
                      const Icon(Icons.circle, size: 8, color: AppColors.success),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshing ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette palette, ScrollController scrollController) {
    if (_loading && _sale == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sale == null) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          _InlineWarning(message: _error!, palette: palette),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
        ],
      );
    }
    final sale = _sale;
    if (sale == null) return const SizedBox.shrink();
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (_error != null) ...[
          _InlineWarning(message: _error!, palette: palette),
          const SizedBox(height: 10),
        ],
        _SaleOverview(sale: sale, palette: palette),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Cuentas y pedidos', style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900))),
            Text('${sale.accounts.length} cuentas', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 9),
        if (sale.accounts.isEmpty)
          _EmptyMini(message: 'La venta todavía no tiene cuentas.', palette: palette)
        else
          for (final account in sale.accounts) ...[
            _LiveAccountCard(account: account, palette: palette),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _SaleOverview extends StatelessWidget {
  const _SaleOverview({required this.sale, required this.palette});

  final _LiveSale sale;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _DetailMetricData('Total', CurrencyUtils.format(sale.total), Icons.payments_outlined, palette.secondary),
      _DetailMetricData('Pagado', CurrencyUtils.format(sale.paid), Icons.check_circle_outline_rounded, AppColors.success),
      _DetailMetricData('Saldo', CurrencyUtils.format(sale.balance), Icons.pending_actions_rounded, sale.balance > 0 ? AppColors.warning : AppColors.success),
      _DetailMetricData('Propina', CurrencyUtils.format(sale.tip), Icons.volunteer_activism_outlined, AppColors.info),
      _DetailMetricData('Productos', '${sale.productLines} líneas · ${_formatDecimal(sale.units)} und.', Icons.shopping_bag_outlined, palette.secondary),
      _DetailMetricData('Tiempo', _durationLabel(sale.durationMinutes), Icons.schedule_rounded, AppColors.warning),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 3 : constraints.maxWidth >= 470 ? 2 : 1;
        final gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final metric in metrics) SizedBox(width: width, child: _DetailMetric(data: metric, palette: palette))],
        );
      },
    );
  }
}

class _DetailMetricData {
  const _DetailMetricData(this.label, this.value, this.icon, this.tint);
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.data, required this.palette});
  final _DetailMetricData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: data.tint.withOpacity(0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: data.tint.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: data.tint, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: TextStyle(color: palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAccountCard extends StatelessWidget {
  const _LiveAccountCard({required this.account, required this.palette});

  final _LiveAccount account;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final statusColor = account.isPaid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.32 : 0.58),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: palette.cardBorder.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(account.title, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                child: Text(account.isPaid ? 'PAGADA' : 'PENDIENTE', style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _SmallSaleInfo(label: 'Subtotal', value: CurrencyUtils.format(account.subtotal), palette: palette)),
              Expanded(child: _SmallSaleInfo(label: 'Propina', value: CurrencyUtils.format(account.tip), palette: palette)),
              Expanded(child: _SmallSaleInfo(label: 'Total', value: CurrencyUtils.format(account.total), palette: palette)),
              Expanded(child: _SmallSaleInfo(label: 'Saldo', value: CurrencyUtils.format(account.balance), palette: palette, tint: account.balance > 0 ? AppColors.warning : AppColors.success)),
            ],
          ),
          const SizedBox(height: 11),
          Text('Productos pedidos', style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (account.products.isEmpty)
            Text('Sin productos', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))
          else
            for (var index = 0; index < account.products.length; index++) ...[
              _LiveProductRow(product: account.products[index], palette: palette),
              if (index + 1 < account.products.length) Divider(height: 13, color: palette.cardBorder.withOpacity(0.55)),
            ],
          if (account.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Pagos registrados', style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (var index = 0; index < account.payments.length; index++) ...[
              _LivePaymentRow(payment: account.payments[index], palette: palette),
              if (index + 1 < account.payments.length) Divider(height: 13, color: palette.cardBorder.withOpacity(0.55)),
            ],
          ],
        ],
      ),
    );
  }
}

class _LiveProductRow extends StatelessWidget {
  const _LiveProductRow({required this.product, required this.palette});
  final _LiveProduct product;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(11)),
          child: Text(_formatDecimal(product.quantity), style: TextStyle(color: palette.secondary, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
              Text('${CurrencyUtils.format(product.unitPrice)} c/u${product.paid ? ' · pagado' : ''}', style: TextStyle(color: product.paid ? AppColors.success : palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Text(CurrencyUtils.format(product.subtotal), style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _LivePaymentRow extends StatelessWidget {
  const _LivePaymentRow({required this.payment, required this.palette});
  final _LivePayment payment;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.11), borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(payment.method, style: TextStyle(color: palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
              Text(
                '${_formatDateTime(payment.date)} · ${payment.responsible}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(CurrencyUtils.format(payment.value), style: const TextStyle(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w900)),
            if (payment.change > 0)
              Text('Cambio ${CurrencyUtils.format(payment.change)}', style: TextStyle(color: palette.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _SalesDataTable extends StatelessWidget {
  const _SalesDataTable({required this.items, required this.palette, required this.onOpen});

  final List<_ManagerSale> items;
  final AppPalette palette;
  final ValueChanged<_ManagerSale> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 58,
        columnSpacing: 22,
        headingTextStyle: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w900),
        dataTextStyle: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        columns: const [
          DataColumn(label: Text('Venta')),
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Mesa')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Responsable')),
          DataColumn(label: Text('Productos')),
          DataColumn(label: Text('Medio de pago')),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('Pagado'), numeric: true),
          DataColumn(label: Text('Saldo'), numeric: true),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final sale in items)
            DataRow(
              cells: [
                DataCell(Text('#${sale.id ?? '-'}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900))),
                DataCell(Text(_formatDateTime(sale.date))),
                DataCell(Text('Mesa ${sale.tableNumber}')),
                DataCell(_SaleStatusChip(sale: sale, palette: palette)),
                DataCell(SizedBox(width: 120, child: Text(sale.responsible, maxLines: 1, overflow: TextOverflow.ellipsis))),
                DataCell(Text('${sale.distinctProducts} prod. · ${_formatDecimal(sale.units)} und.')),
                DataCell(SizedBox(width: 125, child: Text(sale.paymentMethods, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(CurrencyUtils.format(sale.total), style: const TextStyle(fontWeight: FontWeight.w900))),
                DataCell(Text(CurrencyUtils.format(sale.paid))),
                DataCell(Text(CurrencyUtils.format(sale.balance), style: TextStyle(color: sale.balance > 0 ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w900))),
                DataCell(
                  IconButton(
                    tooltip: 'Ver venta',
                    onPressed: sale.id == null ? null : () => onOpen(sale),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MobileSaleCard extends StatelessWidget {
  const _MobileSaleCard({required this.sale, required this.palette, required this.onOpen});

  final _ManagerSale sale;
  final AppPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.62),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.cardBorder.withOpacity(0.65)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('#${sale.id ?? '-'} · Mesa ${sale.tableNumber}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
              _SaleStatusChip(sale: sale, palette: palette),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: Text(_formatDateTime(sale.date), style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700))),
              Text(CurrencyUtils.format(sale.total), style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          Divider(height: 16, color: palette.cardBorder.withOpacity(0.65)),
          Row(
            children: [
              Expanded(child: _SmallSaleInfo(label: 'Responsable', value: sale.responsible, palette: palette)),
              Expanded(child: _SmallSaleInfo(label: 'Productos', value: '${sale.distinctProducts} · ${_formatDecimal(sale.units)} und.', palette: palette)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _SmallSaleInfo(label: 'Pago', value: sale.paymentMethods, palette: palette)),
              Expanded(child: _SmallSaleInfo(label: 'Saldo', value: CurrencyUtils.format(sale.balance), palette: palette, tint: sale.balance > 0 ? AppColors.danger : AppColors.success)),
              IconButton(
                tooltip: 'Ver venta',
                onPressed: sale.id == null ? null : onOpen,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallSaleInfo extends StatelessWidget {
  const _SmallSaleInfo({required this.label, required this.value, required this.palette, this.tint});

  final String label;
  final String value;
  final AppPalette palette;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tint ?? palette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SaleStatusChip extends StatelessWidget {
  const _SaleStatusChip({required this.sale, required this.palette});

  final _ManagerSale sale;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = sale.normalizedStatus == 'FINALIZADA'
        ? AppColors.success
        : sale.isCancelled
            ? AppColors.danger
            : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(sale.status, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _PeriodControl extends StatelessWidget {
  const _PeriodControl({
    required this.rangeLabel,
    required this.periodLabel,
    required this.palette,
    required this.onTap,
  });

  final String rangeLabel;
  final String periodLabel;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 230),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(palette.darkBackground ? 0.35 : 0.62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder.withOpacity(0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.calendar_month_rounded, color: palette.secondary, size: 18),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.expand_more_rounded, color: palette.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodPickerSheet extends ConsumerStatefulWidget {
  const _PeriodPickerSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  ConsumerState<_PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends ConsumerState<_PeriodPickerSheet> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  void _setPreset(_PeriodPreset preset) {
    final today = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    setState(() {
      switch (preset) {
        case _PeriodPreset.today:
          _start = today;
          _end = today;
          break;
        case _PeriodPreset.yesterday:
          _start = today.subtract(const Duration(days: 1));
          _end = _start;
          break;
        case _PeriodPreset.sevenDays:
          _end = today;
          _start = today.subtract(const Duration(days: 6));
          break;
        case _PeriodPreset.thirtyDays:
          _end = today;
          _start = today.subtract(const Duration(days: 29));
          break;
        case _PeriodPreset.thisMonth:
          _start = DateTime(today.year, today.month, 1);
          _end = today;
          break;
      }
    });
  }

  bool _matches(_PeriodPreset preset) {
    final today = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return switch (preset) {
      _PeriodPreset.today => _start == today && _end == today,
      _PeriodPreset.yesterday => _start == today.subtract(const Duration(days: 1)) && _end == _start,
      _PeriodPreset.sevenDays => _end == today && _end.difference(_start).inDays == 6,
      _PeriodPreset.thirtyDays => _end == today && _end.difference(_start).inDays == 29,
      _PeriodPreset.thisMonth => _start == DateTime(today.year, today.month, 1) && _end == today,
    };
  }

  Future<void> _pickDate({required bool start}) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: start ? 'Fecha inicial' : 'Fecha final',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: palette.actionColor,
                onPrimary: palette.onAction,
                surface: palette.surface,
                onSurface: palette.textPrimary,
              ),
          dialogTheme: DialogThemeData(
            backgroundColor: palette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    final value = DateTime(selected.year, selected.month, selected.day);
    setState(() {
      if (start) {
        _start = value;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = value;
        if (_start.isAfter(_end)) _start = _end;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final days = _end.difference(_start).inDays + 1;
    final options = <(_PeriodPreset, String, IconData)>[
      (_PeriodPreset.today, 'Hoy', Icons.today_rounded),
      (_PeriodPreset.yesterday, 'Ayer', Icons.history_rounded),
      (_PeriodPreset.sevenDays, '7 días', Icons.view_week_rounded),
      (_PeriodPreset.thirtyDays, '30 días', Icons.calendar_view_month_rounded),
      (_PeriodPreset.thisMonth, 'Este mes', Icons.date_range_rounded),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.55,
      maxChildSize: 0.92,
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
                  color: palette.textSecondary.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.calendar_month_rounded, color: palette.secondary),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Periodo de análisis', style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                          Text('Selecciona un rango rápido o define las fechas.', style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    Text('Rangos rápidos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in options)
                          _PeriodPresetOption(
                            label: option.$2,
                            icon: option.$3,
                            selected: _matches(option.$1),
                            palette: palette,
                            onTap: () => _setPreset(option.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Fechas personalizadas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 9),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final vertical = constraints.maxWidth < 560;
                        final from = _DateSelectorCard(
                          label: 'Desde',
                          date: _start,
                          palette: palette,
                          onTap: () => _pickDate(start: true),
                        );
                        final to = _DateSelectorCard(
                          label: 'Hasta',
                          date: _end,
                          palette: palette,
                          onTap: () => _pickDate(start: false),
                        );
                        if (vertical) return Column(children: [from, const SizedBox(height: 8), to]);
                        return Row(children: [Expanded(child: from), const SizedBox(width: 9), Expanded(child: to)]);
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: palette.secondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$days ${days == 1 ? 'día seleccionado' : 'días seleccionados'}',
                              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(DateTimeRange(start: _start, end: _end)),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.actionColor,
                      foregroundColor: palette.onAction,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar periodo', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodPresetOption extends StatelessWidget {
  const _PeriodPresetOption({required this.label, required this.icon, required this.selected, required this.palette, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.actionColor : palette.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? palette.actionColor : palette.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? palette.onAction : palette.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? palette.onAction : palette.textPrimary, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _DateSelectorCard extends StatelessWidget {
  const _DateSelectorCard({required this.label, required this.date, required this.palette, required this.onTap});

  final String label;
  final DateTime date;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.event_rounded, color: palette.secondary, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_rounded, color: palette.textSecondary, size: 19),
          ],
        ),
      ),
    );
  }
}

class _QuickRangeButton extends StatelessWidget {
  const _QuickRangeButton({required this.label, required this.selected, required this.onTap, required this.palette});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: selected
          ? FilledButton(onPressed: onTap, style: FilledButton.styleFrom(backgroundColor: palette.actionColor, foregroundColor: palette.onAction, padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(label))
          : OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(foregroundColor: palette.textPrimary, side: BorderSide(color: palette.cardBorder), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(label)),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message, required this.palette});

  final String message;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.message, required this.palette});

  final String message;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
    );
  }
}

class _NamedAmount {
  const _NamedAmount(this.name, this.total);

  final String name;
  final double total;

  String get label => name;
}

Map<String, dynamic> _parseMap(Object? json) {
  if (json is Map) return Map<String, dynamic>.from(json);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _parseMapList(Object? json) {
  return (json as List? ?? const <Object?>[])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  return (value as List? ?? const <Object?>[])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double _number(Map<String, dynamic> map, String key) => _toDouble(map[key]);

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

String _value(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double? _variation(double current, double previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return ((current - previous) / previous) * 100;
}

String _formatInteger(num value) => NumberFormat.decimalPattern('es_CO').format(value.round());

String _formatDecimal(num value) {
  if (value == value.roundToDouble()) return _formatInteger(value);
  return NumberFormat('#,##0.##', 'es_CO').format(value);
}

String _compactMoney(double value) {
  if (value.abs() >= 1000000) return r'$' + '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value.abs() >= 1000) return r'$' + '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}k';
  return r'$' + value.toStringAsFixed(0);
}

String _shortDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '--' : DateFormat('dd/MM').format(date);
}

String _formatDateTime(DateTime? value) => value == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());

String _durationLabel(double minutes) {
  final total = minutes.round().clamp(0, 1000000);
  if (total < 60) return '$total min';
  final hours = total ~/ 60;
  final remaining = total % 60;
  if (hours < 24) return remaining == 0 ? '$hours h' : '$hours h $remaining min';
  final days = hours ~/ 24;
  final dayHours = hours % 24;
  return dayHours == 0 ? '$days d' : '$days d $dayHours h';
}
