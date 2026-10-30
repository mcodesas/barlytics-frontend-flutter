import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../productos/data/models/productos_response_model.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/inventario_response_model.dart';
import '../providers/inventario_conteo_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

enum _ConteoFilter { pendientes, registrados, todos }

class InventarioListPage extends ConsumerStatefulWidget {
  const InventarioListPage({super.key});

  @override
  ConsumerState<InventarioListPage> createState() =>
      _InventarioListPageState();
}

class _InventarioListPageState extends ConsumerState<InventarioListPage> {
  final _searchController = TextEditingController();
  final Set<int> _justCompleted = <int>{};
  _ConteoFilter _filter = _ConteoFilter.pendientes;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(planCapabilitiesProvider).valueOrNull;
    if (entitlement != null && !entitlement.includes('INVENTARIO')) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Esta funcionalidad no está incluida en tu plan actual.')),
      );
    }
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final state = ref.watch(inventarioConteoProvider);
    final loading = branchState.loading || state.loading;
    final failure = branchState.failure ?? state.failure;

    if (loading && state.productos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(child: Center(child: AppLoader())),
      );
    }

    if (failure != null && state.productos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: Center(
            child: AppErrorView(
              message: failure.message,
              onRetry: _refreshInventory,
            ),
          ),
        ),
      );
    }

    final total = state.productos.length;
    final completed = state.productos
        .where(
          (product) => state.registrosHoy.containsKey(product.prodId),
        )
        .length;
    final pending = math.max(0, total - completed).toInt();
    final progress = total == 0 ? 0.0 : completed / total;
    final query = _searchController.text.trim().toLowerCase();
    final diferenciasPendientes =
        state.conteosPendientes.values.toList(growable: false)
          ..sort((a, b) {
            final ad = DateTime.tryParse(a.invtFecha ?? '');
            final bd = DateTime.tryParse(b.invtFecha ?? '');
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return ad.compareTo(bd);
          });

    final visible = state.productos.where((product) {
      final id = product.prodId;
      final isCompleted = id != null && state.registrosHoy.containsKey(id);
      final keepDuringAnimation = id != null && _justCompleted.contains(id);
      final matchesStatus = switch (_filter) {
        _ConteoFilter.pendientes => !isCompleted || keepDuringAnimation,
        _ConteoFilter.registrados => isCompleted,
        _ConteoFilter.todos => true,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      final haystack = [
        product.prodNombre,
        product.prodDescripcion,
        product.prodId?.toString(),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    visible.sort((a, b) {
      if (_filter == _ConteoFilter.todos) {
        final aCompleted = state.registrosHoy.containsKey(a.prodId);
        final bCompleted = state.registrosHoy.containsKey(b.prodId);
        if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
      }
      return (a.prodNombre ?? '').toLowerCase().compareTo(
            (b.prodNombre ?? '').toLowerCase(),
          );
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _refreshInventory,
          color: palette.secondary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (branchState.branches.length > 1)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _InventoryBranchSelector(
                          palette: palette,
                          branches: branchState.branches,
                          activeBranchId: branchState.activeBranchId,
                          onChanged: _changeBranch,
                        ),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _InventoryProgressHeader(
                        palette: palette,
                        total: total,
                        completed: completed,
                        pending: pending,
                        progress: progress,
                        branchName: branchState.activeBranch?.sucuNombre,
                        lastUpdated: state.actualizadoEn,
                        lastCountAt: state.ultimoConteoEn,
                        pendingReconciliations:
                            state.conteosPendientes.length,
                        refreshing: loading,
                        onRefresh: _refreshInventory,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _InventoryToolbar(
                        palette: palette,
                        searchController: _searchController,
                        selected: _filter,
                        pending: pending,
                        completed: completed,
                        total: total,
                        onSearchChanged: (_) => setState(() {}),
                        onFilterChanged: (value) =>
                            setState(() => _filter = value),
                      ),
                    ),
                  ),
                ),
              ),
              if (diferenciasPendientes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _InventoryReconcileBanner(
                          palette: palette,
                          differences: diferenciasPendientes.length,
                          onPressed: loading ? null : () => _openReconcileDialog(context, diferenciasPendientes, state.productos),
                        ),
                      ),
                    ),
                  ),
                ),
              if (failure != null)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _InlineError(
                          message: failure!.message,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _InventoryEmptyState(
                      palette: palette,
                      filter: _filter,
                      hasQuery: query.isNotEmpty,
                      onShowCompleted: () => setState(
                        () => _filter = _ConteoFilter.registrados,
                      ),
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      final productId = product.prodId;
                      final record = productId == null
                          ? null
                          : state.registrosHoy[productId];
                      final lastCount = productId == null
                          ? null
                          : state.ultimosConteos[productId];
                      final justCompleted = productId != null &&
                          _justCompleted.contains(productId);
                      final saving = productId != null &&
                          state.guardandoProductos.contains(productId);

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1088),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index == visible.length - 1 ? 0 : 10,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              child: _InventoryProductRow(
                                key: ValueKey(
                                  '${product.prodId}-${record?.invtId}-${justCompleted ? 'done' : 'normal'}',
                                ),
                                product: product,
                                record: record,
                                lastCount: lastCount,
                                palette: palette,
                                saving: saving,
                                justCompleted: justCompleted,
                                onCount: saving
                                    ? null
                                    : () => _openCountSheet(
                                          context,
                                          product,
                                          record,
                                        ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshInventory() async {
    await ref.read(branchScopeProvider.notifier).load();
    if (!mounted) return;
    await ref.read(inventarioConteoProvider.notifier).load();
  }

  Future<void> _changeBranch(int? branchId) async {
    final currentBranchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null || branchId == currentBranchId) return;

    final inventoryState = ref.read(inventarioConteoProvider);
    if (inventoryState.guardandoProductos.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Espera a que termine el registro actual antes de cambiar de sucursal.',
          ),
        ),
      );
      return;
    }

    await ref.read(branchScopeProvider.notifier).select(branchId);
    if (!mounted) return;
    _searchController.clear();
    setState(() {
      _filter = _ConteoFilter.pendientes;
      _justCompleted.clear();
    });
  }

  Future<void> _openCountSheet(
    BuildContext context,
    ProductosResponseModel product,
    InventarioResponseModel? previousRecord,
  ) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final quantity = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.68),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.none,
      builder: (sheetContext) => _InventoryCountSheet(
        product: product,
        previousRecord: previousRecord,
        palette: palette,
      ),
    );

    if (quantity == null || !mounted) return;
    final ok = await ref
        .read(inventarioConteoProvider.notifier)
        .registrarConteo(producto: product, cantidad: quantity);
    if (!mounted) return;

    if (!ok) {
      final message = ref.read(inventarioConteoProvider).failure?.message ??
          'No fue posible registrar el conteo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final id = product.prodId;
    if (id != null) {
      setState(() => _justCompleted.add(id));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _justCompleted.remove(id));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.prodNombre ?? 'Producto'} registrado: ${_formatQuantity(quantity)} unidades.',
        ),
      ),
    );
  }

  Future<void> _openReconcileDialog(BuildContext context, List<InventarioResponseModel> differences, List<ProductosResponseModel> products) async {
    final observation = TextEditingController();
    String reason = 'Diferencia de conteo';
    final palette = ref.read(selectedAppPaletteProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
      scrollable: true,
          title: const Text('Sincronizar diferencias'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Se conciliará cada diferencia contra su último conteo físico. '
                  'Si el conteo fue hace varios días, las ventas, compras y demás movimientos posteriores se conservan; '
                  'solo se registra la diferencia detectada en ese conteo.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ...differences.map((record) {
                  ProductosResponseModel? product;
                  for (final item in products) {
                    if (item.prodId == record.prodId) { product = item; break; }
                  }
                  final diff = record.invtDiferencia ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(diff > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: diff > 0 ? palette.success : palette.warning),
                    title: Text(product?.prodNombre ?? 'Producto ${record.prodId}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      'Conteo ${_shortDate(record.invtFecha)} · '
                      'Sistema ${_formatQuantity(record.invtCantidadEsperada ?? 0)} · '
                      'Físico ${_formatQuantity(record.invtCantidad ?? 0)} · '
                      'Diferencia ${diff > 0 ? '+' : ''}${_formatQuantity(diff)}',
                    ),
                  );
                }),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Motivo del ajuste'),
                  items: const ['Diferencia de conteo','Merma','Rotura','Consumo interno','Pérdida','Sobrante','Error de registro','Otro']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) { if (value != null) setDialogState(() => reason = value); },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: observation,
                  onChanged: (_) => setDialogState(() {}),
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Sustentación obligatoria', hintText: 'Explica por qué se ajustará el inventario.'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: observation.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sincronizar inventario'),
            ),
          ],
        ),
      ),
    );
    final note = observation.text.trim();
    if (confirmed != true || note.isEmpty || !mounted) return;
    final ok = await ref.read(inventarioConteoProvider.notifier).sincronizarDiferencias(
      registros: differences, motivo: reason, observacion: note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Inventario sincronizado. Los ajustes quedaron registrados en movimientos.'
          : (ref.read(inventarioConteoProvider).failure?.message ?? 'No fue posible sincronizar el inventario.')),
    ));
  }
}

