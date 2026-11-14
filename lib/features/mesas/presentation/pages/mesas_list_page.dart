import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../mesero/domain/mesas_permission_policy.dart';

/// Centro de control de mesas para GERENTE.
///
/// Combina el catálogo completo de mesas con ventas abiertas y actividad del día.
/// La información operativa se actualiza automáticamente sin cambiar de pantalla.
class MesasListPage extends ConsumerStatefulWidget {
  const MesasListPage({super.key});

  @override
  ConsumerState<MesasListPage> createState() => _MesasListPageState();
}

class _MesasListPageState extends ConsumerState<MesasListPage> {
  static const _refreshInterval = Duration(seconds: 5);
  static const _pageSize = 18;

  bool _canChangeTableState() {
    final keys = ref.read(userMenuProvider).maybeWhen(
      data: (items) => items.map((item) => item.keyName).toSet(),
      orElse: () => const <String>{},
    );
    final privilegedRole = ref.read(activeRolesProvider).any((role) {
      final name = role.trim().toUpperCase().replaceFirst(
        RegExp(r'^ROLE_'), '',
      );
      return const <String>{
        'GERENTE', 'MANAGER', 'SUPERVISOR', 'CAJERO', 'CAJERA',
        'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN',
      }.contains(name);
    });
    return MesasPermissionPolicy.canDeleteOrChangeState(
      menuKeys: keys, isCashier: privilegedRole,
    );
  }

  final _searchController = TextEditingController();
  Timer? _timer;
  bool _loading = true;
  bool _liveLoading = false;
  bool _autoRefresh = true;
  String? _error;
  DateTime? _updatedAt;
  int? _loadedBranchId;
  int _page = 0;
  _TableFilter _filter = _TableFilter.all;
  _TableSort _sort = _TableSort.number;
  List<_ManagerTable> _tables = const [];

