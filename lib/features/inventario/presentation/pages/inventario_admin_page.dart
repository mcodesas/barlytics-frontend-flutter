import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../movimientos/data/models/movimientos_response_model.dart';
import '../../../productos/data/models/productos_response_model.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/inventario_response_model.dart';

enum _InventoryAdminFilter { todos, pendientes, diferencias, sincronizados }

class InventarioAdminPage extends ConsumerStatefulWidget {
  const InventarioAdminPage({super.key});

  @override
  ConsumerState<InventarioAdminPage> createState() =>
      _InventarioAdminPageState();
}

class _InventarioAdminPageState extends ConsumerState<InventarioAdminPage> {
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  int? _branchId;
  DateTimeRange? _range;
  _InventoryAdminFilter _filter = _InventoryAdminFilter.todos;
  List<_CountSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
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
        _error = 'Selecciona una sucursal para administrar sus conteos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      final inventoryResponse =
          await api.get<List<InventarioResponseModel>>(
        '/api/v1/inventario/sucursal/$branchId',
        (json) => (json as List? ?? const <Object>[])
            .whereType<Map>()
            .map(
              (item) => InventarioResponseModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );

      final movementResponse =
          await api.get<List<MovimientosResponseModel>>(
        '/api/v1/movimientos/sucursal/$branchId',
        (json) => (json as List? ?? const <Object>[])
            .whereType<Map>()
            .map(
              (item) => MovimientosResponseModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );

      final products = await _loadProducts(branchId);

      final inventory = inventoryResponse.data ?? const <InventarioResponseModel>[];
      final movements = movementResponse.data ?? const <MovimientosResponseModel>[];

      final productNames = <int, String>{
        for (final product in products)
          if (product.prodId != null)
            product.prodId!:
                (product.prodNombre?.trim().isNotEmpty == true
                    ? product.prodNombre!.trim()
                    : 'Producto ${product.prodId}'),
      };

      final adjustments = <int, MovimientosResponseModel>{};
      final countPattern = RegExp(r'Conteo #(\d+)');
      for (final movement in movements) {
        final match = countPattern.firstMatch(movement.moviReferencia ?? '');
        if (match == null) continue;
        final countId = int.tryParse(match.group(1) ?? '');
        if (countId != null) adjustments[countId] = movement;
      }

      final countRecords = inventory
          .where((item) => (item.invtOrigen ?? '').startsWith('CONTEO_FISICO'))
          .toList(growable: false)
        ..sort((a, b) {
          final ad = DateTime.tryParse(a.invtFecha ?? '');
          final bd = DateTime.tryParse(b.invtFecha ?? '');
          if (ad == null && bd == null) {
            return (b.invtId ?? 0).compareTo(a.invtId ?? 0);
          }
          if (ad == null) return 1;
          if (bd == null) return -1;
          final cmp = bd.compareTo(ad);
          return cmp != 0 ? cmp : (b.invtId ?? 0).compareTo(a.invtId ?? 0);
        });

      final grouped = <String, List<_CountItem>>{};
      for (final record in countRecords) {
        final date = DateTime.tryParse(record.invtFecha ?? '');
        if (date == null) continue;

        final responsible =
            (record.invtRegistradoPor ?? '').trim().isEmpty
                ? 'Sin responsable'
                : record.invtRegistradoPor!.trim();
        final key =
            '${DateFormat('yyyy-MM-dd').format(date)}|${responsible.toLowerCase()}';

        grouped.putIfAbsent(key, () => <_CountItem>[]).add(
              _CountItem(
                record: record,
                productName:
                    productNames[record.prodId] ?? 'Producto ${record.prodId}',
                adjustment: adjustments[record.invtId],
              ),
            );
      }

      final sessions = grouped.entries.map((entry) {
        final items = entry.value;
        items.sort((a, b) => a.productName.compareTo(b.productName));
        final date =
            DateTime.tryParse(items.first.record.invtFecha ?? '') ?? DateTime.now();
        final responsible =
            (items.first.record.invtRegistradoPor ?? '').trim().isEmpty
                ? 'Sin responsable'
                : items.first.record.invtRegistradoPor!.trim();
        return _CountSession(
          key: entry.key,
          date: date,
          responsible: responsible,
          items: items,
        );
      }).toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
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

  Future<List<ProductosResponseModel>> _loadProducts(int branchId) async {
    final api = ref.read(apiClientProvider);
    final result = <ProductosResponseModel>[];
    var page = 0;

    while (page < 100) {
      final response = await api.get<ProductosPageResponseModel>(
        '/api/v1/productos/page',
        (json) => ProductosPageResponseModel.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
        queryParameters: {
          'page': page,
          'size': 100,
          'sucursalId': branchId,
          'sortBy': 'nombre',
          'direction': 'ASC',
        },
      );
      final data = response.data ?? const ProductosPageResponseModel();
      result.addAll(data.content);
      if (data.last || data.content.isEmpty) break;
      page++;
    }
    return result;
  }

  List<_CountSession> get _visibleSessions {
    final query = _searchController.text.trim().toLowerCase();

    return _sessions.where((session) {
      if (_range != null) {
        final day = DateTime(
          session.date.year,
          session.date.month,
          session.date.day,
        );
        final start = DateTime(
          _range!.start.year,
          _range!.start.month,
          _range!.start.day,
        );
        final end = DateTime(
          _range!.end.year,
          _range!.end.month,
          _range!.end.day,
        );
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      final matchesFilter = switch (_filter) {
        _InventoryAdminFilter.todos => true,
        _InventoryAdminFilter.pendientes => session.pendingCount > 0,
        _InventoryAdminFilter.diferencias => session.differenceCount > 0,
        _InventoryAdminFilter.sincronizados => session.syncedCount > 0,
      };
      if (!matchesFilter) return false;

      if (query.isEmpty) return true;
      return session.responsible.toLowerCase().contains(query) ||
          session.items.any(
            (item) =>
                item.productName.toLowerCase().contains(query) ||
                '${item.record.invtId ?? ''}'.contains(query),
          );
    }).toList(growable: false);
  }

  Future<void> _pickRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Filtrar historial de conteos',
      saveText: 'Aplicar',
    );
    if (selected != null && mounted) {
      setState(() => _range = selected);
    }
  }

  Future<void> _reconcileSession(_CountSession session) async {
    final pending = session.items.where((item) => item.pending).toList();
    if (pending.isEmpty) return;

    final observation = TextEditingController();
    var reason = 'Diferencia de conteo';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Conciliar conteos pendientes'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${pending.length} producto(s) del ${DateFormat('dd/MM/yyyy').format(session.date)} tienen diferencias pendientes.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se conservarán los movimientos posteriores al conteo. El ajuste quedará auditado con la referencia del conteo físico.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration:
                        const InputDecoration(labelText: 'Motivo del ajuste'),
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
                        setDialogState(() => reason = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observation,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Sustentación obligatoria',
                      hintText: 'Explica por qué se concilia este conteo.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: observation.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Conciliar'),
            ),
          ],
        ),
      ),
    );

    final note = observation.text.trim();
    if (confirmed != true || note.isEmpty || !mounted) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      for (final item in pending) {
        final id = item.record.invtId;
        if (id == null) continue;
        await api.post<Object?>(
          '/api/v1/inventario/sincronizar-conteo',
          {
            'invtId': id,
            'motivo': reason,
            'observacion': note,
          },
          (json) => json,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conteos conciliados. Los ajustes quedaron registrados en movimientos.',
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
        _branchId = nextId;
        _load();
      }
    });

    if (_loading && _sessions.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: Center(
            child: AppLoader(
              message: 'Cargando historial de conteos...',
            ),
          ),
        ),
      );
    }

    if (_error != null && _sessions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: AppErrorView(message: _error!, onRetry: _load),
        ),
      );
    }

    final sessions = _visibleSessions;
    final allItems = _sessions.expand((item) => item.items).toList();
    final pending = allItems.where((item) => item.pending).length;
    final synced = allItems.where((item) => item.synced).length;
    final differences = allItems.where((item) => item.hasDifference).length;

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
                  child: _AdminWidth(
                    top: 16,
                    child: _AdminHeader(
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
                      onClearRange: _range == null
                          ? null
                          : () => setState(() => _range = null),
                      onRefresh: _load,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _AdminWidth(
                    child: _AdminKpis(
                      palette: palette,
                      sessions: _sessions.length,
                      counts: allItems.length,
                      differences: differences,
                      pending: pending,
                      synced: synced,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _AdminWidth(
                    child: _AdminToolbar(
                      palette: palette,
                      controller: _searchController,
                      selected: _filter,
                      onSearch: (_) => setState(() {}),
                      onFilter: (value) => setState(() => _filter = value),
                    ),
                  ),
                ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: _AdminWidth(
                      child: _InlineAdminError(
                        palette: palette,
                        message: _error!,
                      ),
                    ),
                  ),
                if (sessions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No hay conteos que coincidan con los filtros.',
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
                      itemCount: sessions.length,
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index == sessions.length - 1 ? 0 : 10,
                            ),
                            child: _CountSessionCard(
                              session: sessions[index],
                              palette: palette,
                              onReconcile:
                                  sessions[index].pendingCount == 0 || _loading
                                      ? null
                                      : () =>
                                          _reconcileSession(sessions[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading && _sessions.isNotEmpty)
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

class _CountItem {
  const _CountItem({
    required this.record,
    required this.productName,
    required this.adjustment,
  });

  final InventarioResponseModel record;
  final String productName;
  final MovimientosResponseModel? adjustment;

  double get difference => record.invtDiferencia ?? 0;
  bool get hasDifference => difference.abs() > 0.0001;

  bool get synced =>
      record.invtOrigen == 'CONTEO_FISICO_SINCRONIZADO' ||
      adjustment != null;

  bool get pending =>
      record.invtOrigen == 'CONTEO_FISICO' && hasDifference && !synced;

  String get status {
    if (synced) return 'SINCRONIZADO';
    if (pending) return 'PENDIENTE';
    return 'CUADRA';
  }
}

class _CountSession {
  const _CountSession({
    required this.key,
    required this.date,
    required this.responsible,
    required this.items,
  });

  final String key;
  final DateTime date;
  final String responsible;
  final List<_CountItem> items;

  int get pendingCount => items.where((item) => item.pending).length;
  int get syncedCount => items.where((item) => item.synced).length;
  int get differenceCount => items.where((item) => item.hasDifference).length;
}

class _AdminWidth extends StatelessWidget {
  const _AdminWidth({
    required this.child,
    this.top = 12,
  });

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top, 16, 0),
            child: child,
          ),
        ),
      );
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.palette,
    required this.branches,
    required this.branchId,
    required this.range,
    required this.onBranchChanged,
    required this.onRange,
    required this.onClearRange,
    required this.onRefresh,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? branchId;
  final DateTimeRange? range;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback onRange;
  final VoidCallback? onClearRange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administración de inventario',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Historial de conteos físicos, diferencias, conciliaciones y ajustes de inventario.',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (branches.length > 1)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              value: branches.any((item) => item.sucuId == branchId)
                  ? branchId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sucursal',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              items: [
                ...branches.where((item) => item.sucuId != null).map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.sucuId,
                        child: Text(
                          item.sucuNombre ?? 'Sucursal ${item.sucuId}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              ],
              onChanged: onBranchChanged,
            ),
          ),
        OutlinedButton.icon(
          onPressed: onRange,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(
            range == null
                ? 'Filtrar fechas'
                : '${DateFormat('dd/MM/yy').format(range!.start)} - ${DateFormat('dd/MM/yy').format(range!.end)}',
          ),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Quitar filtro de fechas',
            onPressed: onClearRange,
            icon: const Icon(Icons.close_rounded),
          ),
        IconButton.filledTonal(
          tooltip: 'Actualizar',
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
                controls,
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                controls,
              ],
            ),
    );
  }
}

