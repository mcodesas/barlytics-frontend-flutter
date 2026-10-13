import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

class ComandasPage extends ConsumerStatefulWidget {
  const ComandasPage({super.key});

  @override
  ConsumerState<ComandasPage> createState() => _ComandasPageState();
}

class _ComandasPageState extends ConsumerState<ComandasPage> {
  static const _statuses = <String>[
    'NUEVA',
    'EN_PREPARACION',
    'LISTA',
    'ENTREGADA',
  ];

  List<_ComandaItem> _items = const <_ComandaItem>[];
  final Set<int> _updating = <int>{};
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  String _station = 'TODAS';
  String _mobileStatus = 'NUEVA';
  int? _loadedBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted && !silent) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        if (silent) {
          _refreshing = true;
        } else {
          _loading = true;
        }
      });
    }

    try {
      final response = await ref.read(apiClientProvider).get<List<_ComandaItem>>(
            '/api/v1/comandas',
            (json) => (json as List? ?? const <dynamic>[])
                .whereType<Map>()
                .map((item) => _ComandaItem.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList(growable: false),
            queryParameters: <String, dynamic>{
              'sucursalId': branchId,
              if (_station != 'TODAS') 'estacion': _station,
            },
          );
      if (!mounted) return;
      setState(() {
        _items = response.data ?? const <_ComandaItem>[];
        _loadedBranchId = branchId;
      });
    } catch (error) {
      if (!mounted || silent) return;
      _message('No fue posible cargar las comandas: $error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _advance(_ComandaItem item) async {
    final next = switch (item.estado) {
      'NUEVA' => 'EN_PREPARACION',
      'EN_PREPARACION' => 'LISTA',
      'LISTA' => 'ENTREGADA',
      _ => null,
    };
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (next == null || branchId == null || _updating.contains(item.detalleId)) {
      return;
    }

    setState(() => _updating.add(item.detalleId));
    try {
      final response = await ref.read(apiClientProvider).put<_ComandaItem>(
            '/api/v1/comandas/${item.detalleId}/estado'
            '?sucursalId=$branchId&estado=$next',
            null,
            (json) => _ComandaItem.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          );
      if (!mounted) return;
      final updated = response.data;
      if (updated != null) {
        setState(() {
          _items = _items
              .map((current) =>
                  current.detalleId == updated.detalleId ? updated : current)
              .where((current) =>
                  _station == 'TODAS' || current.estacion == _station)
              .toList(growable: false);
        });
      }
    } catch (error) {
      _message('No fue posible cambiar el estado de la comanda: $error',
          error: true);
    } finally {
      if (mounted) setState(() => _updating.remove(item.detalleId));
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(branchScopeProvider);
    final branchId = branch.activeBranchId;
    if (branchId != null && branchId != _loadedBranchId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && branchId != _loadedBranchId) _load();
      });
    }

    final branchName = branch.activeBranch?.sucuNombre ?? 'Sucursal activa';
    return Stack(
      children: [
        const Positioned.fill(child: AppPageBackground()),
        SafeArea(
          child: Column(
            children: [
              _Header(
                branchName: branchName,
                station: _station,
                refreshing: _refreshing,
                items: _items,
                onStationChanged: (value) {
                  if (_station == value) return;
                  setState(() => _station = value);
                  _load();
                },
                onRefresh: () => _load(silent: true),
              ),
              Expanded(
                child: _loading
                    ? const AppLoader()
                    : _items.isEmpty
                        ? const _EmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 820) {
                                return Column(
                                  children: [
                                    _MobileStatusBar(
                                      selected: _mobileStatus,
                                      items: _items,
                                      onSelected: (value) {
                                        setState(() => _mobileStatus = value);
                                      },
                                    ),
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          6,
                                          10,
                                          90,
                                        ),
                                        children: [
                                          _StatusSection(
                                            status: _mobileStatus,
                                            items: _items
                                                .where((item) =>
                                                    item.estado ==
                                                    _mobileStatus)
                                                .toList(growable: false),
                                            updating: _updating,
                                            onAdvance: _advance,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              if (constraints.maxWidth >= 1180) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 90),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (var index = 0;
                                          index < _statuses.length;
                                          index++) ...[
                                        Expanded(
                                          child: _StatusSection(
                                            status: _statuses[index],
                                            scrollable: true,
                                            items: _items
                                                .where((item) =>
                                                    item.estado ==
                                                    _statuses[index])
                                                .toList(growable: false),
                                            updating: _updating,
                                            onAdvance: _advance,
                                          ),
                                        ),
                                        if (index < _statuses.length - 1)
                                          const SizedBox(width: 10),
                                      ],
                                    ],
                                  ),
                                );
                              }

                              return SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 90),
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var index = 0;
                                        index < _statuses.length;
                                        index++) ...[
                                      SizedBox(
                                        width: 360,
                                        height: constraints.maxHeight - 16,
                                        child: _StatusSection(
                                          status: _statuses[index],
                                          scrollable: true,
                                          items: _items
                                              .where((item) =>
                                                  item.estado ==
                                                  _statuses[index])
                                              .toList(growable: false),
                                          updating: _updating,
                                          onAdvance: _advance,
                                        ),
                                      ),
                                      if (index < _statuses.length - 1)
                                        const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.branchName,
    required this.station,
    required this.refreshing,
    required this.items,
    required this.onStationChanged,
    required this.onRefresh,
  });

  final String branchName;
  final String station;
  final bool refreshing;
  final List<_ComandaItem> items;
  final ValueChanged<String> onStationChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = items.where((item) => item.estado != 'ENTREGADA').length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primaryContainer.withOpacity(.8),
                child: Icon(
                  Icons.room_service_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comandas',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$branchName · $pending pendientes',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const <String>['TODAS', 'COCINA', 'BARRA'])
                ChoiceChip(
                  selected: station == option,
                  label: Text(
                    option == 'TODAS'
                        ? 'Todas'
                        : option == 'COCINA'
                            ? 'Cocina'
                            : 'Barra',
                  ),
                  avatar: Icon(
                    option == 'COCINA'
                        ? Icons.restaurant_rounded
                        : option == 'BARRA'
                            ? Icons.local_bar_rounded
                            : Icons.dashboard_customize_rounded,
                    size: 18,
                  ),
                  onSelected: (_) => onStationChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileStatusBar extends StatelessWidget {
  const _MobileStatusBar({
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  final String selected;
  final List<_ComandaItem> items;
  final ValueChanged<String> onSelected;

  static const _statuses = <String>[
    'NUEVA',
    'EN_PREPARACION',
    'LISTA',
    'ENTREGADA',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    int countOrders(String status) {
      return items
          .where((item) => item.estado == status)
          .map((item) => '${item.ventaId}|${item.cuentaId}|${item.mesaId ?? 0}')
          .toSet()
          .length;
    }

    String label(String status) => switch (status) {
          'NUEVA' => 'Nuevas',
          'EN_PREPARACION' => 'Preparación',
          'LISTA' => 'Listas',
          _ => 'Entregadas',
        };

    IconData icon(String status) => switch (status) {
          'NUEVA' => Icons.notifications_active_outlined,
          'EN_PREPARACION' => Icons.soup_kitchen_outlined,
          'LISTA' => Icons.check_circle_outline_rounded,
          _ => Icons.room_service_outlined,
        };

    return Container(
      height: 58,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final active = status == selected;
          final count = countOrders(status);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primaryContainer.withOpacity(.9)
                    : theme.colorScheme.surface.withOpacity(.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? theme.colorScheme.primary.withOpacity(.5)
                      : theme.colorScheme.outlineVariant.withOpacity(.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon(status),
                    size: 18,
                    color: active
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label(status),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: active
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary.withOpacity(.16)
                          : theme.colorScheme.surfaceContainerHighest
                              .withOpacity(.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.status,
    required this.items,
    required this.updating,
    required this.onAdvance,
    this.scrollable = false,
  });

  final String status;
  final List<_ComandaItem> items;
  final Set<int> updating;
  final Future<void> Function(_ComandaItem) onAdvance;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupByOrder(items);
    final content = <Widget>[
      _StatusHeader(status: status, count: groupedOrders.length),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const _EmptyColumn()
      else
        ...groupedOrders.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OrderGroupCard(
              items: entry.value,
              updating: entry.value.any(
                (item) => updating.contains(item.detalleId),
              ),
              onAdvance: () async {
                for (final item in entry.value) {
                  await onAdvance(item);
                }
              },
            ),
          ),
        ),
    ];

    if (scrollable) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: _columnDecoration(context),
        child: ListView(children: content),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _columnDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      ),
    );
  }

  BoxDecoration _columnDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface.withOpacity(.82),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withOpacity(.55),
      ),
    );
  }

  Map<String, List<_ComandaItem>> _groupByOrder(List<_ComandaItem> values) {
    final result = <String, List<_ComandaItem>>{};
    for (final item in values) {
      final key = '${item.ventaId}|${item.cuentaId}|${item.mesaId ?? 0}';
      result.putIfAbsent(key, () => <_ComandaItem>[]).add(item);
    }
    for (final group in result.values) {
      group.sort((a, b) {
        final aDate = a.fechaPedido ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.fechaPedido ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }
    return result;
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status, required this.count});

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (status) {
      'NUEVA' => 'Nuevas',
      'EN_PREPARACION' => 'En preparación',
      'LISTA' => 'Listas',
      _ => 'Entregadas',
    };
    final tone = switch (status) {
      'NUEVA' => theme.colorScheme.primary,
      'EN_PREPARACION' => theme.colorScheme.tertiary,
      'LISTA' => theme.colorScheme.secondary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (status) {
      'NUEVA' => Icons.notifications_active_outlined,
      'EN_PREPARACION' => Icons.soup_kitchen_outlined,
      'LISTA' => Icons.check_circle_outline_rounded,
      _ => Icons.room_service_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.withOpacity(.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tone.withOpacity(.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableGroupHeader extends StatelessWidget {
  const _TableGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            Icons.table_restaurant_rounded,
            size: 17,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderGroupCard extends StatelessWidget {
  const _OrderGroupCard({
    required this.items,
    required this.updating,
    required this.onAdvance,
  });

  final List<_ComandaItem> items;
  final bool updating;
  final Future<void> Function() onAdvance;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final first = items.first;
    final tone = switch (first.estado) {
      'NUEVA' => theme.colorScheme.primary,
      'EN_PREPARACION' => theme.colorScheme.tertiary,
      'LISTA' => theme.colorScheme.secondary,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final tableLabel = first.mesaNumero == null
        ? 'Venta directa'
        : 'Mesa ${first.mesaNumero}${first.mesaDescripcion.trim().isEmpty ? '' : ' · ${first.mesaDescripcion.trim()}'}';
    final accountLabel = 'Cuenta ${first.cuentaNumero ?? '-'}'
        '${first.cuentaDescripcion.trim().isEmpty ? '' : ' · ${first.cuentaDescripcion.trim()}'}';
    final stationNames = items.map((item) => item.estacion).toSet();
    final stationLabel = stationNames.length == 1
        ? (stationNames.first == 'BARRA' ? 'Barra' : 'Cocina')
        : 'Cocina + Barra';

    final nextLabel = switch (first.estado) {
      'NUEVA' => 'Iniciar pedido completo',
      'EN_PREPARACION' => 'Marcar pedido como listo',
      'LISTA' => 'Marcar pedido entregado',
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            decoration: BoxDecoration(
              color: tone.withOpacity(.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      first.mesaNumero == null
                          ? Icons.point_of_sale_rounded
                          : Icons.table_restaurant_rounded,
                      size: 19,
                      color: tone,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        tableLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Pedido #${first.ventaId}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _GroupInfoChip(
                      icon: Icons.receipt_long_outlined,
                      label: accountLabel,
                    ),
                    _GroupInfoChip(
                      icon: Icons.restaurant_menu_rounded,
                      label:
                          '${items.length} producto${items.length == 1 ? '' : 's'}',
                    ),
                    _GroupInfoChip(
                      icon: stationNames.length == 1 &&
                              stationNames.first == 'BARRA'
                          ? Icons.local_bar_rounded
                          : Icons.restaurant_rounded,
                      label: stationLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _OrderProductRow(item: items[index]),
                  if (index < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withOpacity(.28),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  first.fechaPedido == null
                      ? 'Sin hora'
                      : DateFormat('HH:mm').format(first.fechaPedido!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (first.mesero.trim().isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      first.mesero,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
          if (nextLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: FilledButton.icon(
                onPressed: updating ? null : onAdvance,
                icon: updating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        first.estado == 'LISTA'
                            ? Icons.room_service_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(nextLabel),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showProductDetail(
  BuildContext context,
  _ComandaItem item,
) async {
  final theme = Theme.of(context);
  final customization = item.customization;
  final tableLabel = item.mesaNumero == null
      ? 'Venta directa'
      : 'Mesa ${item.mesaNumero}${item.mesaDescripcion.trim().isEmpty ? '' : ' · ${item.mesaDescripcion.trim()}'}';
  final accountLabel = 'Cuenta ${item.cuentaNumero ?? '-'}'
      '${item.cuentaDescripcion.trim().isEmpty ? '' : ' · ${item.cuentaDescripcion.trim()}'}';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .45,
        maxChildSize: .94,
        expand: false,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(.45),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        'x${_formatQuantity(item.cantidad)}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productoNombre,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.estacion == 'BARRA' ? 'Barra' : 'Cocina',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
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
                const SizedBox(height: 18),
                _DetailSection(
                  icon: Icons.notes_rounded,
                  title: 'Descripción completa',
                  child: Text(
                    item.productoDescripcion.trim().isEmpty
                        ? 'Sin descripción registrada'
                        : item.productoDescripcion.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (customization.removed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    icon: Icons.remove_circle_outline_rounded,
                    title: 'Sin ingredientes',
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final text in customization.removed)
                          _CompactModifier(
                            icon: Icons.remove_rounded,
                            label: text,
                            tone: theme.colorScheme.error,
                          ),
                      ],
                    ),
                  ),
                ],
                if (customization.additions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Adiciones',
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final text in customization.additions)
                          _CompactModifier(
                            icon: Icons.add_rounded,
                            label: text,
                            tone: theme.colorScheme.tertiary,
                          ),
                      ],
                    ),
                  ),
                ],
                if (customization.observation != null &&
                    customization.observation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Observaciones',
                    child: Text(
                      customization.observation!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _DetailMetaRow(
                  icon: Icons.table_restaurant_rounded,
                  label: tableLabel,
                ),
                _DetailMetaRow(
                  icon: Icons.receipt_long_outlined,
                  label: accountLabel,
                ),
                _DetailMetaRow(
                  icon: Icons.tag_rounded,
                  label: 'Pedido #${item.ventaId}',
                ),
                if (item.fechaPedido != null)
                  _DetailMetaRow(
                    icon: Icons.schedule_rounded,
                    label:
                        'Hora: ${DateFormat('HH:mm').format(item.fechaPedido!)}',
                  ),
                if (item.mesero.trim().isNotEmpty)
                  _DetailMetaRow(
                    icon: Icons.person_outline_rounded,
                    label: item.mesero,
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _OrderProductRow extends StatelessWidget {
  const _OrderProductRow({required this.item});

  final _ComandaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customization = item.customization;
    final description = item.productoDescripcion.trim();
    final kitchen = item.estacion == 'COCINA';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProductDetail(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'x${_formatQuantity(item.cantidad)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.productoNombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withOpacity(.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                kitchen
                                    ? Icons.restaurant_rounded
                                    : Icons.local_bar_rounded,
                                size: 13,
                                color:
                                    theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                kitchen ? 'Cocina' : 'Barra',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isEmpty
                          ? 'Sin descripción registrada'
                          : description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: description.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                                .withOpacity(.62)
                            : theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                        fontWeight: description.isEmpty
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                    if (customization.removed.isNotEmpty ||
                        customization.additions.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final text in customization.removed)
                            _CompactModifier(
                              icon: Icons.remove_rounded,
                              label: 'SIN $text',
                              tone: theme.colorScheme.error,
                            ),
                          for (final text in customization.additions)
                            _CompactModifier(
                              icon: Icons.add_rounded,
                              label: text,
                              tone: theme.colorScheme.tertiary,
                            ),
                        ],
                      ),
                    ],
                    if (customization.observation != null &&
                        customization.observation!.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customization.observation!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Toca para ver detalle',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: theme.colorScheme.onSurfaceVariant,
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

class _CompactModifier extends StatelessWidget {
  const _CompactModifier({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(.36),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
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
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupInfoChip extends StatelessWidget {
  const _GroupInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.item,
    required this.updating,
    required this.onAdvance,
    this.showAction = true,
  });

  final _ComandaItem item;
  final bool updating;
  final VoidCallback onAdvance;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = switch (item.estado) {
      'NUEVA' => theme.colorScheme.primary,
      'EN_PREPARACION' => theme.colorScheme.tertiary,
      'LISTA' => theme.colorScheme.secondary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final customization = item.customization;
    final removed = customization.removed;
    final additions = customization.additions;
    final observation = customization.observation;

    final nextLabel = switch (item.estado) {
      'NUEVA' => 'Iniciar preparación',
      'EN_PREPARACION' => 'Marcar como lista',
      'LISTA' => 'Marcar entregada',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tone.withOpacity(.28),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: tone.withOpacity(.11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.withOpacity(.18)),
                ),
                child: Text(
                  'x${_formatQuantity(item.cantidad)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productoNombre,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withOpacity(.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 15,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Descripción',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.productoDescripcion.trim().isEmpty
                                ? 'Sin descripción registrada'
                                : item.productoDescripcion.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.productoDescripcion.trim().isEmpty
                                  ? theme.colorScheme.onSurfaceVariant
                                      .withOpacity(.7)
                                  : theme.colorScheme.onSurface,
                              height: 1.4,
                              fontWeight: item.productoDescripcion.trim().isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Cuenta ${item.cuentaNumero ?? '-'}'
                            '${item.cuentaDescripcion.trim().isEmpty ? '' : ' · ${item.cuentaDescripcion.trim()}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StationBadge(station: item.estacion),
            ],
          ),
          if (removed.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final text in removed)
              _InstructionLine(
                icon: Icons.remove_circle_outline_rounded,
                label: 'SIN $text',
                tone: theme.colorScheme.error,
              ),
          ],
          if (additions.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final text in additions)
              _InstructionLine(
                icon: Icons.add_circle_outline_rounded,
                label: '+ $text',
                tone: theme.colorScheme.tertiary,
              ),
          ],
          if (observation != null && observation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      observation,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                item.fechaPedido == null
                    ? 'Sin hora'
                    : DateFormat('HH:mm').format(item.fechaPedido!),
                style: theme.textTheme.labelSmall,
              ),
              if (item.mesero.trim().isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.person_outline_rounded,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.mesero,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
          if (showAction && nextLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: updating ? null : onAdvance,
                icon: updating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        item.estado == 'LISTA'
                            ? Icons.room_service_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(nextLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StationBadge extends StatelessWidget {
  const _StationBadge({required this.station});

  final String station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kitchen = station == 'COCINA';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kitchen ? Icons.restaurant_rounded : Icons.local_bar_rounded,
            size: 15,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            kitchen ? 'Cocina' : 'Barra',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  const _InstructionLine({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: tone.withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.withOpacity(.16)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: tone),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Sin comandas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.room_service_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay comandas pendientes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Los productos preparados aparecerán aquí cuando se agreguen a una mesa o venta directa.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _ComandaItem {
  const _ComandaItem({
    required this.detalleId,
    required this.ventaId,
    required this.sucursalId,
    required this.mesaId,
    required this.mesaNumero,
    required this.mesaDescripcion,
    required this.cuentaId,
    required this.cuentaNumero,
    required this.cuentaDescripcion,
    required this.productoId,
    required this.productoNombre,
    required this.productoDescripcion,
    required this.cantidad,
    required this.estacion,
    required this.estado,
    required this.personalizacion,
    required this.mesero,
    required this.fechaPedido,
    required this.fechaEstado,
  });

  final int detalleId;
  final int ventaId;
  final int sucursalId;
  final int? mesaId;
  final int? mesaNumero;
  final String mesaDescripcion;
  final int cuentaId;
  final int? cuentaNumero;
  final String cuentaDescripcion;
  final int productoId;
  final String productoNombre;
  final String productoDescripcion;
  final double cantidad;
  final String estacion;
  final String estado;
  final String? personalizacion;
  final String mesero;
  final DateTime? fechaPedido;
  final DateTime? fechaEstado;

  factory _ComandaItem.fromJson(Map<String, dynamic> json) => _ComandaItem(
        detalleId: _asInt(json['detalleId']) ?? 0,
        ventaId: _asInt(json['ventaId']) ?? 0,
        sucursalId: _asInt(json['sucursalId']) ?? 0,
        mesaId: _asInt(json['mesaId']),
        mesaNumero: _asInt(json['mesaNumero']),
        mesaDescripcion: json['mesaDescripcion']?.toString() ?? '',
        cuentaId: _asInt(json['cuentaId']) ?? 0,
        cuentaNumero: _asInt(json['cuentaNumero']),
        cuentaDescripcion: json['cuentaDescripcion']?.toString() ?? '',
        productoId: _asInt(json['productoId']) ?? 0,
        productoNombre: json['productoNombre']?.toString() ?? 'Producto',
        productoDescripcion: json['productoDescripcion']?.toString() ?? '',
        cantidad: _asDouble(json['cantidad']) ?? 0,
        estacion:
            (json['estacion']?.toString() ?? 'COCINA').trim().toUpperCase(),
        estado: (json['estado']?.toString() ?? 'NUEVA').trim().toUpperCase(),
        personalizacion: json['personalizacion']?.toString(),
        mesero: json['mesero']?.toString() ?? '',
        fechaPedido: DateTime.tryParse(json['fechaPedido']?.toString() ?? ''),
        fechaEstado: DateTime.tryParse(json['fechaEstado']?.toString() ?? ''),
      );

  _Customization get customization =>
      _Customization.fromRaw(personalizacion);
}

class _Customization {
  const _Customization({
    required this.removed,
    required this.additions,
    required this.observation,
  });

  final List<String> removed;
  final List<String> additions;
  final String? observation;

  factory _Customization.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _Customization(
        removed: <String>[],
        additions: <String>[],
        observation: null,
      );
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map) {
        return const _Customization(
          removed: <String>[],
          additions: <String>[],
          observation: null,
        );
      }
      final map = Map<String, dynamic>.from(value);
      final removed = (map['quitados'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => item['nombre']?.toString() ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
      final additions = (map['adiciones'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) {
            final name = item['nombre']?.toString() ?? '';
            final quantity = _asDouble(item['cantidad']);
            final unit = item['unidad']?.toString() ?? '';
            if (quantity == null || quantity == 1) return name;
            return '${_formatQuantity(quantity)} $unit $name'.trim();
          })
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
      final observation = map['observacion']?.toString().trim();
      return _Customization(
        removed: removed,
        additions: additions,
        observation:
            observation == null || observation.isEmpty ? null : observation,
      );
    } catch (_) {
      return _Customization(
        removed: const <String>[],
        additions: const <String>[],
        observation: raw.trim(),
      );
    }
  }
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _formatQuantity(num value) {
  final number = value.toDouble();
  if (number % 1 == 0) return number.toInt().toString();
  return number.toStringAsFixed(2);
}