  @override
  void initState() {
    super.initState();
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
    ref.watch(userMenuProvider);
    ref.watch(activeRolesProvider);

    ref.listen<int?>(
      branchScopeProvider.select((state) => state.activeBranchId),
      (previous, next) {
        if (previous == next || next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => _load(force: true));
      },
    );

    if (_loading && _tables.isEmpty) {
      return const AppLoader(message: 'Preparando el control de mesas...');
    }
    if (_error != null && _tables.isEmpty) {
      return AppErrorView(message: _error!, onRetry: () => _load(force: true));
    }

    final filtered = _filteredTables();
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
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(palette, branchState.activeBranch?.sucuNombre),
                        if (_loading || _liveLoading) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: const LinearProgressIndicator(minHeight: 3),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _InlineMessage(message: _error!, palette: palette, warning: true),
                        ],
                        const SizedBox(height: 12),
                        _buildKpis(palette),
                        const SizedBox(height: 12),
                        _buildAlerts(palette),
                        const SizedBox(height: 12),
                        _buildFilters(palette),
                        const SizedBox(height: 12),
                        if (pageItems.isEmpty)
                          _buildEmpty(palette)
                        else
                          _buildTableGrid(pageItems, palette),
                        if (pageItems.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildPagination(pageCount, filtered.length, palette),
                        ],
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
    final updated = _updatedAt == null ? 'Sin sincronizar' : DateFormat('HH:mm:ss').format(_updatedAt!);
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.table_bar_rounded, color: palette.secondary, size: 29),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control de mesas',
                      style: TextStyle(color: palette.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      branchName ?? 'Sucursal activa',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ocupación, consumo, pagos, responsables y tiempos de atención en una sola vista.',
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
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(palette.darkBackground ? 0.46 : 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _autoRefresh ? palette.success : palette.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _autoRefresh ? 'En vivo · $updated' : 'Pausado · $updated',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: _autoRefresh ? 'Pausar actualización automática' : 'Reanudar actualización automática',
                onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
                icon: Icon(_autoRefresh ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              IconButton.outlined(
                tooltip: 'Actualizar ahora',
                onPressed: _liveLoading ? null : () => _load(force: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: _openCreateSheet,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva mesa'),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: title), const SizedBox(width: 16), actions],
          );
        },
      ),
    );
  }

  Widget _buildKpis(AppPalette palette) {
    final occupied = _tables.where((table) => table.isOccupied).length;
    final inactive = _tables.where((table) => table.isInactive).length;
    final available = _tables.length - occupied - inactive;
    final consumption = _tables.fold<double>(0, (sum, table) => sum + table.live.total);
    final pending = _tables.fold<double>(0, (sum, table) => sum + table.live.balance);
    final todaySales = _tables.fold<int>(0, (sum, table) => sum + table.today.saleCount);
    final todayRevenue = _tables.fold<double>(0, (sum, table) => sum + table.today.total);

    final items = <_KpiData>[
      _KpiData('Mesas', '${_tables.length}', Icons.table_restaurant_rounded, palette.secondary, _TableFilter.all),
      _KpiData('Ocupadas', '$occupied', Icons.people_alt_rounded, palette.warning, _TableFilter.occupied),
      _KpiData('Disponibles', '$available', Icons.event_available_rounded, palette.success, _TableFilter.available),
      _KpiData('Inactivas', '$inactive', Icons.block_rounded, palette.textSecondary, _TableFilter.inactive),
      _KpiData('Consumo abierto', CurrencyUtils.format(consumption), Icons.receipt_long_rounded, palette.accent, null),
      _KpiData('Saldo abierto', CurrencyUtils.format(pending), Icons.account_balance_wallet_outlined, palette.warning, null),
      _KpiData('Ventas de hoy', '$todaySales', Icons.point_of_sale_rounded, palette.secondary, null),
      _KpiData('Facturado hoy', CurrencyUtils.format(todayRevenue), Icons.trending_up_rounded, palette.success, null),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width < 600
            ? (width - 10) / 2
            : width < 1050
                ? (width - 20) / 3
                : (width - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _KpiCard(
                  data: item,
                  palette: palette,
                  selected: item.filter != null && _filter == item.filter,
                  onTap: item.filter == null
                      ? null
                      : () => setState(() {
                            _filter = item.filter!;
                            _page = 0;
                          }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAlerts(AppPalette palette) {
    final delayed = _tables.where((table) => table.isOccupied && table.live.durationMinutes >= 90).toList();
    final highBalance = _tables.where((table) => table.isOccupied && table.live.balance >= 100000).toList();
    final withoutProducts = _tables.where((table) => table.isOccupied && table.live.productUnits <= 0).toList();
    if (delayed.isEmpty && highBalance.isEmpty && withoutProducts.isEmpty) {
      return _InlineMessage(
        message: 'Operación estable: no hay mesas con alertas críticas en este momento.',
        palette: palette,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.warning, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final alerts = <Widget>[];
          if (delayed.isNotEmpty) {
            alerts.add(_AlertChip(
              icon: Icons.schedule_rounded,
              label: '${delayed.length} mesa${delayed.length == 1 ? '' : 's'} con más de 90 min',
              palette: palette,
              onTap: () => _focusTables(delayed),
            ));
          }
          if (highBalance.isNotEmpty) {
            alerts.add(_AlertChip(
              icon: Icons.payments_outlined,
              label: '${highBalance.length} saldo${highBalance.length == 1 ? '' : 's'} superior${highBalance.length == 1 ? '' : 'es'} a ${CurrencyUtils.format(100000)}',
              palette: palette,
              onTap: () => _focusTables(highBalance),
            ));
          }
          if (withoutProducts.isNotEmpty) {
            alerts.add(_AlertChip(
              icon: Icons.report_problem_outlined,
              label: '${withoutProducts.length} venta${withoutProducts.length == 1 ? '' : 's'} abierta${withoutProducts.length == 1 ? '' : 's'} sin productos',
              palette: palette,
              onTap: () => _focusTables(withoutProducts),
            ));
          }
          return Wrap(spacing: 8, runSpacing: 8, children: alerts);
        },
      ),
    );
  }

  Widget _buildFilters(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _searchController,
            onChanged: (_) => setState(() {
              _page = 0;
            }),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar mesa, responsable o descripción',
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
            ),
          );

          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactDropdown<_TableFilter>(
                value: _filter,
                label: 'Estado',
                icon: Icons.filter_alt_outlined,
                items: _TableFilter.values,
                text: (value) => value.label,
                onChanged: (value) => setState(() {
                  _filter = value;
                  _page = 0;
                }),
              ),
              _CompactDropdown<_TableSort>(
                value: _sort,
                label: 'Ordenar',
                icon: Icons.sort_rounded,
                items: _TableSort.values,
                text: (value) => value.label,
                onChanged: (value) => setState(() {
                  _sort = value;
                  _page = 0;
                }),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 10), controls],
            );
          }
          return Row(
            children: [Expanded(child: search), const SizedBox(width: 10), controls],
          );
        },
      ),
    );
  }

  Widget _buildTableGrid(List<_ManagerTable> items, AppPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 650
            ? width
            : width < 1050
                ? (width - 12) / 2
                : width < 1400
                    ? (width - 24) / 3
                    : (width - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final table in items)
              SizedBox(
                width: cardWidth,
                child: _ManagerTableCard(
                  table: table,
                  palette: palette,
                  onOpen: () => _openTableDetail(table),
                  onEdit: () => _openEditSheet(table),
                  onDeactivate: table.isInactive || !_canChangeTableState()
                      ? null : () => _deactivateTable(table),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPagination(int pageCount, int total, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: palette.panelDecoration(baseRadius: 18, tint: palette.secondary, elevated: false),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$total mesa${total == 1 ? '' : 's'} · Página ${_page + 1} de $pageCount',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
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
    );
  }

  Widget _buildEmpty(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      decoration: palette.panelDecoration(baseRadius: 24, tint: palette.secondary, elevated: false),
      child: Column(
        children: [
          Icon(Icons.table_restaurant_outlined, size: 54, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text('No hay mesas para mostrar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 5),
          Text('Cambia el filtro, limpia la búsqueda o crea una nueva mesa.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _load({bool force = false}) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Selecciona una sucursal para consultar sus mesas.';
      });
      return;
    }
    if (!force && _loadedBranchId == branchId && _tables.isNotEmpty) return;

    if (mounted) {
      setState(() {
        _loading = _tables.isEmpty;
        _liveLoading = _tables.isNotEmpty;
        _error = null;
      });
    }

    final api = ref.read(apiClientProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Los reportes son información complementaria. Un rol personalizado
    // puede tener Mesas sin tener Reportes; un 403 en los KPI no debe impedir
    // listar las mesas ni abrir el formulario para crearlas o editarlas.
    Future<List<Map<String, dynamic>>> optionalReport(
      String url, Map<String, dynamic> query,
    ) async {
      try {
        final response = await api.get<List<Map<String, dynamic>>>(
          url, _parseMapList, queryParameters: query,
        );
        return response.data ?? const <Map<String, dynamic>>[];
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }

    final liveFuture = optionalReport(
      '${ApiPaths.reportes}/ventas/tiempo-real', {'sucursalId': branchId},
    );
    final historyFuture = optionalReport(
      '${ApiPaths.reportes}/ventas/detalle',
      {'inicio': today, 'fin': today, 'sucursalId': branchId, 'limite': 500},
    );
    try {
      // La consulta principal sí es obligatoria y conserva sus errores.
      final response = await api.get<List<Map<String, dynamic>>>(
        '${ApiPaths.mesas}/sucursal/$branchId', _parseMapList,
      );
      final rawTables = response.data ?? const <Map<String, dynamic>>[];
      final rawLive = await liveFuture;
      final rawHistory = await historyFuture;
      if (!mounted) return;
      final liveByTable = <int, _LiveTableSale>{};
      for (final row in rawLive) {
        final live = _LiveTableSale.fromJson(row);
        if (live.tableId != null) liveByTable[live.tableId!] = live;
      }
      final todayByTable = <int, _TodayTableStats>{};
      for (final row in rawHistory) {
        final tableId = _toInt(row['mesa_id'] ?? row['mesaId']);
        if (tableId == null) continue;
        final current = todayByTable[tableId] ?? const _TodayTableStats();
        todayByTable[tableId] = current.addSale(row);
      }

      final tables = rawTables
          .map((row) => _ManagerTable.fromJson(
                row,
                live: liveByTable[_toInt(row['mesaId'])],
                today: todayByTable[_toInt(row['mesaId'])],
              ))
          .toList(growable: false)
        ..sort((a, b) => a.number.compareTo(b.number));

      setState(() {
        _tables = tables;
        _loadedBranchId = branchId;
        _updatedAt = DateTime.now();
        _loading = false;
        _liveLoading = false;
        _error = null;
        _page = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _liveLoading = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }

  Future<void> _refreshLive() async {
    if (_liveLoading || !mounted) return;
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return;
    setState(() => _liveLoading = true);
    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
            '${ApiPaths.reportes}/ventas/tiempo-real',
            _parseMapList,
            queryParameters: {'sucursalId': branchId},
          );
      if (!mounted) return;
      final liveByTable = <int, _LiveTableSale>{};
      for (final row in response.data ?? const <Map<String, dynamic>>[]) {
        final live = _LiveTableSale.fromJson(row);
        if (live.tableId != null) liveByTable[live.tableId!] = live;
      }
      setState(() {
        _tables = _tables
            .map((table) => table.copyWith(live: liveByTable[table.id] ?? const _LiveTableSale()))
            .toList(growable: false);
        _updatedAt = DateTime.now();
        _liveLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liveLoading = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (_autoRefresh && mounted) _refreshLive();
    });
  }

  List<_ManagerTable> _filteredTables() {
    final query = _normalize(_searchController.text);
    final filtered = _tables.where((table) {
      final matchesState = switch (_filter) {
        _TableFilter.all => true,
        _TableFilter.occupied => table.isOccupied,
        _TableFilter.available => table.isAvailable,
        _TableFilter.inactive => table.isInactive,
        _TableFilter.alerts => table.hasAlert,
      };
      if (!matchesState) return false;
      if (query.isEmpty) return true;
      return _normalize([
        table.number,
        table.description,
        table.state,
        table.live.responsible,
        table.live.saleId,
      ].join(' ')).contains(query);
    }).toList(growable: false);

    filtered.sort((a, b) {
      switch (_sort) {
        case _TableSort.number:
          return a.number.compareTo(b.number);
        case _TableSort.consumption:
          return b.live.total.compareTo(a.live.total);
        case _TableSort.balance:
          return b.live.balance.compareTo(a.live.balance);
        case _TableSort.duration:
          return b.live.durationMinutes.compareTo(a.live.durationMinutes);
        case _TableSort.today:
          return b.today.total.compareTo(a.today.total);
      }
    });
    return filtered;
  }

  void _focusTables(List<_ManagerTable> tables) {
    if (tables.isEmpty) return;
    setState(() {
      _filter = _TableFilter.alerts;
      _searchController.clear();
      _page = 0;
    });
  }

  Future<void> _openTableDetail(_ManagerTable table) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.60),
      builder: (sheetContext) => _TableDetailSheet(
        table: table,
        branchId: branchId,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          Future<void>.delayed(const Duration(milliseconds: 150), () => _openEditSheet(table));
        },
      ),
    );
    if (mounted) await _refreshLive();
  }

  Future<void> _openCreateSheet() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null || !mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (_) => _TableFormSheet(
        branchId: branchId, canChangeState: _canChangeTableState()),
    );
    if (saved == true && mounted) {
      _showSuccess('Mesa creada correctamente.');
      await _load(force: true);
    }
  }

  Future<void> _openEditSheet(_ManagerTable table) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null || !mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (_) => _TableFormSheet(
        branchId: branchId, table: table,
        canChangeState: _canChangeTableState()),
    );
    if (saved == true && mounted) {
      _showSuccess('Mesa actualizada correctamente.');
      await _load(force: true);
    }
  }

  Future<void> _deactivateTable(_ManagerTable table) async {
    if (!_canChangeTableState()) {
      _showError('Tu rol no permite inactivar mesas.');
      return;
    }
    if (table.isOccupied) {
      _showError('No se puede inactivar una mesa con una venta abierta.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('Inactivar mesa ${table.number}'),
        content: const Text(
          'Si tiene histórico, la mesa se conservará como inactiva. Si nunca se ha utilizado, el backend puede eliminarla definitivamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continuar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete<Object?>(
            '${ApiPaths.mesas}/${table.id}',
            (json) => json,
          );
      if (!mounted) return;
      _showSuccess('La mesa fue eliminada o marcada como inactiva.');
      await _load(force: true);
    } catch (error) {
      if (!mounted) return;
      _showError(ErrorMapper.map(error).message);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ManagerTableCard extends StatelessWidget {
  const _ManagerTableCard({
    required this.table,
    required this.palette,
    required this.onOpen,
    required this.onEdit,
    this.onDeactivate,
  });

  final _ManagerTable table;
  final AppPalette palette;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final statusColor = table.isInactive
        ? palette.textSecondary
        : table.isOccupied
            ? palette.warning
            : palette.success;
    final progress = table.live.total <= 0 ? 0.0 : (table.live.paid / table.live.total).clamp(0, 1).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(palette.radius(24)),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: palette.panelDecoration(baseRadius: 24, tint: statusColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TablePhoto(value: table.photo, size: 58, palette: palette),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Mesa ${table.number}',
                                style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                            _StatusPill(label: table.statusLabel, color: statusColor, palette: palette),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          table.description.isEmpty ? 'Sin descripción' : table.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones de mesa',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'deactivate') onDeactivate?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modificar'), dense: true)),
                      if (onDeactivate != null)
                        const PopupMenuItem(value: 'deactivate', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Inactivar'), dense: true)),
                    ],
                    icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (table.isOccupied) ...[
                Row(
                  children: [
                    Expanded(child: _MiniInfo(icon: Icons.person_outline_rounded, value: table.live.responsible, palette: palette)),
                    const SizedBox(width: 8),
                    _MiniInfo(icon: Icons.schedule_rounded, value: _durationLabel(table.live.durationMinutes), palette: palette),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _AmountLine(label: 'Consumo', value: table.live.total, palette: palette)),
                    Expanded(child: _AmountLine(label: 'Pagado', value: table.live.paid, palette: palette, alignEnd: true)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Saldo', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    Text(
                      CurrencyUtils.format(table.live.balance),
                      style: TextStyle(color: table.live.balance > 0 ? palette.warning : palette.success, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: palette.background.withOpacity(0.54),
                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1 ? palette.success : palette.secondary),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SmallChip(icon: Icons.receipt_long_outlined, label: '${table.live.accountCount} cuenta${table.live.accountCount == 1 ? '' : 's'}', palette: palette),
                    _SmallChip(icon: Icons.local_bar_outlined, label: '${_numberLabel(table.live.productUnits)} unidades', palette: palette),
                    if (table.hasAlert) _SmallChip(icon: Icons.warning_amber_rounded, label: 'Requiere atención', palette: palette, warning: true),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(table.isInactive ? Icons.block_rounded : Icons.event_available_rounded, color: statusColor),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          table.isInactive ? 'Mesa fuera de operación' : 'Disponible para una nueva atención',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 11),
              Divider(height: 1, color: palette.cardBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TodayIndicator(
                      label: 'Ventas hoy',
                      value: '${table.today.saleCount}',
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: _TodayIndicator(
                      label: 'Facturado hoy',
                      value: CurrencyUtils.format(table.today.total),
                      palette: palette,
                      alignEnd: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: palette.secondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableDetailSheet extends ConsumerStatefulWidget {
  const _TableDetailSheet({
    required this.table,
    required this.branchId,
    required this.onEdit,
  });

  final _ManagerTable table;
  final int branchId;
  final VoidCallback onEdit;

  @override
  ConsumerState<_TableDetailSheet> createState() => _TableDetailSheetState();
}

class _TableDetailSheetState extends ConsumerState<_TableDetailSheet> {
  Timer? _timer;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    if (widget.table.live.saleId != null) {
      _load();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92;
    final live = _detail == null ? widget.table.live : _LiveTableSale.fromJson(_detail!);
    final accounts = _mapList(_detail?['cuentas']);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: 1040, maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.34), blurRadius: 34, offset: const Offset(0, -12))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: palette.textSecondary.withOpacity(0.35), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
                child: Row(
                  children: [
                    _TablePhoto(value: widget.table.photo, size: 52, palette: palette),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mesa ${widget.table.number}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 3),
                          Text(
                            widget.table.description.isEmpty ? 'Detalle operativo de la mesa' : widget.table.description,
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(tooltip: 'Modificar mesa', onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined)),
                    const SizedBox(width: 6),
                    IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _InlineMessage(message: _error!, palette: palette, warning: true),
                        const SizedBox(height: 10),
                      ],
                      if (widget.table.isOccupied || _detail != null) ...[
                        _LiveSummary(live: live, palette: palette),
                        const SizedBox(height: 12),
                        _SectionTitle(icon: Icons.receipt_long_outlined, title: 'Cuentas y pedidos', subtitle: '${accounts.length} cuenta${accounts.length == 1 ? '' : 's'}', palette: palette),
                        const SizedBox(height: 9),
                        if (accounts.isEmpty)
                          _InlineMessage(message: 'La venta está abierta, pero todavía no tiene cuentas o productos visibles.', palette: palette, warning: true)
                        else
                          for (final account in accounts) ...[
                            _AccountPanel(account: account, palette: palette),
                            const SizedBox(height: 9),
                          ],
                      ] else ...[
                        _AvailableTablePanel(table: widget.table, palette: palette),
                      ],
                      const SizedBox(height: 12),
                      _SectionTitle(icon: Icons.today_outlined, title: 'Actividad de hoy', subtitle: 'Resumen de esta mesa', palette: palette),
                      const SizedBox(height: 9),
                      _TodayStatsPanel(stats: widget.table.today, palette: palette),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load({bool silent = false}) async {
    final saleId = widget.table.live.saleId;
    if (saleId == null || _loading) return;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '${ApiPaths.reportes}/ventas/$saleId/detalle-operativo',
            _parseMap,
            queryParameters: {'sucursalId': widget.branchId},
          );
      if (!mounted) return;
      setState(() {
        _detail = response.data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }
}

class _TableFormSheet extends ConsumerStatefulWidget {
  const _TableFormSheet({
    required this.branchId,
    required this.canChangeState,
    this.table,
  });

  final int branchId;
  final bool canChangeState;
  final _ManagerTable? table;

  @override
  ConsumerState<_TableFormSheet> createState() => _TableFormSheetState();
}

class _TableFormSheetState extends ConsumerState<_TableFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _descriptionController;
  late String _photo;
  late String _state;
  bool _saving = false;
  bool _photoChanged = false;

  bool get _editing => widget.table != null;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.table?.number.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.table?.description ?? '');
    _photo = widget.table?.photo ?? '';
    _state = widget.table?.state.toUpperCase() ?? 'DISPONIBLE';
  }

  @override
  void dispose() {
    _numberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: 860, maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.34), blurRadius: 34, offset: const Offset(0, -12))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: palette.textSecondary.withOpacity(0.35), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_editing ? Icons.edit_rounded : Icons.add_business_rounded, color: palette.secondary),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_editing ? 'Modificar mesa' : 'Crear mesa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 3),
                          Text('Configura su identificación, estado y fotografía.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'Cerrar', onPressed: _saving ? null : () => Navigator.of(context).pop(false), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              if (_saving) const LinearProgressIndicator(minHeight: 3),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 700;
                        final profile = _PhotoEditor(
                          value: _photo,
                          palette: palette,
                          onChanged: (value) => setState(() {
                            _photo = value;
                            _photoChanged = true;
                          }),
                        );
                        final fields = Column(
                          children: [
                            TextFormField(
                              controller: _numberController,
                              maxLength: 10,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              inputFormatters: InputConstraints.integerFormatters(maxValue: 2147483647),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Número de mesa', prefixIcon: Icon(Icons.numbers_rounded)),
                              validator: (value) {
                                final parsed = int.tryParse((value ?? '').trim());
                                if (parsed == null || parsed <= 0) return 'Ingresa un número de mesa válido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Descripción o ubicación',
                                hintText: 'Ejemplo: Terraza, junto a la ventana, zona VIP...',
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _state,
                              decoration: const InputDecoration(labelText: 'Estado de la mesa', prefixIcon: Icon(Icons.toggle_on_outlined)),
                              items: const [
                                DropdownMenuItem(value: 'DISPONIBLE', child: Text('Disponible')),
                                DropdownMenuItem(value: 'OCUPADA', child: Text('Ocupada')),
                                DropdownMenuItem(value: 'INACTIVA', child: Text('Inactiva')),
                              ],
                              onChanged: !widget.canChangeState ||
                                  widget.table?.isOccupied == true
                                  ? null
                                  : (value) => setState(() => _state = value ?? 'DISPONIBLE'),
                            ),
                            if (widget.table?.isOccupied == true) ...[
                              const SizedBox(height: 8),
                              _InlineMessage(message: 'El estado de una mesa ocupada se administra desde la venta activa.', palette: palette, warning: true),
                            ],
                          ],
                        );
                        if (!wide) {
                          return Column(children: [profile, const SizedBox(height: 16), fields]);
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 270, child: profile),
                            const SizedBox(width: 18),
                            Expanded(child: fields),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(palette.darkBackground ? 0.45 : 0.78),
                  border: Border(top: BorderSide(color: palette.cardBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: Icon(_editing ? Icons.save_rounded : Icons.add_rounded),
                        label: Text(_editing ? 'Guardar cambios' : 'Crear mesa'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'sucuId': widget.branchId,
      'mesaNumero': int.parse(_numberController.text.trim()),
      'mesaEstado': _state,
      'mesaDescripcion': _descriptionController.text.trim(),
      'mesaFoto': _photoChanged || !_editing ? _photo.trim() : widget.table?.photo,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (_editing) {
        await api.put<Map<String, dynamic>>(
          '${ApiPaths.mesas}/${widget.table!.id}',
          payload,
          _parseMap,
        );
      } else {
        await api.post<Map<String, dynamic>>(ApiPaths.mesas, payload, _parseMap);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMapper.map(error).message), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _PhotoEditor extends StatefulWidget {
  const _PhotoEditor({required this.value, required this.palette, required this.onChanged});

  final String value;
  final AppPalette palette;
  final ValueChanged<String> onChanged;

  @override
  State<_PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<_PhotoEditor> {
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > InputConstraints.imageMaxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen no puede superar 2 MB.')),
        );
        return;
      }
      final extension = (file?.extension ?? 'png').toLowerCase();
      final mime = extension == 'jpg' || extension == 'jpeg'
          ? 'image/jpeg'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/png';
      widget.onChanged('data:$mime;base64,${base64Encode(bytes)}');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: widget.palette.panelDecoration(baseRadius: 22, tint: widget.palette.secondary, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Foto de la mesa', style: TextStyle(color: widget.palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _SmartImage(value: value, palette: widget.palette, iconSize: 46),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _picking ? null : _pick,
            icon: Icon(_picking ? Icons.hourglass_top_rounded : Icons.upload_file_rounded),
            label: Text(value.isEmpty ? 'Cargar foto' : 'Reemplazar foto'),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => widget.onChanged(''),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar foto'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveSummary extends StatelessWidget {
  const _LiveSummary({required this.live, required this.palette});

  final _LiveTableSale live;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final progress = live.total <= 0 ? 0.0 : (live.paid / live.total).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.warning, elevated: false),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _DetailMetric(label: 'Venta', value: live.saleId == null ? '-' : '#${live.saleId}', icon: Icons.tag_rounded, palette: palette)),
              Expanded(child: _DetailMetric(label: 'Responsable', value: live.responsible, icon: Icons.person_outline_rounded, palette: palette)),
              Expanded(child: _DetailMetric(label: 'Tiempo', value: _durationLabel(live.durationMinutes), icon: Icons.schedule_rounded, palette: palette)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DetailMetric(label: 'Consumo', value: CurrencyUtils.format(live.total), icon: Icons.receipt_long_outlined, palette: palette)),
              Expanded(child: _DetailMetric(label: 'Pagado', value: CurrencyUtils.format(live.paid), icon: Icons.payments_outlined, palette: palette)),
              Expanded(child: _DetailMetric(label: 'Saldo', value: CurrencyUtils.format(live.balance), icon: Icons.account_balance_wallet_outlined, palette: palette, emphasis: live.balance > 0)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: palette.background.withOpacity(0.52),
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 1 ? palette.success : palette.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.account, required this.palette});

  final Map<String, dynamic> account;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final products = _mapList(account['productos']);
    final payments = _mapList(account['pagos']);
    final total = _toDouble(account['total']);
    final paid = _toDouble(account['total_pagado']);
    final balance = _toDouble(account['saldo_pendiente']);
    final number = _toInt(account['numero']) ?? 0;

    return Container(
      decoration: palette.panelDecoration(baseRadius: 20, tint: balance > 0 ? palette.warning : palette.success, elevated: false),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
          child: Text('$number', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        title: Text('Cuenta $number', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
        subtitle: Text('${products.length} producto${products.length == 1 ? '' : 's'} · ${CurrencyUtils.format(total)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
        trailing: _StatusPill(label: balance > 0 ? 'Pendiente' : 'Pagada', color: balance > 0 ? palette.warning : palette.success, palette: palette),
        children: [
          Row(
            children: [
              Expanded(child: _AmountLine(label: 'Total', value: total, palette: palette)),
              Expanded(child: _AmountLine(label: 'Pagado', value: paid, palette: palette)),
              Expanded(child: _AmountLine(label: 'Saldo', value: balance, palette: palette, alignEnd: true)),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Text('Productos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
          const SizedBox(height: 7),
          if (products.isEmpty)
            Text('Sin productos registrados.', style: TextStyle(color: palette.textSecondary))
          else
            for (final product in products) _ProductRow(product: product, palette: palette),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: Text('Pagos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
          const SizedBox(height: 7),
          if (payments.isEmpty)
            Text('Todavía no se han registrado pagos.', style: TextStyle(color: palette.textSecondary))
          else
            for (final payment in payments) _PaymentRow(payment: payment, palette: palette),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.palette});

  final Map<String, dynamic> product;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final name = _text(product['producto_nombre'], 'Producto');
    final photo = _text(product['producto_foto']);
    final quantity = _toDouble(product['cantidad']);
    final unitPrice = _toDouble(product['valor_unitario']);
    final subtotal = _toDouble(product['subtotal']);
    final paid = _toBool(product['pagado']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _SmartImage(value: photo, palette: palette, iconSize: 20))),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${_numberLabel(quantity)} × ${CurrencyUtils.format(unitPrice)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyUtils.format(subtotal), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(paid ? 'Pagado' : 'Pendiente', style: TextStyle(color: paid ? palette.success : palette.warning, fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.palette});

  final Map<String, dynamic> payment;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final method = _text(payment['medio_pago_nombre'], 'Medio de pago');
    final value = _toDouble(payment['valor']);
    final responsible = _text(payment['responsable']);
    final date = _formatDateTime(payment['fecha']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: palette.success.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.success.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, color: palette.success, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  if (responsible.isNotEmpty || date.isNotEmpty)
                    Text([responsible, date].where((value) => value.isNotEmpty).join(' · '), style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
                ],
              ),
            ),
            Text(CurrencyUtils.format(value), style: TextStyle(color: palette.success, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _AvailableTablePanel extends StatelessWidget {
  const _AvailableTablePanel({required this.table, required this.palette});

  final _ManagerTable table;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = table.isInactive ? palette.textSecondary : palette.success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: palette.panelDecoration(baseRadius: 22, tint: color, elevated: false),
      child: Column(
        children: [
          Icon(table.isInactive ? Icons.block_rounded : Icons.event_available_rounded, color: color, size: 46),
          const SizedBox(height: 10),
          Text(
            table.isInactive ? 'Mesa inactiva' : 'Mesa disponible',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 5),
          Text(
            table.isInactive ? 'No participa en la operación hasta que sea reactivada.' : 'No tiene una venta abierta en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TodayStatsPanel extends StatelessWidget {
  const _TodayStatsPanel({required this.stats, required this.palette});

  final _TodayTableStats stats;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 20, tint: palette.secondary, elevated: false),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatBox(label: 'Ventas', value: '${stats.saleCount}', icon: Icons.point_of_sale_outlined, palette: palette),
          _StatBox(label: 'Facturado', value: CurrencyUtils.format(stats.total), icon: Icons.trending_up_rounded, palette: palette),
          _StatBox(label: 'Recaudado', value: CurrencyUtils.format(stats.paid), icon: Icons.payments_outlined, palette: palette),
          _StatBox(label: 'Propinas', value: CurrencyUtils.format(stats.tips), icon: Icons.volunteer_activism_outlined, palette: palette),
          _StatBox(label: 'Última actividad', value: stats.lastActivityLabel, icon: Icons.history_rounded, palette: palette),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data, required this.palette, required this.selected, this.onTap});

  final _KpiData data;
  final AppPalette palette;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(palette.radius(20)),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: palette.panelDecoration(baseRadius: 20, tint: data.color, elevated: selected),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: data.color.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.icon, required this.label, required this.palette, required this.onTap});

  final IconData icon;
  final String label;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, color: palette.warning, size: 18),
      label: Text(label),
      side: BorderSide(color: palette.warning.withOpacity(0.28)),
      backgroundColor: palette.warning.withOpacity(0.08),
      labelStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({required this.value, required this.label, required this.icon, required this.items, required this.text, required this.onChanged});

  final T value;
  final String label;
  final IconData icon;
  final List<T> items;
  final String Function(T value) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (_) => [for (final item in items) PopupMenuItem(value: item, child: Text(text(item)))],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 20), const SizedBox(width: 7), Text(text(value), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 5), const Icon(Icons.expand_more_rounded, size: 19)],
        ),
      ),
    );
  }
}

class _TablePhoto extends StatelessWidget {
  const _TablePhoto({required this.value, required this.size, required this.palette});

  final String value;
  final double size;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.30),
        child: _SmartImage(value: value, palette: palette, iconSize: size * 0.42),
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  const _SmartImage({required this.value, required this.palette, required this.iconSize});

  final String value;
  final AppPalette palette;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    final fallback = Container(
      color: palette.secondary.withOpacity(0.10),
      alignment: Alignment.center,
      child: Icon(Icons.table_bar_rounded, color: palette.secondary, size: iconSize),
    );
    if (trimmed.isEmpty) return fallback;
    if (trimmed.startsWith('data:image')) {
      final comma = trimmed.indexOf(',');
      if (comma > -1) {
        try {
          return Image.memory(base64Decode(trimmed.substring(comma + 1)), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
        } catch (_) {
          return fallback;
        }
      }
    }
    return Image.network(trimmed, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color, required this.palette});

  final String label;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(0.24))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10.5)),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label, required this.palette, this.warning = false});

  final IconData icon;
  final String label;
  final AppPalette palette;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? palette.warning : palette.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(0.16))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5))]),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.value, required this.palette});

  final IconData icon;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 17, color: palette.secondary), const SizedBox(width: 5), Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)))],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value, required this.palette, this.alignEnd = false});

  final String label;
  final double value;
  final AppPalette palette;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 2),
        Text(CurrencyUtils.format(value), textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }
}

