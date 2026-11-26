import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../utils/inventory_count_history_filter.dart';
import '../utils/inventory_history_xlsx.dart';
import '../utils/inventory_admin_balance.dart';

enum _InventoryHistoryView { cards, table }

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
  String? _selectedDayKey;
  int? _selectedProductId;

  late DateTimeRange _range;
  int? _branchId;
  bool _loading = true;
  bool _exportingExcel = false;
  _InventoryHistoryView _historyView = _InventoryHistoryView.cards;
  String? _error;
  _InventoryAdminFilter _filter = _InventoryAdminFilter.todos;
  List<_InventoryAuditRow> _rows = const [];
  List<Map<String, dynamic>> _synchronizations = const [];
  String? _synchronizationWarning;
  bool _undoingSynchronization = false;
  bool _allSynchronizationHistory = false;

  bool get _canUndoSynchronization => ref.read(authControllerProvider).roles.any(
        (role) {
          final code = role.toUpperCase().replaceFirst('ROLE_', '');
          return const {'ADMINISTRADOR', 'GERENTE', 'ADMIN', 'SUPERADMIN',
              'SUPER_ADMIN', 'MANAGER'}.contains(code);
        },
      );

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
      final api = ref.read(apiClientProvider);
      final response = await api.get<
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
      List<Map<String, dynamic>> syncRows = const [];
      String? warning;
      try {
        final history = await api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.inventario}/administracion/sincronizaciones',
          (json) => (json as List? ?? const <Object>[])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
          queryParameters: {
            'sucursalId': branchId,
            if (!_allSynchronizationHistory)
              'desde': DateFormat('yyyy-MM-dd').format(_range.start),
            if (!_allSynchronizationHistory)
              'hasta': DateFormat('yyyy-MM-dd').format(_range.end),
          },
        );
        syncRows = history.data ?? const [];
      } catch (error) {
        debugPrint('No fue posible consultar auditoría de sincronizaciones: $error');
        warning = 'La bitácora de sincronizaciones no está disponible. '
            'Revisa la conexión o la versión del backend y reintenta.';
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _synchronizations = syncRows;
        _synchronizationWarning = warning;
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

  String? get _activeDayKey {
    final dayKey = _selectedDayKey;
    if (dayKey == null) return null;
    return _days.any(
      (day) => matchesCountHistoryDay(
        date: day.date, selectedDay: dayKey),
    ) ? dayKey : null;
  }

  /// El selector de productos sólo muestra los registrados en el día elegido.
  /// Sin fecha seleccionada, se ofrecen todos los productos del período.
  Map<int, String> get _availableCountedProducts {
    final dayKey = _activeDayKey;
    final products = <int, String>{};
    for (final day in _days) {
      if (!matchesCountHistoryDay(
          date: day.date, selectedDay: dayKey)) continue;
      for (final row in day.rows) {
        products[row.productId] = row.product;
      }
    }
    return products;
  }

  int? get _activeProductId {
    final id = _selectedProductId;
    return id != null && _availableCountedProducts.containsKey(id)
        ? id : null;
  }

  List<_InventoryCountDay> get _visibleDays {
    final query = _searchController.text.trim().toLowerCase();
    final selectedDay = _activeDayKey;
    final selectedProduct = _activeProductId;
    final result = <_InventoryCountDay>[];

    for (final day in _days) {
      if (!matchesCountHistoryDay(
          date: day.date, selectedDay: selectedDay)) continue;

      final filterMatches = switch (_filter) {
        _InventoryAdminFilter.todos => true,
        _InventoryAdminFilter.pendientes => day.pendingCount > 0,
        _InventoryAdminFilter.conDiferencias => day.differenceCount > 0,
        _InventoryAdminFilter.sincronizados => day.syncedCount > 0,
        _InventoryAdminFilter.cuadrados => day.differenceCount == 0,
      };
      if (!filterMatches) continue;

      // Filtrar las filas, no únicamente la fecha. Una búsqueda por
      // responsable mantiene los productos de la jornada y, si también se
      // seleccionó un producto, conserva únicamente ese producto.
      final matchingActor = query.isNotEmpty &&
          (day.counters.join(' ').toLowerCase().contains(query) ||
           day.attendants.join(' ').toLowerCase().contains(query));
      final productRows = day.rows.where((row) =>
          matchesCountHistoryRow(
            productId: row.productId,
            countId: row.countId,
            productName: row.product,
            selectedProductId: selectedProduct,
            query: matchingActor ? '' : query,
          )).toList(growable: false);

      if (productRows.isEmpty) continue;
      if ((query.isEmpty && selectedProduct == null) ||
          (matchingActor && selectedProduct == null)) {
        result.add(day);
      } else {
        result.add(_InventoryCountDay(date: day.date, rows: productRows));
      }
    }
    return result;
  }

  /// Genera el archivo XLSX desde el historial previamente autorizado y
  /// cargado en pantalla, si el endpoint de exportación responde HTTP 5xx.
  Uint8List _localHistoryExcel(DateTime start, DateTime end,
      {DateTime? onlyDay}) {
    final selectedDays = onlyDay != null
        ? <String>{DateFormat('yyyy-MM-dd').format(onlyDay)}
        : _visibleDays.map((d) =>
            DateFormat('yyyy-MM-dd').format(d.date)).toSet();
    // Se incluyen todos los productos de las jornadas filtradas, también
    // los que cuadraron; la búsqueda sólo decide qué jornadas exportar.
    final rows = _rows.where((row) => selectedDays.contains(
        DateFormat('yyyy-MM-dd').format(row.countDate))).toList(growable: false);

    final details = <List<Object?>>[
      const [
        'Fecha y hora del conteo', 'Producto', 'Código producto',
        'ID conteo', 'Contado por', 'Referencia de comparación',
        'Esperado histórico al conteo', 'Cantidad contada', 'Diferencia unidades',
        'Stock actual del sistema', 'Costo compra unitario',
        'Valor esperado', 'Valor contado', 'Valor faltante',
        'Valor sobrante', 'Impacto neto', 'Estado del conteo',
        'Conciliado por', 'Fecha conciliación',
        'Ventas del día', 'Total vendido día', 'Atendieron',
      ],
      for (final row in rows)
        [
          DateFormat('dd/MM/yyyy HH:mm').format(row.countDate),
          row.product, row.productId, row.countId, row.countedBy,
          row.expected, row.historicalExpected, row.counted, row.difference,
          row.hasCurrentSystemStock
              ? row.currentSystemStock : 'Sin movimientos',
          row.unitPurchaseCost, row.expectedValue, row.countedValue,
          row.missingValue, row.surplusValue, row.netImpact, row.status,
          row.synchronizedBy ?? '',
          row.synchronizedAt == null ? ''
              : DateFormat('dd/MM/yyyy HH:mm').format(row.synchronizedAt!),
          row.salesDay, row.totalSoldDay, row.attendedBy,
        ],
    ];

    double sum(double Function(_InventoryAuditRow) take) =>
        rows.fold<double>(0, (total, row) => total + take(row));
    final summary = <List<Object?>>[
      const ['BARLYTICS | RESUMEN DE CONTEOS', 'Valor'],
      ['Sucursal', _branchId ?? 'Sin sucursal'],
      ['Desde', DateFormat('dd/MM/yyyy').format(start)],
      ['Hasta', DateFormat('dd/MM/yyyy').format(end)],
      ['Jornadas exportadas', selectedDays.length],
      ['Productos contados', rows.length],
      ['Sin diferencias', rows.where((row) => !row.hasDifference).length],
      ['Con diferencias', rows.where((row) => row.hasDifference).length],
      ['Valor esperado de compra', sum((row) => row.expectedValue)],
      ['Valor contado de compra', sum((row) => row.countedValue)],
      ['Valor faltante', sum((row) => row.missingValue)],
      ['Valor sobrante', sum((row) => row.surplusValue)],
      ['Impacto neto', sum((row) => row.netImpact)],
      const ['Nota', 'Stock actual excluye conteos físicos. '
          'Si no hay movimientos operativos se indica Sin movimientos.'],
    ];
    return buildInventoryHistoryXlsx(detail: details, summary: summary);
  }

  Future<void> _exportExcel({DateTime? onlyDay}) async {
    if (_exportingExcel || _loading || _rows.isEmpty) return;
    final branchId = _branchId;
    if (branchId == null) return;
    setState(() => _exportingExcel = true);
    try {
      final start = onlyDay ?? _range.start;
      final end = onlyDay ?? _range.end;
      final dateStart = DateFormat('yyyy-MM-dd').format(start);
      final dateEnd = DateFormat('yyyy-MM-dd').format(end);
      final filter = onlyDay == null
          ? switch (_filter) {
              _InventoryAdminFilter.todos => 'TODOS',
              _InventoryAdminFilter.pendientes => 'PENDIENTES',
              _InventoryAdminFilter.conDiferencias => 'CON_DIFERENCIAS',
              _InventoryAdminFilter.sincronizados => 'SINCRONIZADOS',
              _InventoryAdminFilter.cuadrados => 'CUADRADOS',
            }
          : 'TODOS';
      Uint8List bytes;
      var generatedLocally = false;
      try {
        bytes = await ref.read(apiClientProvider).getBytes(
          '${ApiPaths.inventario}/administracion/excel',
          queryParameters: {
            'sucursalId': branchId,
            'desde': dateStart,
            'hasta': dateEnd,
            'filtro': filter,
            if (onlyDay == null && _searchController.text.trim().isNotEmpty)
              'buscar': _searchController.text.trim(),
          },
        );
      } on NetworkException catch (error) {
        final status = error.statusCode ?? 0;
        // Los errores de autorización, parámetros y permisos no se omiten.
        if (status < 500 || status >= 600) rethrow;
        bytes = _localHistoryExcel(start, end, onlyDay: onlyDay);
        generatedLocally = true;
      }
      final saved = await downloadBytesFile(
        fileName: 'BarLytics_Conteos_${branchId}_${dateStart}_${dateEnd}.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? (generatedLocally
                  ? 'Excel generado con los conteos cargados. '
                    'El servicio de exportación está temporalmente fallando.'
                  : 'Historial de conteos exportado a Excel con todos los productos.')
              : 'Se canceló la descarga del Excel.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible descargar Excel: ${ErrorMapper.map(error).message}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _undoSynchronization(Map<String, dynamic> audit) async {
    if (_undoingSynchronization || !_canUndoSynchronization) return;
    final countId = audit['conteo_id'];
    final movementId = audit['movimiento_id'];
    if (countId == null || movementId == null) return;
    final controller = TextEditingController();
    final justification = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Row(children: [
          Icon(Icons.restore_outlined, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(child: Text('Anular sincronización')),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Se anulará la conciliación del producto '
                '${audit['producto'] ?? 'seleccionado'} (conteo #$countId). '
                'El movimiento original seguirá en el historial y no se '
                'borrarán ventas ni compras posteriores.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio de anulación',
                  hintText: 'Por ejemplo: conciliación sin autorización o conteo equivocado',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            icon: const Icon(Icons.restore),
            label: const Text('Confirmar anulación'),
          ),
        ],
      ),
    );
    // El diálogo ya devolvió su resultado; el controlador no se utiliza después.
    controller.dispose();
    if (justification == null || !mounted) return;
    setState(() => _undoingSynchronization = true);
    try {
      await ref.read(apiClientProvider).post<Object?>(
        '${ApiPaths.inventario}/administracion/sincronizaciones/anular-lote',
        {'movimientoIds': [movementId], 'justificacion': justification},
        (json) => json,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Sincronización anulada con trazabilidad. '
            'Se conservó el inventario operativo.',
          )),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible anular: ${ErrorMapper.map(error).message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _undoingSynchronization = false);
    }
  }


  /// Anula en una única transacción los movimientos marcados, incluso si
  /// pertenecen a distintas fechas de conteo dentro de la sucursal actual.
  Future<void> _undoSelectedSynchronizations(List<int> movementIds) async {
    if (_undoingSynchronization || !_canUndoSynchronization || movementIds.isEmpty) return;
    if (movementIds.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Puedes anular hasta 1000 sincronizaciones por operación.'),
      ));
      return;
    }
    final selectedIds = movementIds.toSet();
    final preview = _synchronizations.where((row) {
      final raw = row['movimiento_id'];
      final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      return id != null && selectedIds.contains(id);
    }).take(6).map((row) => '• ${row['producto'] ?? 'Producto'} '
        '(movimiento #${row['movimiento_id']}, conteo #${row['conteo_id']})')
        .join('\n');
    final controller = TextEditingController();
    final justification = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Anular sincronizaciones seleccionadas'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Has seleccionado ${movementIds.length} sincronizaciones. '
                  'Se anularán todas en una sola operación, aunque sean de '
                  'distintas fechas. Los movimientos originales se conservarán '
                  'en la bitácora y no se modificarán las ventas ni el stock.'),
              const SizedBox(height: 10),
              if (preview.isNotEmpty)
                Text(preview, maxLines: 6, overflow: TextOverflow.ellipsis),
              if (movementIds.length > 6)
                Text('Y ${movementIds.length - 6} movimientos más incluidos '
                    'en la selección.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Justificación obligatoria para todo el lote',
                  hintText: 'Por ejemplo: conciliaciones realizadas por error',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            icon: const Icon(Icons.undo_rounded),
            label: Text('Anular ${movementIds.length} seleccionadas'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (justification == null || !mounted) return;
    setState(() => _undoingSynchronization = true);
    try {
      await ref.read(apiClientProvider).post<Object?>(
        '${ApiPaths.inventario}/administracion/sincronizaciones/anular-lote',
        {'movimientoIds': movementIds, 'justificacion': justification},
        (json) => json,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${movementIds.length} sincronizaciones anuladas '
              'con justificación y trazabilidad.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo anular el lote: ${ErrorMapper.map(error).message}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _undoingSynchronization = false);
    }
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
    setState(() {
      _range = selected;
      _selectedDayKey = null;
      _selectedProductId = null;
    });
    await _load();
  }

  /// Vista informativa de cada jornada, sin ajustar inventario ni
  /// modificar conteos. Un clic en una prioridad abre el producto filtrado.
  void _showDayDifferenceDetails(_InventoryCountDay day, {int? productId}) {
    if (!mounted) return;
    final palette = ref.read(selectedAppPaletteProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _DayDifferenceDetails(
        day: day,
        palette: palette,
        initialProductId: productId,
      ),
    );
  }

  Future<void> _reviewReconciliation(_InventoryCountDay day) async {
    final candidates =
        day.rows.where((row) => row.reconciliable).toList(growable: false);
    if (candidates.isEmpty) return;

    if (!mounted) return;
    // El diálogo se reconstruye después de desmontar la página.
    // Capturar la paleta ahora evita read() sobre un ref ya desechado.
    final palette = ref.read(selectedAppPaletteProvider);
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
          palette: palette,
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
        setState(() {
          _branchId = nextId;
          _selectedDayKey = null;
          _selectedProductId = null;
        });
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
    // El resumen ejecutivo considera SOLO la última jornada del período;
    // los faltantes históricos no se vuelven a sumar como pendientes actuales.
    final ultimoConteo = allDays.isEmpty ? null : allDays.first;
    final ultimosProductos = ultimoConteo?.rows ?? const <_InventoryAuditRow>[];
    final missing = ultimoConteo?.missingValue ?? 0.0;
    final surplus = ultimoConteo?.surplusValue ?? 0.0;
    final pending = ultimoConteo?.pendingCount ?? 0;
    final accuracy = ultimoConteo?.accuracy ?? 0.0;
    final withoutCost = ultimosProductos
        .where((row) => row.hasDifference && row.unitPurchaseCost <= 0)
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
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
                        setState(() {
                          _branchId = value;
                          _selectedDayKey = null;
                          _selectedProductId = null;
                        });
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
                      products: ultimosProductos.length,
                      lastCountDate: ultimoConteo?.date,
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
                      palette: palette,
                      onDayTap: (day) => _showDayDifferenceDetails(day),
                      onProductTap: (day, productId) =>
                          _showDayDifferenceDetails(day, productId: productId),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PageWidth(
                    child: _AdminToolbar(
                      palette: palette,
                      controller: _searchController,
                      filter: _filter,
                      dates: allDays.map((day) => day.date).toList(growable: false),
                      selectedDay: _activeDayKey,
                      products: _availableCountedProducts,
                      selectedProductId: _activeProductId,
                      onDayChanged: (day) => setState(() {
                        _selectedDayKey = day;
                        _selectedProductId = null;
                      }),
                      onProductChanged: (product) =>
                          setState(() => _selectedProductId = product),
                      onClear: () => setState(() {
                        _searchController.clear();
                        _selectedDayKey = null;
                        _selectedProductId = null;
                        _filter = _InventoryAdminFilter.todos;
                      }),
                      onSearch: (_) => setState(() {}),
                      onFilter: (value) => setState(() => _filter = value),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PageWidth(
                    child: _InventoryHistoryActions(
                      palette: palette,
                      view: _historyView,
                      count: days.fold<int>(0, (sum, day) => sum + day.rows.length),
                      exporting: _exportingExcel,
                      canExport: days.isNotEmpty && !_loading,
                      onViewChanged: (value) => setState(() => _historyView = value),
                      onExport: () => _exportExcel(
                        onlyDay: _activeDayKey == null
                            ? null : DateTime.parse(_activeDayKey!),
                      ),
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
                  SliverToBoxAdapter(
                    child: _PageWidth(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 28),
                        decoration: palette.panelDecoration(
                          baseRadius: 20, elevated: false),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                              color: palette.secondary, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              'Sin jornadas en este período',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Cambia las fechas, la sucursal o los filtros '
                              'para consultar otros conteos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                              key: ValueKey(
                                'conteo-${days[index].date.toIso8601String()}-'
                                '${_activeDayKey ?? 'todos'}-'
                                '${_activeProductId ?? 'todos'}',
                              ),
                              day: days[index],
                              palette: palette,
                              expandInitially: _activeDayKey != null ||
                                  _activeProductId != null,
                              tableView: _historyView == _InventoryHistoryView.table,
                              onExportExcel: !_loading && !_exportingExcel
                                  ? () => _exportExcel(onlyDay: days[index].date)
                                  : null,
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
                // La bitácora de sincronizaciones complementa el historial
                // y no desplaza las jornadas de conteo fuera de pantalla.
                SliverToBoxAdapter(
                    child: _PageWidth(
                      child: _SynchronizationHistoryPanel(
                        rows: _synchronizations,
                        palette: palette,
                        canUndo: _canUndoSynchronization && !_undoingSynchronization,
                        onUndo: _undoSynchronization,
                        onUndoSelected: _undoSelectedSynchronizations,
                        allHistorical: _allSynchronizationHistory,
                        onAllHistoricalChanged: (all) {
                          setState(() => _allSynchronizationHistory = all);
                          _load();
                        },
                      ),
                    ),
                  ),
                if (_synchronizationWarning != null)
                  SliverToBoxAdapter(
                    child: _PageWidth(
                      child: _InlineError(
                        palette: palette,
                        message: _synchronizationWarning!,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
    required this.historicalExpected,
    required this.usesCurrentStock,
    required this.counted,
    required this.difference,
    required this.currentSystemStock,
    required this.hasCurrentSystemStock,
    required this.currentSystemStockDate,
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
  final double historicalExpected;
  final bool usesCurrentStock;
  final double counted;
  final double difference;
  final double currentSystemStock;
  final bool hasCurrentSystemStock;
  final DateTime? currentSystemStockDate;
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
  // Un conteo cuya sincronización fue anulada puede reconciliarse otra vez
  // si sigue siendo el último conteo físico de ese producto.
  bool get reconciliable =>
      hasDifference &&
      (status == 'PENDIENTE' || status == 'ANULADO') &&
      latestCount;

  factory _InventoryAuditRow.fromJson(Map<String, dynamic> json) {
    final persistedStatus = json['estado']?.toString() ?? 'CUADRA';
    final latest = json['es_ultimo_conteo'] == true ||
        json['es_ultimo_conteo']?.toString() == 'true';
    final available = json['stock_actual_disponible'] == true ||
        json['stock_actual_disponible']?.toString() == 'true';
    final balance = InventoryAdminBalance.resolve(
      historicalExpected: _num(json['esperado_historico'] ?? json['esperado']),
      counted: _num(json['contado']),
      currentStock: _num(json['stock_actual_sistema']),
      hasCurrentStock: available,
      latestCount: latest,
      persistedStatus: persistedStatus,
      unitCost: _num(json['costo_unitario_compra']),
      persistedExpectedValue: _num(json['valor_esperado_compra']),
      persistedCountedValue: _num(json['valor_contado_compra']),
      persistedMissingValue: _num(json['valor_faltante_compra']),
      persistedSurplusValue: _num(json['valor_sobrante_compra']),
      persistedNetImpact: _num(json['impacto_neto_compra']),
    );
    return _InventoryAuditRow(
      countId: _int(json['conteo_id']),
      productId: _int(json['producto_id']),
      product: json['producto']?.toString() ?? 'Producto',
      countDate:
          DateTime.tryParse(json['fecha_conteo']?.toString() ?? '') ??
              DateTime.now(),
      countedBy: _actor(json['contado_por']),
      expected: balance.expected,
      historicalExpected: balance.historicalExpected,
      usesCurrentStock: balance.usesCurrentStock,
      counted: balance.counted,
      difference: balance.difference,
      currentSystemStock: _num(json['stock_actual_sistema']),
      hasCurrentSystemStock: json['stock_actual_disponible'] == true ||
          json['stock_actual_disponible']?.toString() == 'true',
      currentSystemStockDate:
          DateTime.tryParse(json['stock_actual_fecha']?.toString() ?? ''),
      unitPurchaseCost: _num(json['costo_unitario_compra']),
      purchasePresentationCost:
          _num(json['costo_presentacion_compra']),
      unitsPerPresentation: _num(json['unidades_por_presentacion']),
      purchasePresentation:
          json['presentacion_compra']?.toString() ?? 'Unidad',
      expectedValue: balance.expectedValue,
      countedValue: balance.countedValue,
      missingValue: balance.missingValue,
      surplusValue: balance.surplusValue,
      netImpact: balance.netImpact,
      status: balance.status,
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
  int get pendingCount =>
      rows.where((row) => row.reconciliable).length;
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
                    'Se aplicará lo contado como nuevo stock en cada producto '
                    'seleccionado. Cuando coincida, no se generará ningún '
                    'movimiento. Si hubo ventas o compras posteriores, '
                    'se pedirá reconfirmar el conteo antes de ajustarlo.',
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
                          label: row.usesCurrentStock ? 'Stock actual' : 'Esperado histórico',
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
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TechBrandMark(
          icon: Icons.fact_check_rounded,
          size: compact ? 44 : 54,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AUDITORÍA Y TRAZABILIDAD',
                style: TextStyle(
                  color: palette.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Historial de conteos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontSize: compact ? 21 : 25,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Revisa cada jornada, compara cantidades, identifica '
                'faltantes y sobrantes, y consulta las conciliaciones.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.4,
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

    return TechGlassPanel(
      padding: EdgeInsets.all(compact ? 15 : 18),
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
    required this.lastCountDate,
    required this.missing,
    required this.surplus,
    required this.accuracy,
    required this.pending,
  });

  final AppPalette palette;
  final int days;
  final int products;
  final DateTime? lastCountDate;
  final double missing;
  final double surplus;
  final double accuracy;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final net = surplus - missing;
    final fecha = lastCountDate == null
        ? 'Sin conteos en el período'
        : 'Último conteo: ${DateFormat('dd/MM/yyyy').format(lastCountDate!)}';
    final items = [
      (
        'Faltante a costo',
        CurrencyUtils.format(missing),
        'Unidades faltantes a costo del último conteo.',
        Icons.trending_down_rounded,
        Colors.redAccent,
      ),
      (
        'Sobrante a costo',
        CurrencyUtils.format(surplus),
        'Unidades sobrantes a costo del último conteo.',
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
        '$products productos del último conteo · $days jornada(s) en historial.',
        Icons.verified_rounded,
        accuracy >= 95 ? palette.success : palette.warning,
      ),
      (
        'Por administrar',
        '$pending',
        pending == 0
            ? 'No hay diferencias pendientes en el último conteo.'
            : 'Diferencias del último conteo que pueden revisarse.',
        Icons.pending_actions_rounded,
        pending == 0 ? palette.success : palette.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dos columnas en móvil amplio y tres en tableta. Evita tarjetas
        // innecesariamente altas y valores truncados en pantallas pequeñas.
        final columns = constraints.maxWidth < 390
            ? 1
            : constraints.maxWidth < 760
                ? 2
                : constraints.maxWidth < 1120
                    ? 3
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
                  constraints: const BoxConstraints(minHeight: 154),
                  padding: const EdgeInsets.all(14),
                  decoration: palette.panelDecoration(
                    baseRadius: 20,
                    tint: item.$5,
                    elevated: false,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: item.$5.withOpacity(.13),
                              borderRadius: BorderRadius.circular(
                                palette.radius(11)),
                            ),
                            child: Icon(item.$4, color: item.$5, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.$1,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        fecha,
                        style: TextStyle(
                          color: palette.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          height: 1.3,
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
    required this.palette,
    required this.onDayTap,
    required this.onProductTap,
  });

  final List<_InventoryCountDay> days;
  final AppPalette palette;
  final ValueChanged<_InventoryCountDay> onDayTap;
  final void Function(_InventoryCountDay day, int productId) onProductTap;

  @override
  Widget build(BuildContext context) {
    final ultimo = days.isEmpty ? null : days.first;
    // Las prioridades son únicamente del último conteo, no del histórico
    // completo; se muestran faltantes y sobrantes según impacto económico.
    final hallazgos = [...?ultimo?.rows.where(
      (row) => row.hasDifference &&
          (row.status == 'PENDIENTE' || row.status == 'ANULADO'),
    )]
      ..sort((a, b) {
        final impacto = b.netImpact.abs().compareTo(a.netImpact.abs());
        if (impacto != 0) return impacto;
        return b.difference.abs().compareTo(a.difference.abs());
      });
    final prioritarios = hallazgos.take(6).toList(growable: false);
    final dayCards = days.take(8).toList(growable: false);
    final ultimoFecha = ultimo == null
        ? 'Sin conteos'
        : DateFormat('dd/MM/yyyy').format(ultimo.date);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final trend = _AdminPanel(
          title: 'Diferencias por jornada',
          subtitle: 'Pulsa una jornada para ver productos, cantidades, '
              'faltantes, sobrantes, valores y responsables.',
          icon: Icons.bar_chart_rounded,
          palette: palette,
          child: dayCards.isEmpty
              ? _EmptyAdminState(
                  palette: palette,
                  text: 'Aún no hay jornadas en el período.',
                )
              : Column(
                  children: [
                    for (final day in dayCards) ...[
                      _DayValueBar(
                        day: day,
                        palette: palette,
                        onTap: () => onDayTap(day),
                      ),
                      if (day != dayCards.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
        );
        final products = _AdminPanel(
          title: 'Hallazgos prioritarios · último conteo',
          subtitle: 'Conteo $ultimoFecha · Ordenados por mayor '
              'impacto económico pendiente. Pulsa para inspeccionar.',
          icon: Icons.crisis_alert_rounded,
          palette: palette,
          child: prioritarios.isEmpty
              ? _EmptyAdminState(
                  palette: palette,
                  text: ultimo == null
                      ? 'No hay conteos en el período.'
                      : 'El último conteo no tiene diferencias pendientes '
                          'de revisar.',
                )
              : Column(
                  children: [
                    for (final row in prioritarios) ...[
                      _PriorityInventoryProduct(
                        row: row,
                        palette: palette,
                        onTap: () => onProductTap(ultimo!, row.productId),
                      ),
                      if (row != prioritarios.last)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
        );

        if (compact) {
          return Column(children: [
            trend,
            const SizedBox(height: 12),
            products,
          ]);
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
    required this.onTap,
  });

  final _InventoryCountDay day;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(day.missingValue, day.surplusValue);
    final missingRatio = maxValue <= 0 ? 0.0 : day.missingValue / maxValue;
    final surplusRatio = maxValue <= 0 ? 0.0 : day.surplusValue / maxValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: palette.secondary),
                  const SizedBox(width: 7),
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
                  Flexible(
                    flex: 3,
                    child: Text(
                      'Falta ${CurrencyUtils.format(day.missingValue)} · '
                      'Sobra ${CurrencyUtils.format(day.surplusValue)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded,
                      color: palette.secondary, size: 16),
                ],
              ),
              const SizedBox(height: 7),
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
              const SizedBox(height: 5),
              Text(
                '${day.rows.length} producto(s) · '
                '${day.differenceCount} con diferencia · '
                '${day.pendingCount} pendientes · Ver detalles',
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
    );
  }
}

/// Prioriza faltantes Y sobrantes del último conteo; muestra la unidad
/// afectada, su impacto real y permite abrir el panel detallado.
class _PriorityInventoryProduct extends StatelessWidget {
  const _PriorityInventoryProduct({
    required this.row,
    required this.palette,
    required this.onTap,
  });

  final _InventoryAuditRow row;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = row.difference < 0;
    final color = missing ? Colors.redAccent : palette.success;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(.05),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withOpacity(.17)),
          ),
          child: Row(
            children: [
              Icon(
                missing
                    ? Icons.remove_circle_outline_rounded
                    : Icons.add_circle_outline_rounded,
                color: color, size: 18,
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
                      '${missing ? "Faltan" : "Sobran"} '
                      '${_qty(row.difference.abs())} unid. · '
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
              const SizedBox(width: 6),
              Text(
                CurrencyUtils.format(row.netImpact.abs()),
                style: TextStyle(color: color,
                    fontWeight: FontWeight.w900, fontSize: 11),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: palette.secondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminToolbar extends StatelessWidget {
  const _AdminToolbar({
    required this.palette,
    required this.controller,
    required this.filter,
    required this.dates,
    required this.selectedDay,
    required this.products,
    required this.selectedProductId,
    required this.onDayChanged,
    required this.onProductChanged,
    required this.onClear,
    required this.onSearch,
    required this.onFilter,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final _InventoryAdminFilter filter;
  final List<DateTime> dates;
  final String? selectedDay;
  final Map<int, String> products;
  final int? selectedProductId;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<int?> onProductChanged;
  final VoidCallback onClear;
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

    const icons = {
      _InventoryAdminFilter.todos: Icons.view_list_rounded,
      _InventoryAdminFilter.pendientes: Icons.pending_actions_rounded,
      _InventoryAdminFilter.conDiferencias: Icons.balance_rounded,
      _InventoryAdminFilter.sincronizados: Icons.verified_rounded,
      _InventoryAdminFilter.cuadrados: Icons.check_circle_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(
        baseRadius: 22, tint: palette.primary, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.manage_search_rounded,
                color: palette.secondary, size: 23),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Buscar y filtrar jornadas',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLength: 120,
            buildCounter: (_, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            onChanged: onSearch,
            style: TextStyle(color: palette.textPrimary,
              fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Producto, responsable o quien atendió',
              prefixIcon: Icon(Icons.search_rounded,
                color: palette.secondary),
              suffixIcon: controller.text.isEmpty ? null : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onSearch('');
                },
              ),
              filled: true,
              fillColor: palette.darkBackground
                  ? Colors.white.withOpacity(.05)
                  : palette.background.withOpacity(.65),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(palette.radius(15)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 690
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            final sortedProducts = products.entries.toList()
              ..sort((a, b) =>
                  a.value.toLowerCase().compareTo(b.value.toLowerCase()));
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('inventory-count-day-filter-$selectedDay'),
                    value: selectedDay,
                    hint: const Text('Todas las jornadas'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Fecha del conteo',
                      prefixIcon: Icon(Icons.event_available_rounded,
                        color: palette.secondary),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        child: Text('Todas las jornadas'),
                      ),
                      for (final day in dates)
                        DropdownMenuItem<String>(
                          value: DateFormat('yyyy-MM-dd').format(day),
                          child: Text(DateFormat('dd/MM/yyyy').format(day)),
                        ),
                    ],
                    onChanged: onDayChanged,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      'inventory-count-product-$selectedDay-$selectedProductId'),
                    value: selectedProductId,
                    hint: const Text('Todos los productos'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Producto contado',
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                        color: palette.secondary),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        child: Text('Todos los productos'),
                      ),
                      for (final entry in sortedProducts)
                        DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: onProductChanged,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 9),
          Text(
            'Selecciona una fecha y luego un producto para ver '
            'qué se registró exactamente en ese conteo. '
            'Amplía el período superior para consultar fechas anteriores. '
            'El Excel conserva el historial completo de la jornada.',
            style: TextStyle(
              color: palette.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _InventoryAdminFilter.values)
                ChoiceChip(
                  avatar: Icon(icons[value], size: 17,
                    color: value == filter
                        ? palette.secondary : palette.textSecondary),
                  selected: value == filter,
                  label: Text(labels[value]!),
                  onSelected: (_) => onFilter(value),
                  selectedColor: palette.secondary.withOpacity(.17),
                  side: BorderSide(
                    color: value == filter
                        ? palette.secondary.withOpacity(.48)
                        : palette.translucentBorder,
                  ),
                ),
            ],
          ),
          if (controller.text.trim().isNotEmpty ||
              selectedDay != null ||
              selectedProductId != null ||
              filter != _InventoryAdminFilter.todos) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Limpiar filtros'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bitácora de conciliaciones. Permite elegir movimientos vigentes individuales,
/// todos los del período consultado o consultar jornadas históricas anteriores.
class _SynchronizationHistoryPanel extends StatefulWidget {
  const _SynchronizationHistoryPanel({
    required this.rows,
    required this.palette,
    required this.canUndo,
    required this.onUndo,
    required this.onUndoSelected,
    required this.allHistorical,
    required this.onAllHistoricalChanged,
  });

  final List<Map<String, dynamic>> rows;
  final AppPalette palette;
  final bool canUndo;
  final ValueChanged<Map<String, dynamic>> onUndo;
  final ValueChanged<List<int>> onUndoSelected;
  final bool allHistorical;
  final ValueChanged<bool> onAllHistoricalChanged;

  @override
  State<_SynchronizationHistoryPanel> createState() =>
      _SynchronizationHistoryPanelState();
}

class _SynchronizationHistoryPanelState
    extends State<_SynchronizationHistoryPanel> {
  bool showAll = false;
  final Set<int> _selectedMovements = <int>{};

  static int? _movementId(Map<String, dynamic> row) {
    final value = row['movimiento_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isSelectable(Map<String, dynamic> row) =>
      row['anulado'] != true && _movementId(row) != null;

  @override
  void didUpdateWidget(covariant _SynchronizationHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cuando cambie sucursal, período o estado de anulaciones, descartar
    // selecciones que ya no estén disponibles para evitar lotes inesperados.
    final available = widget.rows
        .where(_isSelectable)
        .map(_movementId)
        .whereType<int>()
        .toSet();
    _selectedMovements.removeWhere((id) => !available.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final ordered = widget.rows;
    final shown = showAll ? ordered : ordered.take(20).toList(growable: false);
    final available = ordered.where(_isSelectable)
        .map(_movementId).whereType<int>().toSet();
    final selectedCount = _selectedMovements.length;
    final selectedAll = available.isNotEmpty &&
        _selectedMovements.containsAll(available);

    String date(Object? raw) {
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      return parsed == null
          ? 'Sin fecha' : DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    }
    String observation(Object? raw) {
      final reference = raw?.toString() ?? '';
      final separator = reference.indexOf(' - ');
      return separator < 0 ? reference : reference.substring(separator + 3);
    }
    Widget head(String title) => Text(
          title,
          style: TextStyle(color: palette.textPrimary,
              fontSize: 11, fontWeight: FontWeight.w900),
        );
    Widget content(String value) => Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.textPrimary,
              fontSize: 11.5, fontWeight: FontWeight.w600),
        );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: palette.panelDecoration(baseRadius: 20, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history_toggle_off_rounded,
                color: palette.secondary, size: 23),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial de sincronizaciones',
                    style: TextStyle(color: palette.textPrimary,
                        fontWeight: FontWeight.w900, fontSize: 16)),
                Text(
                  '${ordered.length} movimientos de conciliación · '
                  '${available.length} vigentes · '
                  'incluye anotaciones, responsables y anulaciones.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11),
                ),
              ],
            )),
          ]),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Consultar sincronizaciones de todos los períodos'),
            subtitle: Text(widget.allHistorical
                ? 'Mostrando todos los registros históricos de esta sucursal.'
                : 'Por defecto se muestra únicamente el rango de fechas elegido.'),
            value: widget.allHistorical,
            onChanged: widget.onAllHistoricalChanged,
          ),
          if (widget.canUndo && available.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    if (selectedAll) {
                      _selectedMovements.clear();
                    } else {
                      _selectedMovements
                        ..clear()
                        ..addAll(available);
                    }
                  }),
                  icon: Icon(selectedAll
                      ? Icons.deselect_rounded : Icons.select_all_rounded),
                  label: Text(selectedAll
                      ? 'Deseleccionar todas'
                      : 'Seleccionar todas las vigentes (${available.length})'),
                ),
                if (selectedCount > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(_selectedMovements.clear),
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Limpiar selección'),
                  ),
                FilledButton.icon(
                  onPressed: selectedCount > 0 && selectedCount <= 1000
                      ? () => widget.onUndoSelected(
                          _selectedMovements.toList()..sort())
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                  label: Text('Anular seleccionadas ($selectedCount)'),
                ),
                Text('$selectedCount seleccionadas',
                    style: TextStyle(color: palette.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            if (selectedCount > 1000)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Para anular más de 1000 registros, reduce la '
                    'selección o filtra las fechas y haz varias operaciones.'),
              ),
          ],
          const SizedBox(height: 12),
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Todavía no hay sincronizaciones registradas en el período '
                'y la sucursal seleccionados.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          if (ordered.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: widget.canUndo,
                  onSelectAll: widget.canUndo ? (selected) {
                    setState(() {
                      final ids = shown
                          .where(_isSelectable)
                          .map(_movementId)
                          .whereType<int>();
                      if (selected == true) {
                        _selectedMovements.addAll(ids);
                      } else {
                        _selectedMovements.removeAll(ids);
                      }
                    });
                  } : null,
                  headingRowHeight: 46,
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 100,
                  columnSpacing: 19,
                  headingRowColor: MaterialStateProperty.all(
                      palette.secondary.withOpacity(.09)),
                  columns: [
                    DataColumn(label: head('Fecha')),
                    DataColumn(label: head('Producto')),
                    DataColumn(label: head('Diferencia')),
                    DataColumn(label: head('Sincronizó')),
                    DataColumn(label: head('Motivo y observación')),
                    DataColumn(label: head('Estado')),
                    DataColumn(label: head('Anulación / responsable')),
                    DataColumn(label: head('Acciones')),
                  ],
                  rows: [
                    for (final row in shown)
                      DataRow(
                        selected: _selectedMovements.contains(_movementId(row)),
                        onSelectChanged: widget.canUndo && _isSelectable(row)
                            ? (selected) {
                                final id = _movementId(row)!;
                                setState(() {
                                  if (selected == true) {
                                    _selectedMovements.add(id);
                                  } else {
                                    _selectedMovements.remove(id);
                                  }
                                });
                              }
                            : null,
                        cells: [
                          DataCell(content(date(row['sincronizado_en']))),
                          DataCell(SizedBox(
                            width: 155,
                            child: content(row['producto']?.toString() ?? 'Producto'),
                          )),
                          DataCell(content(
                            '${row['operacion'] ?? ''} '
                            '${_qty(_num(row['unidades_ajuste']))}',
                          )),
                          DataCell(content(
                              row['sincronizado_por']?.toString() ?? '—')),
                          DataCell(SizedBox(
                            width: 220,
                            child: content(
                              '${row['motivo'] ?? 'Sin motivo'} · '
                              '${observation(row['referencia_observacion'])}',
                            ),
                          )),
                          DataCell(Text(
                            row['anulado'] == true ? 'Anulada' : 'Vigente',
                            style: TextStyle(
                              color: row['anulado'] == true
                                  ? palette.warning : palette.success,
                              fontWeight: FontWeight.w800,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 230,
                            child: content(
                              row['anulado'] == true
                                  ? '${row['anulado_por'] ?? '—'} · '
                                    '${date(row['anulado_en'])} · '
                                    '${row['motivo_anulacion'] ?? ''}'
                                  : 'Sin anulación',
                            ),
                          )),
                          DataCell(
                            row['anulado'] == true
                                ? const Icon(Icons.history_rounded, size: 18)
                                : widget.canUndo
                                    ? TextButton.icon(
                                        onPressed: () => widget.onUndo(row),
                                        icon: const Icon(Icons.undo_rounded, size: 17),
                                        label: const Text('Anular'),
                                      )
                                    : const Text('Solo lectura'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (ordered.length > 20) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => showAll = !showAll),
                icon: Icon(showAll ? Icons.expand_less : Icons.expand_more),
                label: Text(showAll
                    ? 'Mostrar solo los últimos 20'
                    : 'Mostrar todos (${ordered.length})'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Control de presentación del historial y exportación del período visible.
class _InventoryHistoryActions extends StatelessWidget {
  const _InventoryHistoryActions({
    required this.palette,
    required this.view,
    required this.count,
    required this.exporting,
    required this.canExport,
    required this.onViewChanged,
    required this.onExport,
  });

  final AppPalette palette;
  final _InventoryHistoryView view;
  final int count;
  final bool exporting;
  final bool canExport;
  final ValueChanged<_InventoryHistoryView> onViewChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: palette.panelDecoration(baseRadius: 19, elevated: false),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial detallado de conteos',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count productos contados en las jornadas visibles. '
                  'El stock actual del sistema se consulta por separado '
                  'sin usar los conteos físicos.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.view_agenda_outlined, size: 17),
                  label: const Text('Tarjetas'),
                  selected: view == _InventoryHistoryView.cards,
                  onSelected: (_) => onViewChanged(_InventoryHistoryView.cards),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.table_rows_rounded, size: 17),
                  label: const Text('Tabla'),
                  selected: view == _InventoryHistoryView.table,
                  onSelected: (_) => onViewChanged(_InventoryHistoryView.table),
                ),
                FilledButton.icon(
                  onPressed: canExport && !exporting ? onExport : null,
                  icon: exporting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_view_rounded, size: 18),
                  label: Text(exporting ? 'Generando Excel' : 'Descargar Excel'),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 10),
                Flexible(child: actions),
              ],
            );
          },
        ),
      );
}

/// Tabla completa: horizontal en móvil, encabezados claros y valores numéricos
/// comparables para cada producto, incluso cuando diferencia = 0.
class _InventoryAuditTable extends StatelessWidget {
  const _InventoryAuditTable({
    required this.rows,
    required this.palette,
  });

  final List<_InventoryAuditRow> rows;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    Text number(String text, {Color? color, bool bold = false}) => Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 2,
          style: TextStyle(
            color: color ?? palette.textPrimary,
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        );

    DataColumn column(String label, {bool numeric = true}) => DataColumn(
          numeric: numeric,
          label: Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        );

    return Container(
      decoration: palette.panelDecoration(
        baseRadius: 17, tint: palette.secondary, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
            child: Row(
              children: [
                Icon(Icons.swipe_rounded,
                    color: palette.textSecondary, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Tabla de productos: desliza horizontalmente para ver '
                    'cantidades, stock del sistema y valores históricos.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 50,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              horizontalMargin: 14,
              columnSpacing: 24,
              dividerThickness: .6,
              headingRowColor:
                  MaterialStateProperty.all(palette.secondary.withOpacity(.08)),
              columns: [
                column('Producto', numeric: false),
                column('Base del conteo'),
                column('Contado'),
                column('Diferencia'),
                column('Stock actual sistema'),
                column('Costo unidad'),
                column('Valor esperado'),
                column('Valor contado'),
                column('Impacto'),
                column('Estado', numeric: false),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    key: ValueKey('producto-conteo-${rows[i].countId}'),
                    color: MaterialStateProperty.all(
                      i.isEven
                          ? palette.background.withOpacity(.08)
                          : palette.secondary.withOpacity(.035),
                    ),
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 205,
                          child: Text(
                            rows[i].product,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(number(_qty(rows[i].expected))),
                      DataCell(number(_qty(rows[i].counted), bold: true)),
                      DataCell(number(
                        _signedQty(rows[i].difference),
                        color: rows[i].hasDifference
                            ? rows[i].difference < 0
                                ? Colors.redAccent
                                : palette.success
                            : palette.textSecondary,
                        bold: rows[i].hasDifference,
                      )),
                      DataCell(
                        Tooltip(
                          message: rows[i].hasCurrentSystemStock
                              ? 'Existencia operativa sin registros de conteo físico'
                              : 'No existen movimientos operativos para este producto',
                          child: number(
                            rows[i].hasCurrentSystemStock
                                ? _qty(rows[i].currentSystemStock)
                                : 'Sin movimientos',
                            color: palette.secondary,
                            bold: true,
                          ),
                        ),
                      ),
                      DataCell(number(CurrencyUtils.format(rows[i].unitPurchaseCost))),
                      DataCell(number(CurrencyUtils.format(rows[i].expectedValue))),
                      DataCell(number(CurrencyUtils.format(rows[i].countedValue), bold: true)),
                      DataCell(number(
                        CurrencyUtils.format(rows[i].netImpact),
                        color: rows[i].netImpact < 0
                            ? Colors.redAccent
                            : rows[i].netImpact > 0
                                ? palette.success
                                : palette.textSecondary,
                      )),
                      DataCell(
                        Text(
                          _statusLabel(rows[i].status),
                          style: TextStyle(
                            color: rows[i].hasDifference
                                ? palette.warning
                                : palette.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountDayCard extends StatefulWidget {
  const _CountDayCard({
    super.key,
    required this.day,
    required this.palette,
    required this.tableView,
    required this.expandInitially,
    required this.onReview,
    required this.onExportExcel,
  });

  final _InventoryCountDay day;
  final AppPalette palette;
  final bool tableView;
  final bool expandInitially;
  final VoidCallback? onReview;
  final VoidCallback? onExportExcel;

  @override
  State<_CountDayCard> createState() => _CountDayCardState();
}

class _CountDayCardState extends State<_CountDayCard> {
  // El historial debe mostrar por defecto todos los productos contados,
  // incluidos los que coinciden exactamente con el stock esperado.
  bool _onlyDifferences = false;
  final _productSearch = TextEditingController();

  @override
  void dispose() {
    _productSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final palette = widget.palette;
    final onReview = widget.onReview;
    final visibleRows = day.rows.where((row) =>
        (!_onlyDifferences || row.hasDifference) &&
        matchesCountHistoryRow(
          productId: row.productId,
          countId: row.countId,
          productName: row.product,
          query: _productSearch.text,
        )).toList(growable: false);

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
            initiallyExpanded: widget.expandInitially,
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
                          text: '${day.rows.length} productos contados · ${day.exactCount} sin diferencia · Abrir detalle',
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
                          text: '${day.rows.length} productos contados · ${day.exactCount} sin diferencia · Abrir detalle',
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
              Text(
                'Historial completo de productos registrados en la jornada, '
                'incluyendo los que coinciden con el inventario esperado.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('inventory-count-day-product-search'),
                controller: _productSearch,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar producto en esta jornada',
                  hintText: 'Nombre o número de conteo',
                  prefixIcon: Icon(Icons.search_rounded,
                    color: palette.secondary),
                  suffixIcon: _productSearch.text.isEmpty ? null : IconButton(
                    tooltip: 'Limpiar producto de esta jornada',
                    onPressed: () {
                      _productSearch.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('Todos los contados (${day.rows.length})'),
                    selected: !_onlyDifferences,
                    onSelected: (selected) {
                      if (selected) setState(() => _onlyDifferences = false);
                    },
                  ),
                  ChoiceChip(
                    label: Text('Solo diferencias (${day.differenceCount})'),
                    selected: _onlyDifferences,
                    onSelected: (selected) {
                      if (selected) setState(() => _onlyDifferences = true);
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onExportExcel,
                    icon: const Icon(Icons.file_download_outlined, size: 17),
                    label: const Text('Excel de esta jornada'),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (_productSearch.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${visibleRows.length} producto(s) encontrados '
                    'en el conteo del ${DateFormat('dd/MM/yyyy').format(day.date)}.',
                    style: TextStyle(
                      color: palette.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (visibleRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _productSearch.text.trim().isNotEmpty
                        ? 'No se registró ningún producto que coincida '
                          'con la búsqueda en esta jornada.'
                        : 'No hay productos con diferencias para este filtro.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (widget.tableView && visibleRows.isNotEmpty)
                _InventoryAuditTable(
                  rows: visibleRows,
                  palette: palette,
                )
              else if (!widget.tableView)
                for (var index = 0; index < visibleRows.length; index++) ...[
                  _ProductAuditRow(
                    row: visibleRows[index],
                    palette: palette,
                  ),
                  if (index != visibleRows.length - 1)
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
                  decoration: palette.panelDecoration(
                    baseRadius: 14, tint: item.$3, elevated: false),
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
      'ANULADO' => palette.warning,
      'SUPERADO' => palette.textSecondary,
      _ => palette.secondary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: palette.panelDecoration(
        baseRadius: 16, tint: statusColor, elevated: false),
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
                label: row.usesCurrentStock ? 'Stock actual' : 'Esperado histórico',
                value: _qty(row.expected),
                palette: palette,
              ),
              if (row.usesCurrentStock &&
                  (row.historicalExpected - row.expected).abs() > 0.0001)
                _AuditValue(
                  label: 'Referencia histórica guardada',
                  value: _qty(row.historicalExpected),
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
                label: 'Stock actual del sistema',
                value: row.hasCurrentSystemStock
                    ? _qty(row.currentSystemStock)
                    : 'Sin movimientos',
                palette: palette,
                color: palette.secondary,
              ),
              _AuditValue(
                label: 'Costo unitario',
                value: CurrencyUtils.format(row.unitPurchaseCost),
                palette: palette,
              ),
              _AuditValue(
                label: 'Valor esperado',
                value: CurrencyUtils.format(row.expectedValue),
                palette: palette,
              ),
              _AuditValue(
                label: 'Valor contado',
                value: CurrencyUtils.format(row.countedValue),
                palette: palette,
                color: palette.secondary,
              ),
              _AuditValue(
                label: 'Impacto en valor',
                value: CurrencyUtils.format(row.netImpact),
                palette: palette,
                color: row.hasDifference
                    ? (row.netImpact < 0 ? Colors.redAccent : palette.success)
                    : palette.textSecondary,
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
          const SizedBox(height: 7),
          Text(
            row.hasCurrentSystemStock
                ? 'Stock actual sin incluir conteos físicos'
                    '${row.currentSystemStockDate == null ? '' : ' · Actualizado ${DateFormat('dd/MM/yyyy HH:mm').format(row.currentSystemStockDate!)}'}'
                : 'Sin movimientos operativos para calcular stock '
                    'actual excluyendo conteos físicos.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
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
      'ANULADO' => 'ANULADO · PUEDE REVISARSE',
      'SUPERADO' => 'HISTÓRICO',
      _ => 'CUADRA',
    };