class _InventoryReconcileBanner extends StatelessWidget {
  const _InventoryReconcileBanner({required this.palette, required this.differences, required this.onPressed});
  final AppPalette palette;
  final int differences;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.warning, elevated: false),
      child: LayoutBuilder(builder: (context, constraints) {
        final info = Row(children: [
          Icon(Icons.sync_problem_rounded, color: palette.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$differences diferencia(s) por conciliar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              'Puede incluir conteos de días anteriores. Al conciliar se conservan todos los movimientos posteriores al conteo.',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ])),
        ]);
        final button = FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.sync_rounded), label: const Text('Conciliar conteos'));
        if (constraints.maxWidth < 650) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 12), button]);
        }
        return Row(children: [Expanded(child: info), const SizedBox(width: 16), button]);
      }),
    );
  }
}

class _InventoryBranchSelector extends StatelessWidget {
  const _InventoryBranchSelector({
    required this.palette,
    required this.branches,
    required this.activeBranchId,
    required this.onChanged,
  });

  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (branches.length <= 1) return const SizedBox.shrink();
    SucursalesResponseModel? activeBranch;
    for (final branch in branches) {
      if (branch.sucuId == activeBranchId) {
        activeBranch = branch;
        break;
      }
    }

    final selector = DropdownButtonFormField<int>(
      value: branches.any((branch) => branch.sucuId == activeBranchId)
          ? activeBranchId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sucursal del inventario',
        prefixIcon: Icon(Icons.storefront_rounded),
      ).compactFilter(),
      hint: const Text('Selecciona una sucursal'),
      items: branches
          .where((branch) => branch.sucuId != null)
          .map(
            (branch) => DropdownMenuItem<int>(
              value: branch.sucuId!,
              child: Text(
                branch.sucuNombre?.trim().isNotEmpty == true
                    ? branch.sucuNombre!.trim()
                    : 'Sucursal ${branch.sucuId}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: branches.length <= 1 ? null : onChanged,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 22,
        tint: palette.secondary,
        elevated: false,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final description = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: palette.secondary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeBranch?.sucuNombre?.trim().isNotEmpty == true
                          ? activeBranch!.sucuNombre!.trim()
                          : 'Selecciona la sede que vas a contar',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'La lista, el progreso y los productos contados se manejan por separado para cada sucursal.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                const SizedBox(height: 12),
                selector,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: description),
              const SizedBox(width: 18),
              SizedBox(width: 310, child: selector),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryProgressHeader extends StatelessWidget {
  const _InventoryProgressHeader({
    required this.palette,
    required this.total,
    required this.completed,
    required this.pending,
    required this.progress,
    required this.branchName,
    required this.lastUpdated,
    required this.lastCountAt,
    required this.pendingReconciliations,
    required this.refreshing,
    required this.onRefresh,
  });

  final AppPalette palette;
  final int total;
  final int completed;
  final int pending;
  final double progress;
  final String? branchName;
  final DateTime? lastUpdated;
  final DateTime? lastCountAt;
  final int pendingReconciliations;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(
        baseRadius: 28,
        tint: pending == 0 ? palette.success : palette.secondary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (pending == 0 ? palette.success : palette.secondary)
                          .withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      pending == 0
                          ? Icons.task_alt_rounded
                          : Icons.fact_check_rounded,
                      color: pending == 0 ? palette.success : palette.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pending == 0 && completed > 0
                              ? 'Conteo físico completado hoy'
                              : completed > 0
                                  ? 'Conteo físico en curso'
                                  : 'Conteo físico de inventario',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          completed == 0
                              ? 'Realízalo cuando corresponda a tu operación: diario, semanal, quincenal o mensual. ${_lastCountText(lastCountAt)}'
                              : pending == 0
                                  ? 'Todos los productos de ${_branchLabel(branchName)} quedaron registrados hoy. ${_lastCountText(lastCountAt)}'
                                  : 'Jornada de conteo en curso en ${_branchLabel(branchName)}. Puedes continuar después sin perder el último conteo registrado.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1).toDouble(),
                        minHeight: 10,
                        backgroundColor: palette.background.withOpacity(0.5),
                        color: pending == 0 ? palette.success : palette.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$completed de $total productos contados hoy${lastUpdated == null ? '' : ' · Actualizado ${_formatTime(lastUpdated!)}'}',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          );

          final counters = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniCounter(
                palette: palette,
                icon: Icons.pending_actions_rounded,
                label: 'Sin contar hoy',
                value: '$pending',
                color: palette.warning,
              ),
              _MiniCounter(
                palette: palette,
                icon: Icons.check_circle_rounded,
                label: 'Contados hoy',
                value: '$completed',
                color: palette.success,
              ),
              if (pendingReconciliations > 0)
                _MiniCounter(
                  palette: palette,
                  icon: Icons.sync_problem_rounded,
                  label: 'Por conciliar',
                  value: '$pendingReconciliations',
                  color: palette.warning,
                ),
              IconButton.filledTonal(
                tooltip: 'Actualizar inventario',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [main, const SizedBox(height: 14), counters],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: main),
              const SizedBox(width: 18),
              counters,
            ],
          );
        },
      ),
    );
  }
}