class _AdminKpis extends StatelessWidget {
  const _AdminKpis({
    required this.palette,
    required this.sessions,
    required this.counts,
    required this.differences,
    required this.pending,
    required this.synced,
  });

  final AppPalette palette;
  final int sessions;
  final int counts;
  final int differences;
  final int pending;
  final int synced;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Jornadas', '$sessions', Icons.event_note_rounded, palette.secondary),
      ('Productos contados', '$counts', Icons.fact_check_rounded, palette.success),
      ('Con diferencia', '$differences', Icons.compare_arrows_rounded, palette.warning),
      ('Pendientes', '$pending', Icons.sync_problem_rounded, Colors.orangeAccent),
      ('Sincronizados', '$synced', Icons.task_alt_rounded, Colors.teal),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600
            ? 2
            : constraints.maxWidth < 1000
                ? 3
                : 5;
        const gap = 8.0;
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
                  padding: const EdgeInsets.all(12),
                  decoration: palette.panelDecoration(
                    baseRadius: 17,
                    tint: item.$4,
                    elevated: false,
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, color: item.$4, size: 21),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              item.$1,
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
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminToolbar extends StatelessWidget {
  const _AdminToolbar({
    required this.palette,
    required this.controller,
    required this.selected,
    required this.onSearch,
    required this.onFilter,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final _InventoryAdminFilter selected;
  final ValueChanged<String> onSearch;
  final ValueChanged<_InventoryAdminFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _InventoryAdminFilter.todos: 'Todos',
      _InventoryAdminFilter.pendientes: 'Pendientes',
      _InventoryAdminFilter.diferencias: 'Con diferencias',
      _InventoryAdminFilter.sincronizados: 'Sincronizados',
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
            width: 300,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Buscar producto, responsable o conteo',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          for (final filter in _InventoryAdminFilter.values)
            ChoiceChip(
              selected: filter == selected,
              label: Text(labels[filter]!),
              onSelected: (_) => onFilter(filter),
              selectedColor: palette.secondary.withOpacity(.14),
              side: BorderSide(
                color: filter == selected
                    ? palette.secondary.withOpacity(.38)
                    : palette.cardBorder,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountSessionCard extends StatelessWidget {
  const _CountSessionCard({
    required this.session,
    required this.palette,
    required this.onReconcile,
  });

  final _CountSession session;
  final AppPalette palette;
  final VoidCallback? onReconcile;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(session.date);

    return Container(
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: session.pendingCount > 0 ? palette.warning : palette.success,
        elevated: false,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (session.pendingCount > 0
                    ? palette.warning
                    : palette.success)
                .withOpacity(.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            session.pendingCount > 0
                ? Icons.pending_actions_rounded
                : Icons.fact_check_rounded,
            color: session.pendingCount > 0
                ? palette.warning
                : palette.success,
          ),
        ),
        title: Text(
          'Conteo $date',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              _StatusText(
                icon: Icons.person_outline_rounded,
                text: session.responsible,
                palette: palette,
              ),
              _StatusText(
                icon: Icons.inventory_2_outlined,
                text: '${session.items.length} productos',
                palette: palette,
              ),
              _StatusText(
                icon: Icons.compare_arrows_rounded,
                text: '${session.differenceCount} diferencias',
                palette: palette,
              ),
              if (session.pendingCount > 0)
                _StatusText(
                  icon: Icons.sync_problem_rounded,
                  text: '${session.pendingCount} pendientes',
                  palette: palette,
                  color: palette.warning,
                ),
            ],
          ),
        ),
        trailing: onReconcile == null
            ? null
            : FilledButton.icon(
                onPressed: onReconcile,
                icon: const Icon(Icons.sync_rounded, size: 17),
                label: const Text('Conciliar'),
              ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          for (var i = 0; i < session.items.length; i++) ...[
            _CountItemRow(item: session.items[i], palette: palette),
            if (i != session.items.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.icon,
    required this.text,
    required this.palette,
    this.color,
  });

  final IconData icon;
  final String text;
  final AppPalette palette;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? palette.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? palette.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _CountItemRow extends StatelessWidget {
  const _CountItemRow({
    required this.item,
    required this.palette,
  });

  final _CountItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final diff = item.difference;
    final tone = item.pending
        ? palette.warning
        : item.synced
            ? palette.success
            : palette.secondary;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder.withOpacity(.65)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 10,
                runSpacing: 5,
                children: [
                  Text(
                    'Esperado ${_qty(item.record.invtCantidadEsperada)}',
                    style: _smallStyle(palette),
                  ),
                  Text(
                    'Contado ${_qty(item.record.invtCantidad)}',
                    style: _smallStyle(palette),
                  ),
                  Text(
                    'Diferencia ${diff > 0 ? '+' : ''}${_qty(diff)}',
                    style: TextStyle(
                      color: diff.abs() < .0001
                          ? palette.success
                          : palette.warning,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ID #${item.record.invtId ?? '-'}',
                    style: _smallStyle(palette),
                  ),
                ],
              ),
              if (item.adjustment != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Ajuste: ${item.adjustment!.moviOperacion ?? '-'} '
                  '${_qty(item.adjustment!.moviCantidad)} · '
                  '${item.adjustment!.moviMotivo ?? 'Sin motivo'}'
                  '${(item.adjustment!.moviRegistradoPor ?? '').trim().isEmpty ? '' : ' · Por ${item.adjustment!.moviRegistradoPor}'}'
                  '${item.adjustment!.moviFechaCambio == null ? '' : ' · ${_dateTime(item.adjustment!.moviFechaCambio)}'}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: tone.withOpacity(.09),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tone.withOpacity(.20)),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                color: tone,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 8),
                badge,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}

class _InlineAdminError extends StatelessWidget {
  const _InlineAdminError({
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

TextStyle _smallStyle(AppPalette palette) => TextStyle(
      color: palette.textSecondary,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
    );

String _qty(num? value) {
  final v = value?.toDouble() ?? 0;
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String _dateTime(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return raw ?? '';
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}