class _TodayIndicator extends StatelessWidget {
  const _TodayIndicator({required this.label, required this.value, required this.palette, this.alignEnd = false});

  final String label;
  final String value;
  final AppPalette palette;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5))],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, required this.subtitle, required this.palette});

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: palette.secondary, size: 20)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)), Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))])),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value, required this.icon, required this.palette, this.emphasis = false});

  final String label;
  final String value;
  final IconData icon;
  final AppPalette palette;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final color = emphasis ? palette.warning : palette.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.icon, required this.palette});

  final String label;
  final String value;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.70), borderRadius: BorderRadius.circular(15), border: Border.all(color: palette.cardBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: palette.secondary, size: 19), const SizedBox(width: 7), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.5))])]),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.palette, this.warning = false});

  final String message;
  final AppPalette palette;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? palette.warning : palette.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [Icon(warning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, color: color, size: 20), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)))]),
    );
  }
}

class _ManagerTable {
  const _ManagerTable({
    required this.id,
    required this.branchId,
    required this.number,
    required this.state,
    required this.description,
    required this.photo,
    required this.updatedBy,
    required this.updatedAt,
    required this.live,
    required this.today,
  });

  final int id;
  final int branchId;
  final int number;
  final String state;
  final String description;
  final String photo;
  final String updatedBy;
  final DateTime? updatedAt;
  final _LiveTableSale live;
  final _TodayTableStats today;