class _MiniCounter extends StatelessWidget {
  const _MiniCounter({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
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
    );
  }
}

class _InventoryToolbar extends StatelessWidget {
  const _InventoryToolbar({
    required this.palette,
    required this.searchController,
    required this.selected,
    required this.pending,
    required this.completed,
    required this.total,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final AppPalette palette;
  final TextEditingController searchController;
  final _ConteoFilter selected;
  final int pending;
  final int completed;
  final int total;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ConteoFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: searchController,
            onChanged: onSearchChanged,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar producto o código',
              prefixIcon: Icon(Icons.search_rounded, color: palette.secondary),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: palette.darkBackground
                  ? Colors.white.withOpacity(0.04)
                  : palette.background.withOpacity(0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ).compactFilter(),
          );

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterButton(
                palette: palette,
                label: 'Pendientes',
                count: pending,
                icon: Icons.radio_button_unchecked_rounded,
                selected: selected == _ConteoFilter.pendientes,
                onTap: () => onFilterChanged(_ConteoFilter.pendientes),
              ),
              _FilterButton(
                palette: palette,
                label: 'Contados',
                count: completed,
                icon: Icons.check_circle_rounded,
                selected: selected == _ConteoFilter.registrados,
                onTap: () => onFilterChanged(_ConteoFilter.registrados),
              ),
              _FilterButton(
                palette: palette,
                label: 'Todos',
                count: total,
                icon: Icons.inventory_2_rounded,
                selected: selected == _ConteoFilter.todos,
                onTap: () => onFilterChanged(_ConteoFilter.todos),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 10), filters],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.palette,
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? palette.secondary.withOpacity(0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? palette.secondary.withOpacity(0.35)
                  : palette.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? palette.secondary : palette.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.secondary : palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? palette.secondary.withOpacity(0.18)
                      : palette.background.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? palette.secondary : palette.textSecondary,
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

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({
    super.key,
    required this.product,
    required this.record,
    required this.lastCount,
    required this.palette,
    required this.saving,
    required this.justCompleted,
    required this.onCount,
  });

  final ProductosResponseModel product;
  final InventarioResponseModel? record;
  final InventarioResponseModel? lastCount;
  final AppPalette palette;
  final bool saving;
  final bool justCompleted;
  final VoidCallback? onCount;

  @override
  Widget build(BuildContext context) {
    final completed = record != null;
    final accent = completed ? palette.success : palette.secondary;
    final counted = record?.invtCantidad;
    final current = product.inventarioActual ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: completed
            ? LinearGradient(
                colors: [
                  palette.success.withOpacity(justCompleted ? 0.22 : 0.11),
                  palette.surface.withOpacity(0.96),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : palette.panelGradient(tint: palette.secondary),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: completed
              ? palette.success.withOpacity(justCompleted ? 0.55 : 0.25)
              : palette.cardBorder,
          width: justCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(completed ? 0.18 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withOpacity(completed ? 0.5 : 0.24),
                  ),
                ),
                child: saving
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      )
                    : Icon(
                        completed
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: accent,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 11),
              _InventoryProductImage(
                value: product.prodFoto,
                palette: palette,
                size: compact ? 56 : 62,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (product.prodNombre ?? '').trim().isEmpty
                          ? 'Producto sin nombre'
                          : product.prodNombre!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _InventoryInfoChip(
                          palette: palette,
                          icon: Icons.qr_code_2_rounded,
                          label: 'Código ${product.prodId ?? '-'}',
                        ),
                        _InventoryInfoChip(
                          palette: palette,
                          icon: Icons.storage_rounded,
                          label: 'Sistema ${_formatQuantity(current)}',
                        ),
                        if (completed)
                          _InventoryInfoChip(
                            palette: palette,
                            icon: Icons.fact_check_rounded,
                            label: 'Contado ${_formatQuantity(counted ?? 0)}',
                            color: palette.success,
                          )
                        else if (lastCount != null)
                          _InventoryInfoChip(
                            palette: palette,
                            icon: Icons.history_rounded,
                            label:
                                'Último conteo ${_formatQuantity(lastCount!.invtCantidad ?? 0)} · ${_shortDate(lastCount!.invtFecha)}',
                            color: palette.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final action = completed
              ? Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      justCompleted ? 'Registrado' : 'Contado hoy',
                      style: TextStyle(
                        color: palette.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatRecordTime(record),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onCount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.success,
                        side: BorderSide(
                          color: palette.success.withOpacity(0.28),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Recontar'),
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: onCount,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.actionColor,
                    foregroundColor: palette.onAction,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.fact_check_rounded, size: 18),
                  label: Text(
                    lastCount == null ? 'Registrar conteo' : 'Nuevo conteo',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                action,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _InventoryInfoChip extends StatelessWidget {
  const _InventoryInfoChip({
    required this.palette,
    required this.icon,
    required this.label,
    this.color,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? palette.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryProductImage extends StatelessWidget {
  const _InventoryProductImage({
    required this.value,
    required this.palette,
    required this.size,
  });

  final String? value;
  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageValue = (value ?? '').trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.local_bar_rounded, color: palette.secondary),
    );

    if (imageValue.isEmpty) return placeholder;

    Widget image;
    if (imageValue.startsWith('data:image')) {
      final comma = imageValue.indexOf(',');
      if (comma < 0) return placeholder;
      try {
        image = Image.memory(
          base64Decode(imageValue.substring(comma + 1)),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    } else {
      image = Image.network(
        imageValue,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.16),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }
}

class _InventoryCountSheet extends StatefulWidget {
  const _InventoryCountSheet({
    required this.product,
    required this.previousRecord,
    required this.palette,
  });

  final ProductosResponseModel product;
  final InventarioResponseModel? previousRecord;
  final AppPalette palette;

  @override
  State<_InventoryCountSheet> createState() => _InventoryCountSheetState();
}

class _InventoryCountSheetState extends State<_InventoryCountSheet> {
  late final TextEditingController _controller;
  double? _value;

  @override
  void initState() {
    super.initState();
    final previous = widget.previousRecord?.invtCantidad;
    _controller = TextEditingController(
      text: previous == null ? '' : _formatQuantity(previous),
    );
    _value = previous;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final systemStock = widget.previousRecord?.invtCantidadEsperada ??
        widget.product.inventarioActual ??
        0;
    final difference = _value == null ? null : _value! - systemStock;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: palette.textSecondary.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InventoryProductImage(
                                value: widget.product.prodFoto,
                                palette: palette,
                                size: 72,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.previousRecord == null
                                          ? 'Registrar conteo'
                                          : 'Recontar producto',
                                      style: TextStyle(
                                        color: palette.secondary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      widget.product.prodNombre ??
                                          'Producto sin nombre',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 19,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Stock del sistema: ${_formatQuantity(systemStock)} unidades',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Cantidad física encontrada',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StepperButton(
                                palette: palette,
                                icon: Icons.remove_rounded,
                                onTap: () => _changeBy(-1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: InputConstraints.decimalFormatters(integerDigits: 30, fractionDigits: 0),
                                  onChanged: _parseValue,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    filled: true,
                                    fillColor: palette.darkBackground
                                        ? Colors.white.withOpacity(0.05)
                                        : palette.background.withOpacity(0.72),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixText: 'unid.',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StepperButton(
                                palette: palette,
                                icon: Icons.add_rounded,
                                onTap: () => _changeBy(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _QuickCountButton(
                                palette: palette,
                                label: '0',
                                onTap: () => _setValue(0),
                              ),
                              _QuickCountButton(
                                palette: palette,
                                label: '5',
                                onTap: () => _setValue(5),
                              ),
                              _QuickCountButton(
                                palette: palette,
                                label: '10',
                                onTap: () => _setValue(10),
                              ),
                              _QuickCountButton(
                                palette: palette,
                                label: '20',
                                onTap: () => _setValue(20),
                              ),
                              _QuickCountButton(
                                palette: palette,
                                label: 'Usar sistema',
                                icon: Icons.content_copy_rounded,
                                onTap: () => _setValue(systemStock.toDouble()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DifferencePreview(
                            palette: palette,
                            systemStock: systemStock.toDouble(),
                            counted: _value,
                            difference: difference,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.textPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _value == null || _value! < 0
                                      ? null
                                      : () => Navigator.of(context).pop(_value),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: palette.actionColor,
                                    foregroundColor: palette.onAction,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: Text(
                                    widget.previousRecord == null
                                        ? 'Confirmar conteo'
                                        : 'Actualizar conteo',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _parseValue(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() => _value = parsed);
  }

  void _setValue(double value) {
    final normalized = math.max(0, value).toDouble();
    _controller.text = _formatQuantity(normalized);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _value = normalized);
  }

  void _changeBy(double delta) {
    _setValue((_value ?? 0) + delta);
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.palette,
    required this.icon,
    required this.onTap,
  });

  final AppPalette palette;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.secondary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 52,
          height: 56,
          child: Icon(icon, color: palette.secondary, size: 25),
        ),
      ),
    );
  }
}

class _QuickCountButton extends StatelessWidget {
  const _QuickCountButton({
    required this.palette,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final AppPalette palette;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: icon == null ? null : Icon(icon, size: 16, color: palette.secondary),
      label: Text(label),
      labelStyle: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: palette.secondary.withOpacity(0.08),
      side: BorderSide(color: palette.secondary.withOpacity(0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _DifferencePreview extends StatelessWidget {
  const _DifferencePreview({
    required this.palette,
    required this.systemStock,
    required this.counted,
    required this.difference,
  });

  final AppPalette palette;
  final double systemStock;
  final double? counted;
  final double? difference;

  @override
  Widget build(BuildContext context) {
    final isEmpty = counted == null || difference == null;
    final isBalanced = !isEmpty && difference!.abs() < 0.0001;
    final positive = !isEmpty && difference! > 0;
    final color = isEmpty
        ? palette.textSecondary
        : isBalanced
            ? palette.success
            : positive
                ? palette.secondary
                : palette.warning;
    final message = isEmpty
        ? 'Ingresa la cantidad para comparar con el sistema.'
        : isBalanced
            ? 'El conteo coincide con el sistema.'
            : positive
                ? 'Sobran ${_formatQuantity(difference!)} unidades frente al sistema.'
                : 'Faltan ${_formatQuantity(difference!.abs())} unidades frente al sistema.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmpty
                  ? Icons.compare_arrows_rounded
                  : isBalanced
                      ? Icons.check_circle_rounded
                      : Icons.rule_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sistema ${_formatQuantity(systemStock)} · Físico ${counted == null ? '-' : _formatQuantity(counted!)}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({
    required this.palette,
    required this.filter,
    required this.hasQuery,
    required this.onShowCompleted,
    required this.onClearSearch,
  });

  final AppPalette palette;
  final _ConteoFilter filter;
  final bool hasQuery;
  final VoidCallback onShowCompleted;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final completed = filter == _ConteoFilter.pendientes && !hasQuery;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: palette.panelDecoration(
            baseRadius: 26,
            tint: completed ? palette.success : palette.secondary,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: (completed ? palette.success : palette.secondary)
                      .withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.task_alt_rounded
                      : Icons.search_off_rounded,
                  color: completed ? palette.success : palette.secondary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                completed
                    ? 'Todos los productos fueron contados hoy'
                    : 'No encontramos productos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                completed
                    ? 'La jornada de conteo de hoy está completa. El próximo conteo puede hacerse cuando corresponda a tu operación.'
                    : 'Cambia el filtro o limpia la búsqueda para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: completed ? onShowCompleted : onClearSearch,
                icon: Icon(
                  completed ? Icons.checklist_rounded : Icons.close_rounded,
                ),
                label: Text(
                  completed ? 'Ver contados hoy' : 'Limpiar búsqueda',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.palette});

  final String message;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 9),
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
}

String _formatQuantity(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String _lastCountText(DateTime? value) {
  if (value == null) return 'Aún no hay un conteo físico anterior.';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Último conteo: hoy.';
  if (days == 1) return 'Último conteo: ayer.';
  return 'Último conteo: hace $days días (${_shortDate(value.toIso8601String())}).';
}

String _shortDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return 'sin fecha';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatRecordTime(InventarioResponseModel? record) {
  final parsed = DateTime.tryParse(record?.invtFecha ?? '');
  if (parsed == null) return 'Registrado hoy';
  return 'Hoy · ${_formatTime(parsed)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour > 12
      ? value.hour - 12
      : value.hour == 0
          ? 12
          : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minute $period';
}

String _branchLabel(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? 'la sucursal seleccionada' : text;
}
