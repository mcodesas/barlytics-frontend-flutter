import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Centro gerencial de productos consumidos por cuenta.
///
/// El rol GERENTE consulta aquí cada producto pedido, su cuenta, mesa,
/// responsable, estado de pago y valor. La operación es de solo lectura: los
/// cambios de cantidades, pagos y cierre continúan perteneciendo al flujo POS.
class DetalleCuentaVentaListPage extends ConsumerStatefulWidget {
  const DetalleCuentaVentaListPage({super.key});

  @override
  ConsumerState<DetalleCuentaVentaListPage> createState() =>
      _DetalleCuentaVentaListPageState();
}

class _DetalleCuentaVentaListPageState
    extends ConsumerState<DetalleCuentaVentaListPage> {
  static const _pageSize = 18;
  static const _refreshInterval = Duration(seconds: 5);

  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  late DateTime _from;
  late DateTime _to;
  Timer? _timer;
  bool _loading = true;
  bool _liveLoading = true;
  bool _autoRefresh = true;
  String? _error;
  String? _liveError;
  int? _loadedBranchId;
  DateTime? _liveUpdatedAt;
  List<_DetailLineSummary> _history = const [];
  List<_LiveAccountGroup> _liveGroups = const [];
  String _paymentStatus = 'TODOS';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _from = today.subtract(const Duration(days: 6));
    _to = today;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(force: true);
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _load(force: true));
      },
    );

    if (_loading && _history.isEmpty) {
      return const AppLoader(message: 'Preparando el detalle de cuentas...');
    }
    if (_error != null && _history.isEmpty) {
      return AppErrorView(
        message: _error!,
        onRetry: () => _load(force: true),
      );
    }

    final filtered = _filteredHistory();
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil()).toInt();
    if (_page >= pageCount) _page = pageCount - 1;
    final pageItems = filtered
        .skip(_page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

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
                        _buildHeader(
                          palette,
                          branchState.activeBranch?.sucuNombre,
                        ),
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
                        _buildLiveSection(palette, branchId),
                        const SizedBox(height: 12),
                        _buildHistorySection(
                          palette: palette,
                          items: pageItems,
                          filteredCount: filtered.length,
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
    final range = _from == _to
        ? DateFormat('dd/MM/yyyy').format(_from)
        : '${DateFormat('dd/MM/yyyy').format(_from)} - '
            '${DateFormat('dd/MM/yyyy').format(_to)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(
        baseRadius: 26,
        tint: palette.secondary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
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
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: palette.secondary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de consumos',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      branchName ?? 'Sucursal activa',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revisa cada producto pedido, quién lo registró, en qué '
                      'mesa está y si ya fue pagado.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              InkWell(
                onTap: _pickPeriod,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: palette.background.withOpacity(
                      palette.darkBackground ? 0.48 : 0.72,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 19,
                        color: palette.secondary,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _periodName,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            range,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        Icons.expand_more_rounded,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  tooltip: 'Actualizar información',
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
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpis(AppPalette palette) {
    final accounts = _history.map((line) => line.accountId).toSet().length;
    final units = _history.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final subtotal = _history.fold<double>(
      0,
      (sum, line) => sum + line.subtotal,
    );
    final paid = _history.where((line) => line.paid).length;
    final pending = _history.where((line) => !line.paid).length;
    final pendingValue = _history
        .where((line) => !line.paid)
        .fold<double>(0, (sum, line) => sum + line.subtotal);

    final data = <_KpiData>[
      _KpiData(
        label: 'Productos registrados',
        value: '${_history.length}',
        icon: Icons.inventory_2_rounded,
        tint: palette.secondary,
      ),
      _KpiData(
        label: 'Cuentas involucradas',
        value: '$accounts',
        icon: Icons.receipt_rounded,
        tint: palette.accent,
      ),
      _KpiData(
        label: 'Unidades pedidas',
        value: _formatQuantity(units),
        icon: Icons.shopping_bag_rounded,
        tint: AppColors.info,
      ),
      _KpiData(
        label: 'Consumo detallado',
        value: CurrencyUtils.format(subtotal),
        icon: Icons.point_of_sale_rounded,
        tint: AppColors.success,
      ),
      _KpiData(
        label: 'Líneas pagadas',
        value: '$paid',
        icon: Icons.verified_rounded,
        tint: AppColors.success,
      ),
      _KpiData(
        label: 'Pendiente por cobrar',
        value: '$pending · ${CurrencyUtils.format(pendingValue)}',
        icon: Icons.pending_actions_rounded,
        tint: pending > 0 ? AppColors.warning : AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 6
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 470
                    ? 2
                    : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in data)
              SizedBox(
                width: width,
                child: _KpiCard(data: item, palette: palette),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLiveSection(AppPalette palette, int? branchId) {
    final units = _liveGroups.fold<double>(
      0,
      (sum, group) => sum + group.units,
    );
    final value = _liveGroups.fold<double>(
      0,
      (sum, group) => sum + group.products.fold<double>(
        0,
        (productSum, product) => productSum + product.subtotal,
      ),
    );
    final updated = _liveUpdatedAt == null
        ? 'Sin actualizar'
        : DateFormat('HH:mm:ss').format(_liveUpdatedAt!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: AppColors.success,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final info = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pedidos activos por cuenta',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _LiveBadge(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_liveGroups.length} cuentas · '
                          '${_formatQuantity(units)} unidades · '
                          '${CurrencyUtils.format(value)} en productos',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final controls = Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Actualizado $updated',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: _autoRefresh
                        ? 'Pausar actualización automática'
                        : 'Reanudar actualización automática',
                    onPressed: () =>
                        setState(() => _autoRefresh = !_autoRefresh),
                    icon: Icon(
                      _autoRefresh
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar ahora',
                    onPressed: _liveLoading
                        ? null
                        : () => _refreshLive(showLoading: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 8), controls],
                );
              }
              return Row(children: [Expanded(child: info), controls]);
            },
          ),
          if (_liveLoading) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ],
          if (_liveError != null) ...[
            const SizedBox(height: 8),
            _InlineWarning(message: _liveError!, palette: palette),
          ],
          const SizedBox(height: 11),
          if (_liveGroups.isEmpty && !_liveLoading)
            _EmptyState(
              icon: Icons.table_bar_outlined,
              title: 'No hay pedidos activos',
              message: 'Las mesas abiertas aparecerán aquí automáticamente.',
              palette: palette,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1120
                    ? 3
                    : constraints.maxWidth >= 700
                        ? 2
                        : 1;
                const spacing = 10.0;
                final width =
                    (constraints.maxWidth - (columns - 1) * spacing) /
                        columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final group in _liveGroups.take(12))
                      SizedBox(
                        width: width,
                        child: _LiveAccountCard(
                          group: group,
                          palette: palette,
                          onTap: branchId == null
                              ? null
                              : () => _openAccountDetail(
                                    group.accountId,
                                    branchId,
                                  ),
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

  Widget _buildHistorySection({
    required AppPalette palette,
    required List<_DetailLineSummary> items,
    required int filteredCount,
    required int pageCount,
    required int? branchId,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: palette.accent,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de productos por cuenta',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$filteredCount líneas encontradas en $_periodName.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );

              final filters = Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _PaymentFilterChip(
                    value: 'TODOS',
                    selected: _paymentStatus == 'TODOS',
                    palette: palette,
                    onTap: () => _changePaymentStatus('TODOS'),
                  ),
                  _PaymentFilterChip(
                    value: 'PENDIENTE',
                    selected: _paymentStatus == 'PENDIENTE',
                    palette: palette,
                    onTap: () => _changePaymentStatus('PENDIENTE'),
                  ),
                  _PaymentFilterChip(
                    value: 'PAGADO',
                    selected: _paymentStatus == 'PAGADO',
                    palette: palette,
                    onTap: () => _changePaymentStatus('PAGADO'),
                  ),
                ],
              );

              if (constraints.maxWidth < 780) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 10), filters],
                );
              }
              return Row(
                children: [Expanded(child: title), Flexible(child: filters)],
              );
            },
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() => _page = 0),
            decoration: InputDecoration(
              hintText:
                  'Buscar producto, mesa, cuenta, venta, responsable o medio de pago',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _page = 0);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Sin resultados',
              message:
                  'No hay productos que coincidan con los filtros seleccionados.',
              palette: palette,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 920) {
                  return _DetailLinesTable(
                    items: items,
                    palette: palette,
                    onOpen: branchId == null
                        ? null
                        : (line) => _openAccountDetail(
                              line.accountId,
                              branchId,
                              highlightedDetailId: line.id,
                            ),
                  );
                }
                return Column(
                  children: [
                    for (final line in items)
                      _DetailLineCard(
                        line: line,
                        palette: palette,
                        onTap: branchId == null
                            ? null
                            : () => _openAccountDetail(
                                  line.accountId,
                                  branchId,
                                  highlightedDetailId: line.id,
                                ),
                      ),
                  ],
                );
              },
            ),
          if (filteredCount > _pageSize) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Página ${_page + 1} de $pageCount',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Página siguiente',
                  onPressed: _page + 1 < pageCount
                      ? () => setState(() => _page++)
                      : null,
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
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _liveLoading = false;
          _error = 'Selecciona una sucursal para consultar los consumos.';
        });
      }
      return;
    }
    if (_loading && !force && _loadedBranchId == branchId && _history.isNotEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final responses = await Future.wait([
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/detalle-cuentas-venta',
          _parseMapList,
          queryParameters: {
            'inicio': _dateFormat.format(_from),
            'fin': _dateFormat.format(_to),
            'sucursalId': branchId,
            'estadoPago': _paymentStatus,
            'limite': 3000,
          },
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/ventas/tiempo-real',
          _parseMapList,
          queryParameters: {'sucursalId': branchId},
        ),
      ]);
      if (!mounted) return;
      final historyRows = responses[0].data ?? const <Map<String, dynamic>>[];
      final liveRows = responses[1].data ?? const <Map<String, dynamic>>[];
      setState(() {
        _history = historyRows
            .map(_DetailLineSummary.fromJson)
            .toList(growable: false);
        _liveGroups = _flattenLiveGroups(liveRows);
        _loadedBranchId = branchId;
        _liveUpdatedAt = DateTime.now();
        _loading = false;
        _liveLoading = false;
        _error = null;
        _liveError = null;
        _page = 0;
      });
    } catch (error) {
      if (!mounted) return;
      final message = ErrorMapper.map(error).message;
      setState(() {
        _loading = false;
        _liveLoading = false;
        _error = message;
        _liveError ??= message;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (_autoRefresh && mounted) _refreshLive();
    });
  }

  Future<void> _refreshLive({bool showLoading = false}) async {
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
      final response =
          await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
                '${ApiPaths.reportes}/ventas/tiempo-real',
                _parseMapList,
                queryParameters: {'sucursalId': branchId},
              );
      if (!mounted) return;
      setState(() {
        _liveGroups = _flattenLiveGroups(
          response.data ?? const <Map<String, dynamic>>[],
        );
        _liveUpdatedAt = DateTime.now();
        _liveLoading = false;
        _liveError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liveLoading = false;
        _liveError = ErrorMapper.map(error).message;
      });
    }
  }

  Future<void> _openAccountDetail(
    int accountId,
    int branchId, {
    int? highlightedDetailId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (_) => _AccountDetailSheet(
        accountId: accountId,
        branchId: branchId,
        highlightedDetailId: highlightedDetailId,
      ),
    );
    if (mounted && _autoRefresh) await _refreshLive();
  }

  Future<void> _pickPeriod() async {
    final today = _dateOnly(DateTime.now());
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _PeriodPickerSheet(
        initialStart: _from,
        initialEnd: _to,
        firstDate: today.subtract(const Duration(days: 366)),
        lastDate: today,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _from = _dateOnly(result.start);
      _to = _dateOnly(result.end);
      _page = 0;
    });
    await _load(force: true);
  }

  void _changePaymentStatus(String value) {
    if (_paymentStatus == value) return;
    setState(() {
      _paymentStatus = value;
      _page = 0;
    });
    _load(force: true);
  }

  List<_DetailLineSummary> _filteredHistory() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _history;
    return _history
        .where((item) => item.searchText.contains(query))
        .toList(growable: false);
  }

  List<_LiveAccountGroup> _flattenLiveGroups(
    List<Map<String, dynamic>> sales,
  ) {
    final result = <_LiveAccountGroup>[];
    for (final sale in sales) {
      final saleId = _toInt(sale['venta_id']) ?? 0;
      final table = _toInt(sale['mesa_numero']) ?? 0;
      final responsible = _value(sale['responsable'], 'SIN_USUARIO');
      final duration = _toDouble(sale['duracion_minutos']);
      for (final account in _mapList(sale['cuentas'])) {
        final products = _mapList(account['productos'])
            .map(_ProductLine.fromJson)
            .toList(growable: false);
        if (products.isEmpty) continue;
        result.add(
          _LiveAccountGroup(
            accountId: _toInt(account['cuenta_id']) ?? 0,
            accountNumber: _toInt(account['numero']) ?? 0,
            description: _value(account['descripcion'], ''),
            saleId: saleId,
            tableNumber: table,
            responsible: responsible,
            durationMinutes: duration,
            total: _toDouble(account['total']),
            paid: _toDouble(account['total_pagado']),
            balance: _toDouble(account['saldo_pendiente']),
            products: products,
          ),
        );
      }
    }
    result.sort((a, b) {
      final tableCompare = a.tableNumber.compareTo(b.tableNumber);
      return tableCompare != 0
          ? tableCompare
          : a.accountNumber.compareTo(b.accountNumber);
    });
    return result;
  }

  int get _days => _to.difference(_from).inDays + 1;

  String get _periodName {
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (_from == today && _to == today) return 'Hoy';
    if (_from == yesterday && _to == yesterday) return 'Ayer';
    if (_days == 7 && _to == today) return 'Últimos 7 días';
    if (_days == 30 && _to == today) return 'Últimos 30 días';
    if (_from == DateTime(today.year, today.month, 1) && _to == today) {
      return 'Este mes';
    }
    return 'Periodo personalizado';
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _DetailLineSummary {
  const _DetailLineSummary({
    required this.id,
    required this.accountId,
    required this.accountNumber,
    required this.accountDescription,
    required this.saleId,
    required this.tableNumber,
    required this.date,
    required this.saleStatus,
    required this.accountStatus,
    required this.responsible,
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.paid,
    required this.accountTotal,
    required this.accountPaid,
    required this.accountBalance,
    required this.paymentMethods,
    required this.durationMinutes,
  });

  final int id;
  final int accountId;
  final int accountNumber;
  final String accountDescription;
  final int saleId;
  final int tableNumber;
  final DateTime? date;
  final String saleStatus;
  final String accountStatus;
  final String responsible;
  final int productId;
  final String productName;
  final String productDescription;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool paid;
  final double accountTotal;
  final double accountPaid;
  final double accountBalance;
  final String paymentMethods;
  final double durationMinutes;

  factory _DetailLineSummary.fromJson(Map<String, dynamic> json) =>
      _DetailLineSummary(
        id: _toInt(json['detalle_id']) ?? 0,
        accountId: _toInt(json['cuenta_id']) ?? 0,
        accountNumber: _toInt(json['cuenta_numero']) ?? 0,
        accountDescription: _value(json['cuenta_descripcion'], ''),
        saleId: _toInt(json['venta_id']) ?? 0,
        tableNumber: _toInt(json['mesa_numero']) ?? 0,
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        saleStatus: _value(json['venta_estado'], 'SIN ESTADO'),
        accountStatus: _value(json['cuenta_estado'], 'SIN ESTADO'),
        responsible: _value(json['responsable'], 'SIN_USUARIO'),
        productId: _toInt(json['producto_id']) ?? 0,
        productName: _value(json['producto_nombre'], 'Producto'),
        productDescription: _value(json['producto_descripcion'], ''),
        quantity: _toDouble(json['cantidad']),
        unitPrice: _toDouble(json['valor_unitario']),
        subtotal: _toDouble(json['subtotal']),
        paid: _toBool(json['pagado']),
        accountTotal: _toDouble(json['total_cuenta']),
        accountPaid: _toDouble(json['total_pagado_cuenta']),
        accountBalance: _toDouble(json['saldo_cuenta']),
        paymentMethods: _value(json['medios_pago'], 'SIN PAGO'),
        durationMinutes: _toDouble(json['duracion_minutos']),
      );

  String get accountTitle => accountDescription.isEmpty
      ? 'Cuenta $accountNumber'
      : 'Cuenta $accountNumber · $accountDescription';

  String get searchText =>
      '$id $accountId $accountNumber $saleId $tableNumber '
      '$responsible $productId $productName $productDescription '
      '$paymentMethods $saleStatus $accountStatus'
          .toLowerCase();
}

class _LiveAccountGroup {
  const _LiveAccountGroup({
    required this.accountId,
    required this.accountNumber,
    required this.description,
    required this.saleId,
    required this.tableNumber,
    required this.responsible,
    required this.durationMinutes,
    required this.total,
    required this.paid,
    required this.balance,
    required this.products,
  });

  final int accountId;
  final int accountNumber;
  final String description;
  final int saleId;
  final int tableNumber;
  final String responsible;
  final double durationMinutes;
  final double total;
  final double paid;
  final double balance;
  final List<_ProductLine> products;

  double get units => products.fold<double>(
        0,
        (sum, product) => sum + product.quantity,
      );

  String get title => description.isEmpty
      ? 'Cuenta $accountNumber'
      : 'Cuenta $accountNumber · $description';
}

class _AccountDetail {
  const _AccountDetail({
    required this.accountId,
    required this.accountNumber,
    required this.description,
    required this.saleId,
    required this.tableNumber,
    required this.responsible,
    required this.saleStatus,
    required this.date,
    required this.durationMinutes,
    required this.total,
    required this.subtotal,
    required this.tip,
    required this.paid,
    required this.balance,
    required this.isPaid,
    required this.products,
    required this.payments,
  });

  final int accountId;
  final int accountNumber;
  final String description;
  final int saleId;
  final int tableNumber;
  final String responsible;
  final String saleStatus;
  final DateTime? date;
  final double durationMinutes;
  final double total;
  final double subtotal;
  final double tip;
  final double paid;
  final double balance;
  final bool isPaid;
  final List<_ProductLine> products;
  final List<_PaymentLine> payments;

  factory _AccountDetail.fromJson(Map<String, dynamic> json) => _AccountDetail(
        accountId: _toInt(json['cuenta_id']) ?? 0,
        accountNumber: _toInt(json['numero']) ?? 0,
        description: _value(json['descripcion'], ''),
        saleId: _toInt(json['venta_id']) ?? 0,
        tableNumber: _toInt(json['mesa_numero']) ?? 0,
        responsible: _value(json['responsable'], 'SIN_USUARIO'),
        saleStatus: _value(json['venta_estado'], 'SIN ESTADO'),
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        durationMinutes: _toDouble(json['duracion_minutos']),
        total: _toDouble(json['total']),
        subtotal: _toDouble(json['subtotal_productos']),
        tip: _toDouble(json['propina']),
        paid: _toDouble(json['total_pagado']),
        balance: _toDouble(json['saldo_pendiente']),
        isPaid: _toBool(json['pagada']),
        products: _mapList(json['productos'])
            .map(_ProductLine.fromJson)
            .toList(growable: false),
        payments: _mapList(json['pagos'])
            .map(_PaymentLine.fromJson)
            .toList(growable: false),
      );

  bool get isOpen {
    final normalized = saleStatus.trim().toUpperCase();
    return normalized.contains('ABIERT') ||
        normalized.contains('ACTIV') ||
        normalized.contains('PENDIENT');
  }

  String get title => description.isEmpty
      ? 'Cuenta $accountNumber'
      : 'Cuenta $accountNumber · $description';
}

class _ProductLine {
  const _ProductLine({
    required this.detailId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.paid,
  });

  final int detailId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final bool paid;

  factory _ProductLine.fromJson(Map<String, dynamic> json) => _ProductLine(
        detailId: _toInt(json['detalle_id']) ?? 0,
        name: _value(json['producto_nombre'], 'Producto'),
        quantity: _toDouble(json['cantidad']),
        unitPrice: _toDouble(json['valor_unitario']),
        subtotal: _toDouble(json['subtotal']),
        paid: _toBool(json['pagado']),
      );
}

class _PaymentLine {
  const _PaymentLine({
    required this.method,
    required this.value,
    required this.received,
    required this.change,
    required this.date,
    required this.responsible,
  });

  final String method;
  final double value;
  final double received;
  final double change;
  final DateTime? date;
  final String responsible;

  factory _PaymentLine.fromJson(Map<String, dynamic> json) => _PaymentLine(
        method: _value(json['medio_pago_nombre'], 'Medio de pago'),
        value: _toDouble(json['valor']),
        received: _toDouble(json['valor_recibido']),
        change: _toDouble(json['cambio']),
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        responsible: _value(json['responsable'], 'SIN_USUARIO'),
      );
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data, required this.palette});

  final _KpiData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: data.tint,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: data.tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.tint, size: 19),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: AppColors.success, size: 7),
          SizedBox(width: 4),
          Text(
            'EN VIVO',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAccountCard extends StatelessWidget {
  const _LiveAccountCard({
    required this.group,
    required this.palette,
    this.onTap,
  });

  final _LiveAccountGroup group;
  final AppPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final preview = group.products.take(4).toList(growable: false);
    final ratio = group.total <= 0
        ? 0.0
        : (group.paid / group.total).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(
              palette.darkBackground ? 0.40 : 0.65,
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: palette.cardBorder.withOpacity(0.72)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.table_restaurant_rounded,
                      color: palette.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mesa ${group.tableNumber} · ${group.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Venta #${group.saleId} · ${group.responsible}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _durationLabel(group.durationMinutes),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final product in preview)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: product.paid
                              ? AppColors.success
                              : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${_formatQuantity(product.quantity)} × ${product.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyUtils.format(product.subtotal),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (group.products.length > preview.length)
                Text(
                  '+${group.products.length - preview.length} productos más',
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: palette.cardBorder.withOpacity(0.45),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _MiniAmount(
                      label: 'Unidades',
                      textValue: _formatQuantity(group.units),
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: _MiniAmount(
                      label: 'Total',
                      textValue: CurrencyUtils.format(group.total),
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: _MiniAmount(
                      label: 'Saldo',
                      textValue: CurrencyUtils.format(group.balance),
                      palette: palette,
                      tint: group.balance > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.textValue,
    required this.palette,
    this.tint,
  });

  final String label;
  final String textValue;
  final AppPalette palette;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          textValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tint ?? palette.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PaymentFilterChip extends StatelessWidget {
  const _PaymentFilterChip({
    required this.value,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = value == 'PAGADO'
        ? AppColors.success
        : value == 'PENDIENTE'
            ? AppColors.warning
            : palette.secondary;
    return ChoiceChip(
      label: Text(_paymentStatusLabel(value)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.18),
      backgroundColor: palette.background.withOpacity(
        palette.darkBackground ? 0.36 : 0.58,
      ),
      side: BorderSide(
        color: selected ? color.withOpacity(0.55) : palette.cardBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? color : palette.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DetailLinesTable extends StatelessWidget {
  const _DetailLinesTable({
    required this.items,
    required this.palette,
    this.onOpen,
  });

  final List<_DetailLineSummary> items;
  final AppPalette palette;
  final ValueChanged<_DetailLineSummary>? onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 54,
        dataRowMaxHeight: 66,
        columnSpacing: 19,
        headingTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        dataTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Mesa / cuenta')),
          DataColumn(label: Text('Producto')),
          DataColumn(label: Text('Cantidad'), numeric: true),
          DataColumn(label: Text('Valor unitario'), numeric: true),
          DataColumn(label: Text('Subtotal'), numeric: true),
          DataColumn(label: Text('Pago')),
          DataColumn(label: Text('Responsable')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              onSelectChanged:
                  onOpen == null ? null : (_) => onOpen!(item),
              cells: [
                DataCell(Text(_formatDateTime(item.date))),
                DataCell(
                  SizedBox(
                    width: 145,
                    child: Text(
                      'Mesa ${item.tableNumber} · ${item.accountTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(_formatQuantity(item.quantity))),
                DataCell(Text(CurrencyUtils.format(item.unitPrice))),
                DataCell(
                  Text(
                    CurrencyUtils.format(item.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                DataCell(_PaidBadge(paid: item.paid, palette: palette)),
                DataCell(
                  SizedBox(
                    width: 115,
                    child: Text(
                      item.responsible,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Ver cuenta completa',
                    onPressed: onOpen == null ? null : () => onOpen!(item),
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

class _DetailLineCard extends StatelessWidget {
  const _DetailLineCard({
    required this.line,
    required this.palette,
    this.onTap,
  });

  final _DetailLineSummary line;
  final AppPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.38 : 0.62,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder.withOpacity(0.70)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _PaidBadge(paid: line.paid, palette: palette),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mesa ${line.tableNumber} · ${line.accountTitle} · '
                  'Venta #${line.saleId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _SmallInfo(
                        label: 'Cantidad',
                        value: _formatQuantity(line.quantity),
                        palette: palette,
                      ),
                    ),
                    Expanded(
                      child: _SmallInfo(
                        label: 'Unitario',
                        value: CurrencyUtils.format(line.unitPrice),
                        palette: palette,
                      ),
                    ),
                    Expanded(
                      child: _SmallInfo(
                        label: 'Subtotal',
                        value: CurrencyUtils.format(line.subtotal),
                        palette: palette,
                        tint: palette.secondary,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                Divider(
                  height: 16,
                  color: palette.cardBorder.withOpacity(0.65),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_formatDateTime(line.date)} · ${line.responsible}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _durationLabel(line.durationMinutes),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({
    required this.label,
    required this.value,
    required this.palette,
    this.tint,
  });

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
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint ?? palette.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.paid, required this.palette});

  final bool paid;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        paid ? 'PAGADO' : 'PENDIENTE',
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AccountDetailSheet extends ConsumerStatefulWidget {
  const _AccountDetailSheet({
    required this.accountId,
    required this.branchId,
    this.highlightedDetailId,
  });

  final int accountId;
  final int branchId;
  final int? highlightedDetailId;

  @override
  ConsumerState<_AccountDetailSheet> createState() =>
      _AccountDetailSheetState();
}

class _AccountDetailSheetState extends ConsumerState<_AccountDetailSheet> {
  _AccountDetail? _detail;
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
      if (mounted && (_detail?.isOpen ?? true)) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (!silent && _detail == null) _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '${ApiPaths.reportes}/cuentas-venta/'
            '${widget.accountId}/detalle-operativo',
            _parseMap,
            queryParameters: {'sucursalId': widget.branchId},
          );
      if (!mounted) return;
      final detail =
          _AccountDetail.fromJson(response.data ?? const <String, dynamic>{});
      setState(() {
        _detail = detail;
        _loading = false;
        _refreshing = false;
        _updatedAt = DateTime.now();
      });
      if (!detail.isOpen) _timer?.cancel();
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
      initialChildSize: 0.91,
      minChildSize: 0.58,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
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
              _buildHeader(palette),
              if (_refreshing && _detail != null)
                const LinearProgressIndicator(minHeight: 2),
              Divider(height: 1, color: palette.cardBorder),
              Expanded(child: _buildBody(palette, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppPalette palette) {
    final detail = _detail;
    final updated = _updatedAt == null
        ? ''
        : ' · ${DateFormat('HH:mm:ss').format(_updatedAt!)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 10, 11),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.receipt_long_rounded, color: palette.secondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail == null
                      ? 'Detalle de la cuenta'
                      : '${detail.title} · Mesa ${detail.tableNumber}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail == null
                      ? 'Consultando información...'
                      : 'Venta #${detail.saleId} · '
                          '${detail.responsible}$updated',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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

  Widget _buildBody(AppPalette palette, ScrollController controller) {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          _InlineWarning(message: _error!, palette: palette),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        if (_error != null) ...[
          _InlineWarning(message: _error!, palette: palette),
          const SizedBox(height: 10),
        ],
        _DetailOverview(detail: detail, palette: palette),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Productos de la cuenta',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${detail.products.length} productos',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detail.products.isEmpty)
          _EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin productos',
            message: 'La cuenta todavía no tiene productos registrados.',
            palette: palette,
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: palette.panelDecoration(
              baseRadius: 18,
              tint: palette.secondary,
              elevated: false,
            ),
            child: Column(
              children: [
                for (var index = 0;
                    index < detail.products.length;
                    index++) ...[
                  _ProductRow(
                    product: detail.products[index],
                    palette: palette,
                    highlighted: detail.products[index].detailId ==
                        widget.highlightedDetailId,
                  ),
                  if (index + 1 < detail.products.length)
                    Divider(
                      height: 15,
                      color: palette.cardBorder.withOpacity(0.65),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pagos registrados',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${detail.payments.length} pagos',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detail.payments.isEmpty)
          _EmptyState(
            icon: Icons.payments_outlined,
            title: 'Sin pagos',
            message: 'La cuenta aún no tiene pagos registrados.',
            palette: palette,
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: palette.panelDecoration(
              baseRadius: 18,
              tint: AppColors.success,
              elevated: false,
            ),
            child: Column(
              children: [
                for (var index = 0;
                    index < detail.payments.length;
                    index++) ...[
                  _PaymentRow(
                    payment: detail.payments[index],
                    palette: palette,
                  ),
                  if (index + 1 < detail.payments.length)
                    Divider(
                      height: 15,
                      color: palette.cardBorder.withOpacity(0.65),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailOverview extends StatelessWidget {
  const _DetailOverview({required this.detail, required this.palette});

  final _AccountDetail detail;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final status = detail.isPaid
        ? 'PAGADA'
        : detail.isOpen
            ? 'PENDIENTE'
            : 'CERRADA';
    final color = detail.isPaid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: color,
        elevated: false,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTime(detail.date),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _durationLabel(detail.durationMinutes),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _OverviewValue(
                  label: 'Productos',
                  value: CurrencyUtils.format(detail.subtotal),
                  tint: palette.secondary,
                ),
                _OverviewValue(
                  label: 'Propina',
                  value: CurrencyUtils.format(detail.tip),
                ),
                _OverviewValue(
                  label: 'Total',
                  value: CurrencyUtils.format(detail.total),
                ),
                _OverviewValue(
                  label: 'Pagado',
                  value: CurrencyUtils.format(detail.paid),
                  tint: AppColors.success,
                ),
                _OverviewValue(
                  label: 'Saldo',
                  value: CurrencyUtils.format(detail.balance),
                  tint: detail.balance > 0
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ];
              final columns = constraints.maxWidth < 520 ? 2 : 5;
              const spacing = 8.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in values)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: item.tint ?? palette.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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

class _OverviewValue {
  const _OverviewValue({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.palette,
    required this.highlighted,
  });

  final _ProductLine product;
  final AppPalette palette;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.all(highlighted ? 10 : 0),
      decoration: highlighted
          ? BoxDecoration(
              color: palette.secondary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.secondary.withOpacity(0.45)),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: product.paid
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              product.paid
                  ? Icons.check_circle_outline_rounded
                  : Icons.pending_actions_rounded,
              color: product.paid ? AppColors.success : AppColors.warning,
              size: 20,
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
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (highlighted)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'SELECCIONADO',
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatQuantity(product.quantity)} × '
                  '${CurrencyUtils.format(product.unitPrice)}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.format(product.subtotal),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                product.paid ? 'Pagado' : 'Pendiente',
                style: TextStyle(
                  color:
                      product.paid ? AppColors.success : AppColors.warning,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.palette});

  final _PaymentLine payment;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.payments_rounded,
            color: AppColors.success,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.method,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_formatDateTime(payment.date)} · ${payment.responsible}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyUtils.format(payment.value),
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (payment.change > 0)
              Text(
                'Cambio ${CurrencyUtils.format(payment.change)}',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PeriodPickerSheet extends StatefulWidget {
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
  State<_PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<_PeriodPickerSheet> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ProviderScope.containerOf(context)
        .read(selectedAppPaletteProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.48,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
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
                padding: const EdgeInsets.fromLTRB(18, 13, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.date_range_rounded,
                        color: palette.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Periodo del detalle',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Selecciona un rango rápido o fechas personalizadas.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.cardBorder),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetButton(
                          label: 'Hoy',
                          icon: Icons.today_rounded,
                          palette: palette,
                          onTap: () => _preset(0, 0),
                        ),
                        _PresetButton(
                          label: 'Ayer',
                          icon: Icons.history_rounded,
                          palette: palette,
                          onTap: () => _preset(1, 1),
                        ),
                        _PresetButton(
                          label: 'Últimos 7 días',
                          icon: Icons.view_week_rounded,
                          palette: palette,
                          onTap: () => _preset(6, 0),
                        ),
                        _PresetButton(
                          label: 'Últimos 30 días',
                          icon: Icons.calendar_view_month_rounded,
                          palette: palette,
                          onTap: () => _preset(29, 0),
                        ),
                        _PresetButton(
                          label: 'Este mes',
                          icon: Icons.calendar_month_rounded,
                          palette: palette,
                          onTap: _thisMonth,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final start = _DateBox(
                          label: 'Desde',
                          date: _start,
                          palette: palette,
                          onTap: () => _pick(true),
                        );
                        final end = _DateBox(
                          label: 'Hasta',
                          date: _end,
                          palette: palette,
                          onTap: () => _pick(false),
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: [
                              start,
                              const SizedBox(height: 8),
                              end,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: start),
                            const SizedBox(width: 9),
                            Expanded(child: end),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.background.withOpacity(
                          palette.darkBackground ? 0.42 : 0.66,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: palette.secondary,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_end.difference(_start).inDays + 1} días '
                              'seleccionados · '
                              '${DateFormat('dd/MM/yyyy').format(_start)} al '
                              '${DateFormat('dd/MM/yyyy').format(_end)}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        DateTimeRange(start: _start, end: _end),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Aplicar periodo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.actionColor,
                        foregroundColor: palette.onAction,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _preset(int startDaysAgo, int endDaysAgo) {
    final today =
        DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    setState(() {
      _start = today.subtract(Duration(days: startDaysAgo));
      _end = today.subtract(Duration(days: endDaysAgo));
    });
  }

  void _thisMonth() {
    final today =
        DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    setState(() {
      _start = DateTime(today.year, today.month, 1);
      _end = today;
    });
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final result = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (result == null) return;
    setState(() {
      if (start) {
        _start = result;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = result;
        if (_start.isAfter(_end)) _start = _end;
      }
    });
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.cardBorder),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.date,
    required this.palette,
    required this.onTap,
  });

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
          color: palette.background.withOpacity(
            palette.darkBackground ? 0.42 : 0.66,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, color: palette.secondary, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.textPrimary,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.34 : 0.58,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder.withOpacity(0.70)),
      ),
      child: Column(
        children: [
          Icon(icon, color: palette.textSecondary, size: 32),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _parseMap(Object? json) =>
    json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

List<Map<String, dynamic>> _parseMapList(Object? json) =>
    (json as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

List<Map<String, dynamic>> _mapList(Object? value) =>
    (value as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

String _value(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Sin fecha';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return NumberFormat('0.##', 'es_CO').format(value);
}

String _durationLabel(double minutes) {
  final total = minutes.round().clamp(0, 999999);
  if (total < 60) return '$total min';
  final hours = total ~/ 60;
  final remainder = total % 60;
  return remainder == 0 ? '$hours h' : '$hours h $remainder min';
}

String _paymentStatusLabel(String value) {
  switch (value) {
    case 'TODOS':
      return 'Todos';
    case 'PENDIENTE':
      return 'Pendientes';
    case 'PAGADO':
      return 'Pagados';
    default:
      return value;
  }
}
