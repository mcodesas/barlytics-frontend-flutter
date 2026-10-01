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
import '../../../sucursales/data/models/sucursales_response_model.dart';

enum _InventoryAdminFilter {
  todos,
  pendientes,
  conDiferencias,
  sincronizados,
  cuadrados,
}

class InventarioAdminPage extends ConsumerStatefulWidget {
  const InventarioAdminPage({super.key});

  @override
  ConsumerState<InventarioAdminPage> createState() =>
      _InventarioAdminPageState();
}

class _InventarioAdminPageState extends ConsumerState<InventarioAdminPage> {
  final _searchController = TextEditingController();

  late DateTimeRange _range;
  int? _branchId;
  bool _loading = true;
  String? _error;
  _InventoryAdminFilter _filter = _InventoryAdminFilter.todos;
  List<_InventoryAuditRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 30)),
      end: today,
    );
    _branchId = ref.read(branchScopeProvider).activeBranchId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final branchId = _branchId ?? ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Selecciona una sucursal para consultar el control de inventario.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await ref.read(apiClientProvider).get<
          List<Map<String, dynamic>>>(
        '${ApiPaths.inventario}/administracion',
        (json) => (json as List? ?? const <Object>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
        queryParameters: {
          'sucursalId': branchId,
          'desde': DateFormat('yyyy-MM-dd').format(_range.start),
          'hasta': DateFormat('yyyy-MM-dd').format(_range.end),
        },
      );

      final rows = (response.data ?? const <Map<String, dynamic>>[])
          .map(_InventoryAuditRow.fromJson)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _branchId = branchId;
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

  List<_InventoryCountDay> get _days {
    final grouped = <String, List<_InventoryAuditRow>>{};
    for (final row in _rows) {
      final key = DateFormat('yyyy-MM-dd').format(row.countDate);
      grouped.putIfAbsent(key, () => <_InventoryAuditRow>[]).add(row);
    }

    final result = grouped.entries
        .map(
          (entry) => _InventoryCountDay(
            date: DateTime.parse(entry.key),
            rows: entry.value
              ..sort((a, b) => a.product.compareTo(b.product)),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  List<_InventoryCountDay> get _visibleDays {
    final query = _searchController.text.trim().toLowerCase();
    return _days.where((day) {
      final filterMatches = switch (_filter) {
        _InventoryAdminFilter.todos => true,
        _InventoryAdminFilter.pendientes => day.pendingCount > 0,
        _InventoryAdminFilter.conDiferencias => day.differenceCount > 0,
        _InventoryAdminFilter.sincronizados => day.syncedCount > 0,
        _InventoryAdminFilter.cuadrados => day.differenceCount == 0,
      };
      if (!filterMatches) return false;
      if (query.isEmpty) return true;

      return day.counters.join(' ').toLowerCase().contains(query) ||
          day.attendants.join(' ').toLowerCase().contains(query) ||
          day.rows.any(
            (row) =>
                row.product.toLowerCase().contains(query) ||
                '${row.countId}'.contains(query),
          );
    }).toList(growable: false);
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Periodo del reporte de inventario',
      saveText: 'Aplicar',
    );
    if (selected == null || !mounted) return;
    setState(() => _range = selected);
    await _load();
  }

  Future<void> _reviewReconciliation(_InventoryCountDay day) async {
    final candidates =
        day.rows.where((row) => row.reconciliable).toList(growable: false);
    if (candidates.isEmpty) return;

    final result = await showDialog<_ReconcileDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(dialogContext).width < 700 ? 10 : 24,
          vertical: MediaQuery.sizeOf(dialogContext).height < 760 ? 10 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: _ReconcileDialog(
          candidates: candidates,
          date: day.date,
          palette: ref.read(selectedAppPaletteProvider),
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      for (final id in result.ids) {
        await api.post<Object?>(
          '${ApiPaths.inventario}/sincronizar-conteo',
          {
            'invtId': id,
            'motivo': result.reason,
            'observacion': result.observation,
          },
          (json) => json,
        );
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.ids.length} diferencia(s) conciliada(s). '
            'Los movimientos quedaron auditados.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMapper.map(error).message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);

    ref.listen<BranchScopeState>(branchScopeProvider, (previous, next) {
      final nextId = next.activeBranchId;
      if (nextId != null && nextId != _branchId && mounted) {
        setState(() => _branchId = nextId);
        _load();
      }
    });

    if (_loading && _rows.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: Center(
            child: AppLoader(
              message: 'Construyendo control administrativo de inventario...',
            ),
          ),
        ),
      );
    }

    if (_error != null && _rows.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: AppErrorView(message: _error!, onRetry: _load),
        ),
      );
    }

    final days = _visibleDays;
    final allDays = _days;
    final missing = allDays.fold<double>(
      0,
      (sum, day) => sum + day.missingValue,
    );
    final surplus = allDays.fold<double>(
      0,
      (sum, day) => sum + day.surplusValue,
    );
    final pending = allDays.fold<int>(
      0,
      (sum, day) => sum + day.pendingCount,
    );
    final exact = _rows.where((row) => !row.hasDifference).length;
    final accuracy = _rows.isEmpty ? 0.0 : exact * 100 / _rows.length;
    final withoutCost =
        _rows.where((row) => row.hasDifference && row.unitPurchaseCost <= 0).length;

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
                  child: _PageWidth(
                    top: 16,
                    child: _InventoryAdminHeader(
                      palette: palette,
                      branches: branchState.branches,
                      branchId: _branchId,
                      range: _range,
                      onBranchChanged: (value) {
                        if (value == null || value == _branchId) return;
                        setState(() => _branchId = value);
                        _load();
                      },
                      onRange: _pickRange,
                      onRefresh: _load,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PageWidth(
                    child: _ExecutiveKpis(
                      palette: palette,
                      days: allDays.length,
                      products: _rows.length,
                      missing: missing,
                      surplus: surplus,
                      accuracy: accuracy,
                      pending: pending,
                    ),
                  ),
                ),
                if (withoutCost > 0)
                  SliverToBoxAdapter(
                    child: _PageWidth(
                      child: _CostWarning(
                        palette: palette,
                        count: withoutCost,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _PageWidth(
                    child: _AdminInsights(
                      days: allDays,
                      rows: _rows,
                      palette: palette,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PageWidth(
                    child: _AdminToolbar(
                      palette: palette,
                      controller: _searchController,
                      filter: _filter,
                      onSearch: (_) => setState(() {}),
                      onFilter: (value) => setState(() => _filter = value),
                    ),
                  ),
                ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: _PageWidth(
                      child: _InlineError(
                        palette: palette,
                        message: _error!,
                      ),
                    ),
                  ),
                if (days.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No hay jornadas de conteo para los filtros seleccionados.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
                    sliver: SliverList.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index == days.length - 1 ? 0 : 12,
                            ),
                            child: _CountDayCard(
                              day: days[index],
                              palette: palette,
                              onReview: days[index].reconciliableCount == 0 ||
                                      _loading
                                  ? null
                                  : () => _reviewReconciliation(days[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading && _rows.isNotEmpty)
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

class _InventoryAuditRow {
  const _InventoryAuditRow({
    required this.countId,
    required this.productId,
    required this.product,
    required this.countDate,
    required this.countedBy,
    required this.expected,
    required this.counted,
    required this.difference,
    required this.unitPurchaseCost,
    required this.purchasePresentationCost,
    required this.unitsPerPresentation,
    required this.purchasePresentation,
    required this.expectedValue,
    required this.countedValue,
    required this.missingValue,
    required this.surplusValue,
    required this.netImpact,
    required this.status,
    required this.latestCount,
    required this.adjustmentId,
    required this.adjustmentOperation,
    required this.adjustmentQuantity,
    required this.adjustmentReason,
    required this.synchronizedBy,
    required this.synchronizedAt,
    required this.salesDay,
    required this.totalSoldDay,
    required this.attendedBy,
  });

  final int countId;
  final int productId;
  final String product;
  final DateTime countDate;
  final String countedBy;
  final double expected;
  final double counted;
  final double difference;
  final double unitPurchaseCost;
  final double purchasePresentationCost;
  final double unitsPerPresentation;
  final String purchasePresentation;
  final double expectedValue;
  final double countedValue;
  final double missingValue;
  final double surplusValue;
  final double netImpact;
  final String status;
  final bool latestCount;
  final int? adjustmentId;
  final String? adjustmentOperation;
  final double adjustmentQuantity;
  final String? adjustmentReason;
  final String? synchronizedBy;
  final DateTime? synchronizedAt;
  final int salesDay;
  final double totalSoldDay;
  final String attendedBy;

  bool get hasDifference => difference.abs() > .0001;
  bool get reconciliable => status == 'PENDIENTE' && latestCount;

  factory _InventoryAuditRow.fromJson(Map<String, dynamic> json) {
    return _InventoryAuditRow(
      countId: _int(json['conteo_id']),
      productId: _int(json['producto_id']),
      product: json['producto']?.toString() ?? 'Producto',
      countDate:
          DateTime.tryParse(json['fecha_conteo']?.toString() ?? '') ??
              DateTime.now(),
      countedBy: _actor(json['contado_por']),
      expected: _num(json['esperado']),
      counted: _num(json['contado']),
      difference: _num(json['diferencia_unidades']),
      unitPurchaseCost: _num(json['costo_unitario_compra']),
      purchasePresentationCost:
          _num(json['costo_presentacion_compra']),
      unitsPerPresentation: _num(json['unidades_por_presentacion']),
      purchasePresentation:
          json['presentacion_compra']?.toString() ?? 'Unidad',
      expectedValue: _num(json['valor_esperado_compra']),
      countedValue: _num(json['valor_contado_compra']),
      missingValue: _num(json['valor_faltante_compra']),
      surplusValue: _num(json['valor_sobrante_compra']),
      netImpact: _num(json['impacto_neto_compra']),
      status: json['estado']?.toString() ?? 'CUADRA',
      latestCount: json['es_ultimo_conteo'] == true ||
          json['es_ultimo_conteo']?.toString() == 'true',
      adjustmentId: _nullableInt(json['movimiento_ajuste_id']),
      adjustmentOperation: json['ajuste_operacion']?.toString(),
      adjustmentQuantity: _num(json['ajuste_cantidad']),
      adjustmentReason: json['ajuste_motivo']?.toString(),
      synchronizedBy: json['sincronizado_por']?.toString(),
      synchronizedAt:
          DateTime.tryParse(json['sincronizado_en']?.toString() ?? ''),
      salesDay: _int(json['ventas_dia']),
      totalSoldDay: _num(json['total_vendido_dia']),
      attendedBy:
          json['atendieron']?.toString() ?? 'SIN_VENTAS_REGISTRADAS',
    );
  }
}

class _InventoryCountDay {
  const _InventoryCountDay({
    required this.date,
    required this.rows,
  });

  final DateTime date;
  final List<_InventoryAuditRow> rows;

  Set<String> get counters => rows
      .map((row) => row.countedBy)
      .where((value) => value.trim().isNotEmpty)
      .toSet();

  Set<String> get attendants {
    final result = <String>{};
    for (final row in rows) {
      for (final actor in row.attendedBy.split(',')) {
        final value = actor.trim();
        if (value.isNotEmpty && value != 'SIN_VENTAS_REGISTRADAS') {
          result.add(value);
        }
      }
    }
    return result;
  }

  int get salesDay => rows.isEmpty ? 0 : rows.first.salesDay;
  double get totalSoldDay => rows.isEmpty ? 0 : rows.first.totalSoldDay;
  int get differenceCount => rows.where((row) => row.hasDifference).length;
  int get pendingCount => rows.where((row) => row.status == 'PENDIENTE').length;
  int get reconciliableCount => rows.where((row) => row.reconciliable).length;
  int get syncedCount =>
      rows.where((row) => row.status == 'SINCRONIZADO').length;
  int get exactCount => rows.where((row) => !row.hasDifference).length;
  int get withoutCost =>
      rows.where((row) => row.hasDifference && row.unitPurchaseCost <= 0).length;

  double get missingValue =>
      rows.fold(0, (sum, row) => sum + row.missingValue);
  double get surplusValue =>
      rows.fold(0, (sum, row) => sum + row.surplusValue);
  double get netImpact => rows.fold(0, (sum, row) => sum + row.netImpact);
  double get expectedValue =>
      rows.fold(0, (sum, row) => sum + row.expectedValue);
  double get countedValue =>
      rows.fold(0, (sum, row) => sum + row.countedValue);
  double get accuracy => rows.isEmpty ? 0 : exactCount * 100 / rows.length;
}

class _ReconcileDialog extends StatefulWidget {
  const _ReconcileDialog({
    required this.candidates,
    required this.date,
    required this.palette,
  });

  final List<_InventoryAuditRow> candidates;
  final DateTime date;
  final AppPalette palette;

  @override
  State<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends State<_ReconcileDialog> {
  late final TextEditingController _observation;
  late final Set<int> _selected;
  int _step = 0;
  String _reason = 'Diferencia de conteo';

  @override
  void initState() {
    super.initState();
    _observation = TextEditingController();
    _selected = widget.candidates.map((row) => row.countId).toSet();
  }

  @override
  void dispose() {
    _observation.dispose();
    super.dispose();
  }

  List<_InventoryAuditRow> get _selectedRows => widget.candidates
      .where((row) => _selected.contains(row.countId))
      .toList(growable: false);

  double get _missing => _selectedRows.fold<double>(
        0,
        (sum, row) => sum + row.missingValue,
      );

  double get _surplus => _selectedRows.fold<double>(
        0,
        (sum, row) => sum + row.surplusValue,
      );

  double get _net => _surplus - _missing;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    final dialogWidth = mobile
        ? size.width - 20
        : math.min(size.width - 48, 780).toDouble();
    final dialogHeight = mobile
        ? size.height - 20
        : math.min(size.height - 48, 760).toDouble();

    return SizedBox(
      width: dialogWidth,
      height: dialogHeight,
      child: Material(
        color: palette.surface,
        child: Column(
          children: [
            _ReconcileDialogHeader(
              palette: palette,
              step: _step,
              date: widget.date,
              selected: _selected.length,
              total: widget.candidates.length,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _step == 0
                    ? _buildReviewStep(context, palette, mobile)
                    : _buildReasonStep(context, palette, mobile),
              ),
            ),
            _buildFooter(context, palette, mobile),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep(
    BuildContext context,
    AppPalette palette,
    bool mobile,
  ) {
    return Column(
      key: const ValueKey('review'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 12 : 18,
            12,
            mobile ? 12 : 18,
            10,
          ),
          child: Column(
            children: [
              _ReconcileMoneySummary(
                count: _selected.length,
                missing: _missing,
                surplus: _surplus,
                net: _net,
                palette: palette,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selecciona únicamente lo que realmente quieres ajustar.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selected.length == widget.candidates.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(
                              widget.candidates.map((row) => row.countId),
                            );
                        }
                      });
                    },
                    child: Text(
                      _selected.length == widget.candidates.length
                          ? 'Quitar todos'
                          : 'Seleccionar todos',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.cardBorder.withOpacity(.65)),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 16,
              12,
              mobile ? 10 : 16,
              18,
            ),
            itemCount: widget.candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = widget.candidates[index];
              final checked = _selected.contains(row.countId);
              return _ReconcileProductCard(
                row: row,
                selected: checked,
                palette: palette,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selected.add(row.countId);
                    } else {
                      _selected.remove(row.countId);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReasonStep(
    BuildContext context,
    AppPalette palette,
    bool mobile,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('reason'),
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 20,
        16,
        mobile ? 12 : 20,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReconcileMoneySummary(
            count: _selected.length,
            missing: _missing,
            surplus: _surplus,
            net: _net,
            palette: palette,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.secondary.withOpacity(.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: palette.secondary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Se crearán ${_selected.length} movimiento(s) de ajuste. '
                    'Las ventas, compras y movimientos posteriores al conteo '
                    'se conservan.',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(
              labelText: 'Motivo del ajuste',
              prefixIcon: Icon(Icons.rule_folder_outlined),
            ),
            items: const [
              'Diferencia de conteo',
              'Merma',
              'Rotura',
              'Consumo interno',
              'Pérdida',
              'Sobrante',
              'Error de registro',
              'Otro',
            ]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reason = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observation,
            minLines: mobile ? 3 : 4,
            maxLines: 5,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Sustentación',
              hintText:
                  'Ej. Se verificó físicamente bodega y barra antes de ajustar.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Productos incluidos',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _selectedRows) ...[
            _ReconcileFinalRow(row: row, palette: palette),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppPalette palette,
    bool mobile,
  ) {
    final canContinue = _selected.isNotEmpty;
    final canConfirm =
        canContinue && _observation.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 18,
        10,
        mobile ? 12 : 18,
        mobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.cardBorder.withOpacity(.65)),
        ),
      ),
      child: Row(
        children: [
          if (_step == 1)
            TextButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          const Spacer(),
          if (_step == 0)
            FilledButton.icon(
              onPressed: canContinue
                  ? () => setState(() => _step = 1)
                  : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                mobile
                    ? 'Continuar (${_selected.length})'
                    : 'Continuar con ${_selected.length}',
              ),
            )
          else
            FilledButton.icon(
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(
                        _ReconcileDecision(
                          ids: _selected.toList(growable: false),
                          reason: _reason,
                          observation: _observation.text.trim(),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                mobile
                    ? 'Confirmar ${_selected.length}'
                    : 'Confirmar ${_selected.length} ajuste(s)',
              ),
            ),
        ],
      ),
    );
  }
}

class _ReconcileDialogHeader extends StatelessWidget {
  const _ReconcileDialogHeader({
    required this.palette,
    required this.step,
    required this.date,
    required this.selected,
    required this.total,
    required this.onClose,
  });

  final AppPalette palette;
  final int step;
  final DateTime date;
  final int selected;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 18,
        14,
        mobile ? 8 : 12,
        12,
      ),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(.055),
        border: Border(
          bottom: BorderSide(color: palette.cardBorder.withOpacity(.55)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              step == 0
                  ? Icons.fact_check_outlined
                  : Icons.assignment_turned_in_outlined,
              color: palette.secondary,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step == 0
                      ? 'Revisar diferencias'
                      : 'Sustentar conciliación',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: mobile ? 15 : 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Conteo ${DateFormat('dd/MM/yyyy').format(date)} · '
                  '$selected de $total seleccionados · Paso ${step + 1} de 2',
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
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReconcileMoneySummary extends StatelessWidget {
  const _ReconcileMoneySummary({
    required this.count,
    required this.missing,
    required this.surplus,
    required this.net,
    required this.palette,
  });

  final int count;
  final double missing;
  final double surplus;
  final double net;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        'Seleccionados',
        '$count',
        Icons.checklist_rounded,
        palette.secondary,
      ),
      (
        'Faltante',
        CurrencyUtils.format(missing),
        Icons.trending_down_rounded,
        Colors.redAccent,
      ),
      (
        'Sobrante',
        CurrencyUtils.format(surplus),
        Icons.trending_up_rounded,
        palette.success,
      ),
      (
        'Impacto neto',
        CurrencyUtils.format(net),
        Icons.account_balance_wallet_outlined,
        net < 0 ? Colors.orangeAccent : palette.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 500 ? 2 : 4;
        const gap = 7.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: item.$4.withOpacity(.07),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: item.$4.withOpacity(.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, color: item.$4, size: 16),
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
                                color: item.$4,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              item.$1,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 8.5,
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

class _ReconcileProductCard extends StatelessWidget {
  const _ReconcileProductCard({
    required this.row,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final _InventoryAuditRow row;
  final bool selected;
  final AppPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final missing = row.difference < 0;
    final tone = missing ? Colors.redAccent : palette.success;

    return Material(
      color: selected
          ? palette.secondary.withOpacity(.055)
          : palette.background.withOpacity(.22),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? palette.secondary.withOpacity(.30)
                  : palette.cardBorder.withOpacity(.62),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value == true),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.product,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniAuditChip(
                          label: 'Esperado',
                          value: _qty(row.expected),
                          color: palette.secondary,
                          palette: palette,
                        ),
                        _MiniAuditChip(
                          label: 'Contado',
                          value: _qty(row.counted),
                          color: palette.accent,
                          palette: palette,
                        ),
                        _MiniAuditChip(
                          label: missing ? 'Faltan' : 'Sobran',
                          value: _qty(row.difference.abs()),
                          color: tone,
                          palette: palette,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Costo unit. ${CurrencyUtils.format(row.unitPurchaseCost)}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(row.netImpact),
                          style: TextStyle(
                            color: tone,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
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
}

class _MiniAuditChip extends StatelessWidget {
  const _MiniAuditChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(.13)),
        ),
        child: Text(
          '$label $value',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      );
}

class _ReconcileFinalRow extends StatelessWidget {
  const _ReconcileFinalRow({
    required this.row,
    required this.palette,
  });

  final _InventoryAuditRow row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final tone =
        row.difference < 0 ? Colors.redAccent : palette.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder.withOpacity(.55)),
      ),
      child: Row(
        children: [
          Icon(
            row.difference < 0
                ? Icons.remove_circle_outline_rounded
                : Icons.add_circle_outline_rounded,
            color: tone,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.product,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
          Text(
            '${_signedQty(row.difference)} · '
            '${CurrencyUtils.format(row.netImpact)}',
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconcileDecision {
  const _ReconcileDecision({
    required this.ids,
    required this.reason,
    required this.observation,
  });

  final List<int> ids;
  final String reason;
  final String observation;
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({
    required this.child,
    this.top = 12,
  });

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top, 16, 0),
            child: child,
          ),
        ),
      );
}

class _InventoryAdminHeader extends StatelessWidget {
  const _InventoryAdminHeader({
    required this.palette,
    required this.branches,
    required this.branchId,
    required this.range,
    required this.onBranchChanged,
    required this.onRange,
    required this.onRefresh,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? branchId;
  final DateTimeRange range;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback onRange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Control administrativo de inventario',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Audita qué se contó, cuánto dinero falta o sobra, quién atendió '
          'ese día y qué diferencias ya fueron conciliadas.',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (branches.length > 1)
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<int?>(
              value: branches.any((item) => item.sucuId == branchId)
                  ? branchId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sucursal',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              items: branches
                  .where((item) => item.sucuId != null)
                  .map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.sucuId,
                      child: Text(
                        item.sucuNombre ?? 'Sucursal ${item.sucuId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onBranchChanged,
            ),
          ),
        OutlinedButton.icon(
          onPressed: onRange,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(
            '${DateFormat('dd/MM/yy').format(range.start)} - '
            '${DateFormat('dd/MM/yy').format(range.end)}',
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Actualizar reporte',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );

    return Container(
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
                actions,
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 18),
                actions,
              ],
            ),
    );
  }
}

class _ExecutiveKpis extends StatelessWidget {
  const _ExecutiveKpis({
    required this.palette,
    required this.days,
    required this.products,
    required this.missing,
    required this.surplus,
    required this.accuracy,
    required this.pending,
  });

  final AppPalette palette;
  final int days;
  final int products;
  final double missing;
  final double surplus;
  final double accuracy;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final net = surplus - missing;
    final items = [
      (
        'Faltante a costo',
        CurrencyUtils.format(missing),
        'Valor de compra de unidades que debían estar y no se encontraron.',
        Icons.trending_down_rounded,
        Colors.redAccent,
      ),
      (
        'Sobrante a costo',
        CurrencyUtils.format(surplus),
        'Valor de compra de unidades encontradas por encima del sistema.',
        Icons.trending_up_rounded,
        palette.success,
      ),
      (
        'Impacto neto',
        CurrencyUtils.format(net),
        net < 0
            ? 'El faltante supera económicamente al sobrante.'
            : 'El sobrante compensa o supera el faltante.',
        Icons.account_balance_wallet_rounded,
        net < 0 ? Colors.orangeAccent : palette.success,
      ),
      (
        'Exactitud',
        '${accuracy.toStringAsFixed(1)} %',
        '$products productos auditados en $days jornada(s).',
        Icons.verified_rounded,
        accuracy >= 95 ? palette.success : palette.warning,
      ),
      (
        'Por administrar',
        '$pending',
        pending == 0
            ? 'No hay diferencias vigentes pendientes.'
            : 'Diferencias del último conteo que pueden revisarse.',
        Icons.pending_actions_rounded,
        pending == 0 ? palette.success : palette.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 1050
                ? 2
                : 5;
        const gap = 9.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 128),
                  padding: const EdgeInsets.all(13),
                  decoration: palette.panelDecoration(
                    baseRadius: 18,
                    tint: item.$5,
                    elevated: false,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$4, color: item.$5, size: 21),
                      const SizedBox(height: 9),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$1,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 9.5,
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

class _CostWarning extends StatelessWidget {
  const _CostWarning({
    required this.palette,
    required this.count,
  });

  final AppPalette palette;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: palette.warning.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.warning.withOpacity(.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.price_change_outlined, color: palette.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count producto(s) con diferencia no tienen costo de compra '
                'histórico disponible. El valor económico del faltante/sobrante '
                'de esos productos no puede calcularse hasta configurar el precio.',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AdminInsights extends StatelessWidget {
  const _AdminInsights({
    required this.days,
    required this.rows,
    required this.palette,
  });

  final List<_InventoryCountDay> days;
  final List<_InventoryAuditRow> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final missingProducts = [...rows]
      ..sort((a, b) => b.missingValue.compareTo(a.missingValue));
    final top = missingProducts
        .where((row) => row.missingValue > 0)
        .take(6)
        .toList(growable: false);

    final dayCards = days.take(8).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        final trend = _AdminPanel(
          title: 'Diferencias por jornada',
          subtitle:
              'Compara en dinero cuánto faltó y cuánto sobró en cada conteo.',
          icon: Icons.bar_chart_rounded,
          palette: palette,
          child: dayCards.isEmpty
              ? _EmptyAdminState(
                  palette: palette,
                  text: 'Aún no hay jornadas en el periodo.',
                )
              : Column(
                  children: [
                    for (final day in dayCards) ...[
                      _DayValueBar(day: day, palette: palette),
                      if (day != dayCards.last) const SizedBox(height: 10),
                    ],
                  ],
                ),
        );

        final products = _AdminPanel(
          title: 'Productos con mayor faltante',
          subtitle:
              'Prioriza dónde investigar primero según impacto a costo de compra.',
          icon: Icons.crisis_alert_rounded,
          palette: palette,
          child: top.isEmpty
              ? _EmptyAdminState(
                  palette: palette,
                  text: 'No hay faltantes valorizados en el periodo.',
                )
              : Column(
                  children: [
                    for (final row in top) ...[
                      _TopMissingProduct(row: row, palette: palette),
                      if (row != top.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
        );

        if (compact) {
          return Column(
            children: [
              trend,
              const SizedBox(height: 12),
              products,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: trend),
            const SizedBox(width: 12),
            Expanded(child: products),
          ],
        );
      },
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration:
            palette.panelDecoration(baseRadius: 20, elevated: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: palette.secondary),
                const SizedBox(width: 8),
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
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
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

class _DayValueBar extends StatelessWidget {
  const _DayValueBar({
    required this.day,
    required this.palette,
  });

  final _InventoryCountDay day;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(day.missingValue, day.surplusValue);
    final missingRatio =
        maxValue <= 0 ? 0.0 : day.missingValue / maxValue;
    final surplusRatio =
        maxValue <= 0 ? 0.0 : day.surplusValue / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(day.date),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              'Falta ${CurrencyUtils.format(day.missingValue)} · '
              'Sobra ${CurrencyUtils.format(day.surplusValue)}',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: missingRatio,
                  minHeight: 7,
                  backgroundColor: palette.cardBorder.withOpacity(.35),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: surplusRatio,
                  minHeight: 7,
                  backgroundColor: palette.cardBorder.withOpacity(.35),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(palette.success),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopMissingProduct extends StatelessWidget {
  const _TopMissingProduct({
    required this.row,
    required this.palette,
  });

  final _InventoryAuditRow row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.redAccent.withOpacity(.14)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.remove_circle_outline_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.product,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Faltan ${_qty(math.max(0, -row.difference))} unid. · '
                    'Costo unit. ${CurrencyUtils.format(row.unitPurchaseCost)}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyUtils.format(row.missingValue),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

class _AdminToolbar extends StatelessWidget {
  const _AdminToolbar({
    required this.palette,
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final _InventoryAdminFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_InventoryAdminFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _InventoryAdminFilter.todos: 'Todas las jornadas',
      _InventoryAdminFilter.pendientes: 'Por administrar',
      _InventoryAdminFilter.conDiferencias: 'Con diferencias',
      _InventoryAdminFilter.sincronizados: 'Sincronizadas',
      _InventoryAdminFilter.cuadrados: 'Sin diferencias',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          palette.panelDecoration(baseRadius: 20, elevated: false),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Buscar producto, quien contó o quien atendió',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          for (final value in _InventoryAdminFilter.values)
            ChoiceChip(
              selected: value == filter,
              label: Text(labels[value]!),
              onSelected: (_) => onFilter(value),
              selectedColor: palette.secondary.withOpacity(.13),
            ),
        ],
      ),
    );
  }
}

class _CountDayCard extends StatelessWidget {
  const _CountDayCard({
    required this.day,
    required this.palette,
    required this.onReview,
  });

  final _InventoryCountDay day;
  final AppPalette palette;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final risky = day.missingValue > 0 || day.pendingCount > 0;
    final tone = risky ? palette.warning : palette.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final reviewButton = onReview == null
            ? null
            : FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rule_rounded, size: 17),
                label: Text(
                  compact
                      ? 'Revisar diferencias (${day.reconciliableCount})'
                      : 'Revisar ${day.reconciliableCount} diferencia(s)',
                ),
              );

        return Container(
          decoration: palette.panelDecoration(
            baseRadius: 22,
            tint: tone,
            elevated: false,
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              9,
              compact ? 8 : 16,
              9,
            ),
            childrenPadding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              0,
              compact ? 10 : 14,
              16,
            ),
            leading: compact
                ? null
                : Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tone.withOpacity(.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      risky
                          ? Icons.inventory_2_outlined
                          : Icons.verified_rounded,
                      color: tone,
                    ),
                  ),
            title: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventario · ${DateFormat('dd/MM/yyyy').format(day.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _AccuracyBadge(
                        value: day.accuracy,
                        palette: palette,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Inventario · ${DateFormat('dd/MM/yyyy').format(day.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AccuracyBadge(
                        value: day.accuracy,
                        palette: palette,
                      ),
                    ],
                  ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Meta(
                          icon: Icons.person_search_rounded,
                          text: 'Contó: ${day.counters.join(', ')}',
                          palette: palette,
                        ),
                        const SizedBox(height: 4),
                        _Meta(
                          icon: Icons.groups_2_outlined,
                          text: day.attendants.isEmpty
                              ? 'Sin ventas registradas ese día'
                              : 'Atendieron: ${day.attendants.join(', ')}',
                          palette: palette,
                        ),
                        const SizedBox(height: 4),
                        _Meta(
                          icon: Icons.point_of_sale_rounded,
                          text:
                              '${day.salesDay} ventas · ${CurrencyUtils.format(day.totalSoldDay)}',
                          palette: palette,
                        ),
                        const SizedBox(height: 4),
                        _Meta(
                          icon: Icons.inventory_outlined,
                          text: '${day.rows.length} productos contados',
                          palette: palette,
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _Meta(
                          icon: Icons.person_search_rounded,
                          text: 'Contó: ${day.counters.join(', ')}',
                          palette: palette,
                        ),
                        _Meta(
                          icon: Icons.groups_2_outlined,
                          text: day.attendants.isEmpty
                              ? 'Sin ventas registradas ese día'
                              : 'Atendieron: ${day.attendants.join(', ')}',
                          palette: palette,
                        ),
                        _Meta(
                          icon: Icons.point_of_sale_rounded,
                          text:
                              '${day.salesDay} ventas · ${CurrencyUtils.format(day.totalSoldDay)}',
                          palette: palette,
                        ),
                        _Meta(
                          icon: Icons.inventory_outlined,
                          text: '${day.rows.length} productos contados',
                          palette: palette,
                        ),
                      ],
                    ),
            ),
            trailing: compact ? null : reviewButton,
            children: [
              const Divider(height: 1),
              if (compact && reviewButton != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: reviewButton,
                ),
              ],
              const SizedBox(height: 12),
              _DayFinancialSummary(day: day, palette: palette),
              if (day.withoutCost > 0) ...[
                const SizedBox(height: 10),
                _CostWarning(palette: palette, count: day.withoutCost),
              ],
              const SizedBox(height: 12),
              _ProductAuditHeader(palette: palette),
              const SizedBox(height: 6),
              for (var index = 0; index < day.rows.length; index++) ...[
                _ProductAuditRow(
                  row: day.rows[index],
                  palette: palette,
                ),
                if (index != day.rows.length - 1)
                  const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DayFinancialSummary extends StatelessWidget {
  const _DayFinancialSummary({
    required this.day,
    required this.palette,
  });

  final _InventoryCountDay day;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        'Valor esperado',
        CurrencyUtils.format(day.expectedValue),
        palette.secondary,
      ),
      (
        'Valor contado',
        CurrencyUtils.format(day.countedValue),
        palette.accent,
      ),
      (
        'Faltante',
        CurrencyUtils.format(day.missingValue),
        Colors.redAccent,
      ),
      (
        'Sobrante',
        CurrencyUtils.format(day.surplusValue),
        palette.success,
      ),
      (
        'Impacto neto',
        CurrencyUtils.format(day.netImpact),
        day.netImpact < 0 ? Colors.orangeAccent : palette.success,
      ),
      (
        'Pendientes',
        '${day.pendingCount}',
        day.pendingCount > 0 ? palette.warning : palette.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 2 : 6;
        const gap = 7.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.$3.withOpacity(.06),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: item.$3.withOpacity(.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.$3,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
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
              ),
          ],
        );
      },
    );
  }
}

class _ProductAuditHeader extends StatelessWidget {
  const _ProductAuditHeader({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Text(
        'Detalle producto por producto',
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      );
}

class _ProductAuditRow extends StatelessWidget {
  const _ProductAuditRow({
    required this.row,
    required this.palette,
  });

  final _InventoryAuditRow row;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (row.status) {
      'PENDIENTE' => palette.warning,
      'SINCRONIZADO' => palette.success,
      'SUPERADO' => palette.textSecondary,
      _ => palette.secondary,
    };

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder.withOpacity(.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.product,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(row.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _AuditValue(
                label: 'Esperado',
                value: _qty(row.expected),
                palette: palette,
              ),
              _AuditValue(
                label: 'Contado',
                value: _qty(row.counted),
                palette: palette,
              ),
              _AuditValue(
                label: 'Diferencia',
                value: _signedQty(row.difference),
                palette: palette,
                color: row.hasDifference
                    ? (row.difference < 0
                        ? Colors.redAccent
                        : palette.success)
                    : palette.secondary,
              ),
              _AuditValue(
                label: 'Costo unitario',
                value: CurrencyUtils.format(row.unitPurchaseCost),
                palette: palette,
              ),
              _AuditValue(
                label: 'Valor faltante',
                value: CurrencyUtils.format(row.missingValue),
                palette: palette,
                color:
                    row.missingValue > 0 ? Colors.redAccent : null,
              ),
              _AuditValue(
                label: 'Valor sobrante',
                value: CurrencyUtils.format(row.surplusValue),
                palette: palette,
                color: row.surplusValue > 0 ? palette.success : null,
              ),
            ],
          ),
          if (row.unitsPerPresentation > 1) ...[
            const SizedBox(height: 7),
            Text(
              'Compra: ${row.purchasePresentation} de '
              '${_qty(row.unitsPerPresentation)} unidades · '
              'Costo presentación ${CurrencyUtils.format(row.purchasePresentationCost)}',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
          ],
          if (row.status == 'SINCRONIZADO') ...[
            const SizedBox(height: 7),
            Text(
              'Conciliado'
              '${row.synchronizedBy == null ? '' : ' por ${row.synchronizedBy}'}'
              '${row.synchronizedAt == null ? '' : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(row.synchronizedAt!)}'}'
              '${row.adjustmentReason == null ? '' : ' · ${row.adjustmentReason}'}',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
          ] else if (row.status == 'SUPERADO') ...[
            const SizedBox(height: 7),
            Text(
              'Existe un conteo físico posterior de este producto. '
              'Este registro queda como evidencia histórica y ya no se concilia.',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditValue extends StatelessWidget {
  const _AuditValue({
    required this.label,
    required this.value,
    required this.palette,
    this.color,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 8.8,
              ),
            ),
          ],
        ),
      );
}

class _AccuracyBadge extends StatelessWidget {
  const _AccuracyBadge({
    required this.value,
    required this.palette,
  });

  final double value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = value >= 95
        ? palette.success
        : value >= 80
            ? palette.warning
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Exactitud ${value.toStringAsFixed(1)} %',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    required this.palette,
  });

  final IconData icon;
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    icon,
                    size: 14,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              TextSpan(text: text),
            ],
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.3,
            ),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _ReconcileSummary extends StatelessWidget {
  const _ReconcileSummary({
    required this.count,
    required this.missing,
    required this.surplus,
  });

  final int count;
  final double missing;
  final double surplus;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('$count producto(s) seleccionado(s)')),
          Chip(label: Text('Faltante ${CurrencyUtils.format(missing)}')),
          Chip(label: Text('Sobrante ${CurrencyUtils.format(surplus)}')),
        ],
      );
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState({
    required this.palette,
    required this.text,
  });

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.palette,
    required this.message,
  });

  final AppPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(.18)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
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

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return _int(value);
}

String _actor(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'SIN_USUARIO' : text;
}

String _qty(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) {
    return NumberFormat.decimalPattern('es_CO').format(number.toInt());
  }
  return NumberFormat.decimalPattern('es_CO').format(number);
}

String _signedQty(num value) {
  final number = value.toDouble();
  if (number > 0) return '+${_qty(number)}';
  return _qty(number);
}

String _statusLabel(String value) => switch (value) {
      'PENDIENTE' => 'POR ADMINISTRAR',
      'SINCRONIZADO' => 'CONCILIADO',
      'SUPERADO' => 'HISTÓRICO',
      _ => 'CUADRA',
    };