  factory _ManagerTable.fromJson(Map<String, dynamic> json, {_LiveTableSale? live, _TodayTableStats? today}) {
    return _ManagerTable(
      id: _toInt(json['mesaId']) ?? 0,
      branchId: _toInt(json['sucuId']) ?? 0,
      number: _toInt(json['mesaNumero']) ?? 0,
      state: _text(json['mesaEstado'], 'DISPONIBLE').toUpperCase(),
      description: _text(json['mesaDescripcion']),
      photo: _text(json['mesaFoto']),
      updatedBy: _text(json['mesaRegistradoPor']),
      updatedAt: _toDateTime(json['mesaFechaCambio']),
      live: live ?? const _LiveTableSale(),
      today: today ?? const _TodayTableStats(),
    );
  }

  bool get isInactive => state == 'INACTIVA';
  bool get isOccupied => live.saleId != null || (!isInactive && state == 'OCUPADA');
  bool get isAvailable => !isInactive && !isOccupied;
  bool get hasAlert => isOccupied && (live.durationMinutes >= 90 || live.balance >= 100000 || live.productUnits <= 0);
  String get statusLabel => isInactive ? 'INACTIVA' : isOccupied ? 'OCUPADA' : 'DISPONIBLE';

  _ManagerTable copyWith({_LiveTableSale? live}) => _ManagerTable(
        id: id,
        branchId: branchId,
        number: number,
        state: state,
        description: description,
        photo: photo,
        updatedBy: updatedBy,
        updatedAt: updatedAt,
        live: live ?? this.live,
        today: today,
      );
}

