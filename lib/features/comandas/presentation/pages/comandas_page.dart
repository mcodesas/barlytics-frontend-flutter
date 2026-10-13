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
                                return ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 90),
                                  children: [
                                    for (final status in _statuses) ...[
                                      _StatusSection(
                                        status: status,
                                        items: _items
                                            .where((item) =>
                                                item.estado == status)
                                            .toList(growable: false),
                                        updating: _updating,
                                        onAdvance: _advance,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ],
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
                                        width: 410,
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
                                        const SizedBox(width: 12),
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
  final ValueChanged<_ComandaItem> onAdvance;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      _StatusHeader(status: status, count: items.length),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const _EmptyColumn()
      else
        ..._groupByTable(items).entries.expand(
          (entry) => <Widget>[
            _TableGroupHeader(label: entry.key, count: entry.value.length),
            const SizedBox(height: 6),
            ...entry.value.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CommandCard(
                  item: item,
                  updating: updating.contains(item.detalleId),
                  onAdvance: () => onAdvance(item),
                ),
              ),
            ),
          ],
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

  Map<String, List<_ComandaItem>> _groupByTable(List<_ComandaItem> values) {
    final result = <String, List<_ComandaItem>>{};
    for (final item in values) {
      final key = item.mesaNumero == null
          ? 'Venta directa'
          : 'Mesa ${item.mesaNumero}${item.mesaDescripcion.trim().isEmpty ? '' : ' · ${item.mesaDescripcion.trim()}'}';
      result.putIfAbsent(key, () => <_ComandaItem>[]).add(item);
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
    final icon = switch (status) {
      'NUEVA' => Icons.notifications_active_outlined,
      'EN_PREPARACION' => Icons.soup_kitchen_outlined,
      'LISTA' => Icons.check_circle_outline_rounded,
      _ => Icons.room_service_outlined,
    };

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Badge(label: Text('$count')),
      ],
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
    return Row(
      children: [
        Icon(Icons.table_restaurant_rounded,
            size: 17, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.item,
    required this.updating,
    required this.onAdvance,
  });

  final _ComandaItem item;
  final bool updating;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customization = item.customization;
    final removed = customization.removed;
    final additions = customization.additions;
    final observation = customization.observation;

    final nextLabel = switch (item.estado) {
      'NUEVA' => 'Tomar pedido',
      'EN_PREPARACION' => 'Marcar lista',
      'LISTA' => 'Marcar entregada',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.55),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
                  color: theme.colorScheme.primaryContainer.withOpacity(.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${_formatQuantity(item.cantidad)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
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
                    if (item.productoDescripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.productoDescripcion.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
          if (nextLabel != null) ...[
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
    return Tooltip(
      message: kitchen ? 'Cocina' : 'Barra',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withOpacity(.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          kitchen ? Icons.restaurant_rounded : Icons.local_bar_rounded,
          size: 17,
          color: theme.colorScheme.onSecondaryContainer,
        ),
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
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(icon, size: 17, color: tone),
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