class _LiveTableSale {
  const _LiveTableSale({
    this.saleId,
    this.tableId,
    this.responsible = 'Sin responsable',
    this.total = 0,
    this.paid = 0,
    this.balance = 0,
    this.tips = 0,
    this.durationMinutes = 0,
    this.accountCount = 0,
    this.productUnits = 0,
    this.state = '',
  });

  final int? saleId;
  final int? tableId;
  final String responsible;
  final double total;
  final double paid;
  final double balance;
  final double tips;
  final int durationMinutes;
  final int accountCount;
  final double productUnits;
  final String state;

  factory _LiveTableSale.fromJson(Map<String, dynamic> json) {
    final accounts = _mapList(json['cuentas']);
    final units = accounts.fold<double>(0, (sum, account) {
      return sum + _mapList(account['productos']).fold<double>(0, (productSum, product) => productSum + _toDouble(product['cantidad']));
    });
    return _LiveTableSale(
      saleId: _toInt(json['venta_id'] ?? json['ventaId']),
      tableId: _toInt(json['mesa_id'] ?? json['mesaId']),
      responsible: _text(json['responsable'], 'Sin responsable'),
      total: _toDouble(json['total']),
      paid: _toDouble(json['total_pagado'] ?? json['totalPagado']),
      balance: _toDouble(json['saldo_pendiente'] ?? json['saldoPendiente']),
      tips: _toDouble(json['propina']),
      durationMinutes: _toDouble(json['duracion_minutos'] ?? json['duracionMinutos']).round(),
      accountCount: accounts.length,
      productUnits: units,
      state: _text(json['estado']),
    );
  }
}

class _TodayTableStats {
  const _TodayTableStats({
    this.saleCount = 0,
    this.total = 0,
    this.paid = 0,
    this.tips = 0,
    this.lastActivity,
  });

  final int saleCount;
  final double total;
  final double paid;
  final double tips;
  final DateTime? lastActivity;

  _TodayTableStats addSale(Map<String, dynamic> row) {
    final date = _toDateTime(row['fecha']);
    final newer = lastActivity == null || (date != null && date.isAfter(lastActivity!)) ? date : lastActivity;
    return _TodayTableStats(
      saleCount: saleCount + 1,
      total: total + _toDouble(row['total']),
      paid: paid + _toDouble(row['total_pagado']),
      tips: tips + _toDouble(row['propina']),
      lastActivity: newer,
    );
  }

  String get lastActivityLabel => lastActivity == null ? 'Sin actividad' : DateFormat('HH:mm').format(lastActivity!);
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color, this.filter);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final _TableFilter? filter;
}

enum _TableFilter { all, occupied, available, inactive, alerts }

extension _TableFilterX on _TableFilter {
  String get label => switch (this) {
        _TableFilter.all => 'Todas',
        _TableFilter.occupied => 'Ocupadas',
        _TableFilter.available => 'Disponibles',
        _TableFilter.inactive => 'Inactivas',
        _TableFilter.alerts => 'Con alertas',
      };
}

enum _TableSort { number, consumption, balance, duration, today }

extension _TableSortX on _TableSort {
  String get label => switch (this) {
        _TableSort.number => 'Número',
        _TableSort.consumption => 'Mayor consumo',
        _TableSort.balance => 'Mayor saldo',
        _TableSort.duration => 'Mayor tiempo',
        _TableSort.today => 'Facturación de hoy',
      };
}

Map<String, dynamic> _parseMap(Object? json) => json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

List<Map<String, dynamic>> _parseMapList(Object? json) {
  if (json is! List) return const <Map<String, dynamic>>[];
  return json.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
}

int? _toInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim();
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _toDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String _formatDateTime(Object? value) {
  final date = _toDateTime(value);
  return date == null ? '' : DateFormat('dd/MM · HH:mm').format(date);
}

String _normalize(String value) {
  var text = value.toLowerCase().trim();
  const replacements = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  replacements.forEach((key, replacement) => text = text.replaceAll(key, replacement));
  return text;
}

String _durationLabel(int minutes) {
  if (minutes <= 0) return 'Recién abierta';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours <= 0) return '$remaining min';
  return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
}

String _numberLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return NumberFormat('0.##', 'es_CO').format(value);
}
