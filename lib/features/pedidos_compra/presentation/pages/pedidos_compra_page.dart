import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

class PedidosCompraPage extends ConsumerStatefulWidget {
  const PedidosCompraPage({super.key}) : providersOnly = false;

  const PedidosCompraPage.proveedores({super.key}) : providersOnly = true;

  final bool providersOnly;

  @override
  ConsumerState<PedidosCompraPage> createState() => _PedidosCompraPageState();
}

class _PedidosCompraPageState extends ConsumerState<PedidosCompraPage> {
  bool _loading = true;
  Object? _error;
  int? _branchId;
  final Set<int> _receiving = <int>{};
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _destinations = const [];
  List<Map<String, dynamic>> _products = const [];

  final NumberFormat _money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
  }

  Set<int> _ids(Object? raw) {
    if (raw is! List) return <int>{};
    return raw.whereType<num>().map((item) => item.toInt()).toSet();
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _qty(Object? value) {
    final number = _number(value);
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }

  Future<void> _reload() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (!mounted) return;
    if (branchId == null) {
      setState(() {
        _branchId = null;
        _orders = const [];
        _destinations = const [];
        _products = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _branchId = branchId;
    });

    try {
      final api = ref.read(apiClientProvider);

      if (widget.providersOnly) {
        final destinations = await api.get<Object?>(
          '/api/v1/pedidos-compra/destinos',
          (json) => json,
          queryParameters: <String, dynamic>{'sucursalId': branchId},
        );
        final products = await api.get<Object?>(
          '/api/v1/productos/sucursal/' + branchId.toString(),
          (json) => json,
        );

        if (!mounted) return;
        final productRows = _maps(products.data)
          ..sort(
            (a, b) => (a['prodNombre'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b['prodNombre'] ?? '').toString().toLowerCase()),
          );
        setState(() {
          _orders = const [];
          _destinations = _maps(destinations.data);
          _products = productRows;
          _loading = false;
        });
      } else {
        final orders = await api.get<Object?>(
          '/api/v1/pedidos-compra/sucursal/' + branchId.toString(),
          (json) => json,
          queryParameters: const <String, dynamic>{'conSaldo': false},
        );
        if (!mounted) return;
        setState(() {
          _orders = _maps(orders.data);
          _destinations = const [];
          _products = const [];
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _receive(Map<String, dynamic> order) async {
    final id = (order['pediId'] as num?)?.toInt();
    if (id == null || _receiving.contains(id)) return;

    final details = _maps(order['detalles']);
    final totalUnits = details.fold<double>(
      0,
      (value, item) => value + _number(item['unidades']),
    );

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Recibir pedido #' + id.toString()),
        content: Text(
          'Se registrarán ' +
              details.length.toString() +
              ' productos y ' +
              _qty(totalUnits) +
              ' unidades en inventario.\n\nConfirma únicamente cuando la mercancía haya sido recibida físicamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.inventory_rounded),
            label: const Text('Recibir pedido'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _receiving.add(id));
    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
            '/api/v1/pedidos-compra/' + id.toString() + '/recibir',
            null,
            (json) => json is Map
                ? Map<String, dynamic>.from(json)
                : <String, dynamic>{},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido #' +
                id.toString() +
                ' recibido. El stock quedó actualizado.',
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible recibir el pedido: ' + error.toString())),
      );
    } finally {
      if (mounted) setState(() => _receiving.remove(id));
    }
  }

  Future<void> _editDestination([Map<String, dynamic>? current]) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return;

    final name = TextEditingController(text: current?['nombre']?.toString() ?? '');
    final phone = TextEditingController(text: current?['whatsapp']?.toString() ?? '');
    final assigned = _ids(current?['productoIds']);
    final defaults = _ids(current?['productoIdsPredeterminados']);
    var saving = false;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(current == null ? 'Nuevo proveedor / WhatsApp' : 'Editar proveedor / WhatsApp'),
            content: SizedBox(
              width: 620,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor / destino',
                        hintText: 'Ej. Distribuidora de papas',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        hintText: '573001234567',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Productos asociados',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final productId = (product['prodId'] as num?)?.toInt();
                            if (productId == null) return const SizedBox.shrink();
                            final checked = assigned.contains(productId);
                            final primary = defaults.contains(productId);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              onChanged: saving
                                  ? null
                                  : (value) {
                                      setLocal(() {
                                        if (value == true) {
                                          assigned.add(productId);
                                        } else {
                                          assigned.remove(productId);
                                          defaults.remove(productId);
                                        }
                                      });
                                    },
                              title: Text(product['prodNombre']?.toString() ?? 'Producto'),
                              subtitle: Text(primary ? 'WhatsApp predeterminado' : 'Proveedor disponible'),
                              secondary: IconButton(
                                tooltip: primary
                                    ? 'Quitar predeterminado'
                                    : 'Marcar predeterminado',
                                onPressed: saving || !checked
                                    ? null
                                    : () {
                                        setLocal(() {
                                          if (primary) {
                                            defaults.remove(productId);
                                          } else {
                                            defaults.add(productId);
                                          }
                                        });
                                      },
                                icon: Icon(
                                  primary
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Un producto puede tener varios proveedores. Solo uno puede quedar como predeterminado.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Completa nombre y WhatsApp.')),
                          );
                          return;
                        }
                        setLocal(() => saving = true);
                        try {
                          final body = <String, dynamic>{
                            'sucuId': branchId,
                            'nombre': name.text.trim(),
                            'whatsapp': phone.text.trim(),
                            'productoIds': assigned.toList()..sort(),
                            'productoIdsPredeterminados': defaults.toList()..sort(),
                          };
                          final api = ref.read(apiClientProvider);
                          if (current == null) {
                            await api.post<Map<String, dynamic>>(
                              '/api/v1/pedidos-compra/destinos',
                              body,
                              (json) => json is Map
                                  ? Map<String, dynamic>.from(json)
                                  : <String, dynamic>{},
                            );
                          } else {
                            final id = (current['id'] as num?)?.toInt();
                            await api.put<Map<String, dynamic>>(
                              '/api/v1/pedidos-compra/destinos/' + id.toString(),
                              body,
                              (json) => json is Map
                                  ? Map<String, dynamic>.from(json)
                                  : <String, dynamic>{},
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          setLocal(() => saving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No fue posible guardar: ' + error.toString()),
                              ),
                            );
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(saving ? 'Guardando' : 'Guardar'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) await _reload();
    } finally {
      name.dispose();
      phone.dispose();
    }
  }

  Future<void> _removeDestination(Map<String, dynamic> destination) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    final id = (destination['id'] as num?)?.toInt();
    if (branchId == null || id == null) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text(
          '¿Eliminar ' +
              (destination['nombre']?.toString() ?? 'este proveedor') +
              ' de los destinos de pedido?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    try {
      await ref.read(apiClientProvider).delete<Object?>(
            '/api/v1/pedidos-compra/destinos/' +
                id.toString() +
                '?sucursalId=' +
                branchId.toString(),
            (json) => json,
          );
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible eliminar: ' + error.toString())),
      );
    }
  }

@override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final activeBranchId = branchState.activeBranchId;

    if (activeBranchId != _branchId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }

    final pending = _orders
        .where(
          (order) =>
              (order['estado'] ?? '').toString().toUpperCase() != 'RECIBIDO',
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        child: SafeArea(
          child: Padding(
            padding: palette.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pageHeader(
                  palette,
                  branchState.activeBranch?.sucuNombre ?? 'Sucursal',
                  pending.length,
                ),
                const SizedBox(height: 12),
                if (!widget.providersOnly &&
                    !_loading &&
                    _error == null &&
                    activeBranchId != null) ...[
                  _summaryGrid(palette, pending),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _loading
                      ? AppLoader(
                          message: widget.providersOnly
                              ? 'Cargando proveedores...'
                              : 'Cargando pedidos...',
                        )
                      : _error != null
                          ? _errorView(palette)
                          : widget.providersOnly
                              ? _destinationsView(palette, activeBranchId)
                              : _pendingView(palette, activeBranchId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(
    AppPalette palette,
    String branchName,
    int pendingCount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: palette.panelDecoration(
        baseRadius: 22,
        tint: palette.secondary,
        elevated: true,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: palette.mainGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: palette.cardShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              widget.providersOnly
                  ? Icons.storefront_rounded
                  : Icons.local_shipping_rounded,
              color: palette.onPrimary,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.providersOnly
                      ? 'Proveedores de pedidos'
                      : 'Pedidos de compra',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.providersOnly
                      ? branchName +
                          ' · configura proveedores, WhatsApp y productos asociados'
                      : branchName +
                          ' · ' +
                          pendingCount.toString() +
                          ' pedido' +
                          (pendingCount == 1 ? '' : 's') +
                          ' por recibir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip:
                widget.providersOnly ? 'Actualizar proveedores' : 'Actualizar pedidos',
            onPressed: _reload,
            style: IconButton.styleFrom(
              foregroundColor: palette.secondary,
              backgroundColor: palette.secondary.withOpacity(.10),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(
    AppPalette palette,
    List<Map<String, dynamic>> pending,
  ) {
    var totalUnits = 0.0;
    var totalValue = 0.0;
    final productIds = <int>{};

    for (final order in pending) {
      totalValue += _number(order['totalEstimado']);
      for (final detail in _maps(order['detalles'])) {
        totalUnits += _number(detail['unidades']);
        final productId = (detail['prodId'] as num?)?.toInt();
        if (productId != null) productIds.add(productId);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth < 620 ? 2 : 4;
        final width =
            ((constraints.maxWidth - (spacing * (columns - 1))) / columns)
                .clamp(0.0, constraints.maxWidth)
                .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: _metricCard(
                palette: palette,
                icon: Icons.pending_actions_rounded,
                label: 'Por recibir',
                value: pending.length.toString(),
                tone: palette.warning,
              ),
            ),
            SizedBox(
              width: width,
              child: _metricCard(
                palette: palette,
                icon: Icons.inventory_2_outlined,
                label: 'Productos',
                value: productIds.length.toString(),
                tone: palette.info,
              ),
            ),
            SizedBox(
              width: width,
              child: _metricCard(
                palette: palette,
                icon: Icons.layers_outlined,
                label: 'Unidades',
                value: _qty(totalUnits),
                tone: palette.secondary,
              ),
            ),
            SizedBox(
              width: width,
              child: _metricCard(
                palette: palette,
                icon: Icons.payments_outlined,
                label: 'Total estimado',
                value: '\$ ' + _money.format(totalValue),
                tone: palette.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required AppPalette palette,
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: palette.panelDecoration(
        baseRadius: 18,
        tint: tone,
        elevated: false,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withOpacity(.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tone, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: palette.panelDecoration(
        baseRadius: 18,
        elevated: false,
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: palette.secondary.withOpacity(.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.secondary.withOpacity(.24)),
        ),
        labelColor: palette.secondary,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(
            icon: Icon(Icons.inventory_2_outlined, size: 20),
            text: 'Por recibir',
          ),
          Tab(
            icon: Icon(Icons.message_outlined, size: 20),
            text: 'Proveedores / WhatsApp',
          ),
        ],
      ),
    );
  }

  Widget _errorView(AppPalette palette) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        decoration: palette.panelDecoration(
          baseRadius: 20,
          tint: palette.warning,
          elevated: false,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: palette.warning,
            ),
            const SizedBox(height: 10),
            Text(
              'No fue posible cargar la información.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingView(AppPalette palette, int? branchId) {
    if (branchId == null) {
      return const AppEmptyView(
        message:
            'Selecciona una sucursal. La recepción siempre afecta el inventario de una sucursal.',
      );
    }

    final pending = _orders
        .where(
          (order) =>
              (order['estado'] ?? '').toString().toUpperCase() != 'RECIBIDO',
        )
        .toList(growable: false);

    if (pending.isEmpty) {
      return const AppEmptyView(
        message:
            'No hay pedidos por recibir. Los pedidos confirmados aparecerán aquí hasta su recepción.',
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 1320
                  ? 3
                  : constraints.maxWidth >= 760
                      ? 2
                      : 1;
              final cardWidth =
                  ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                      .clamp(0.0, constraints.maxWidth)
                      .toDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final order in pending)
                    SizedBox(
                      width: cardWidth,
                      child: _orderCard(palette, order),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _orderCard(
    AppPalette palette,
    Map<String, dynamic> order,
  ) {
    final id = (order['pediId'] as num?)?.toInt();
    final details = _maps(order['detalles']);
    final busy = id != null && _receiving.contains(id);
    final provider =
        order['destinoNombre']?.toString().trim().isNotEmpty == true
            ? order['destinoNombre'].toString()
            : 'Destino general';
    final phone = order['whatsappDestino']?.toString().trim() ?? '';
    final totalUnits = details.fold<double>(
      0,
      (value, item) => value + _number(item['unidades']),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: palette.warning,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.warning.withOpacity(.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: palette.warning,
                  size: 21,
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
                            id == null ? 'Pedido' : 'Pedido #' + id.toString(),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _statusBadge(
                          palette,
                          'POR RECIBIR',
                          palette.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _date(order['fecha']),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: palette.warning.withOpacity(.055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.warning.withOpacity(.13),
              ),
            ),
            child: Column(
              children: [
                _infoRow(
                  palette,
                  Icons.storefront_outlined,
                  'Proveedor',
                  provider,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _infoRow(
                    palette,
                    Icons.chat_outlined,
                    'WhatsApp',
                    phone,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  palette,
                  Icons.inventory_2_outlined,
                  details.length.toString() + ' productos',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  palette,
                  Icons.layers_outlined,
                  _qty(totalUnits) + ' unidades',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.cardBorder.withOpacity(.82),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DETALLE DEL PEDIDO',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 5),
                for (var index = 0; index < details.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 10,
                      color: palette.cardBorder.withOpacity(.55),
                    ),
                  _detailRow(palette, details[index]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total estimado',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '\$ ' + _money.format(_number(order['totalEstimado'])),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || id == null ? null : () => _receive(order),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.inventory_rounded),
            label: Text(
              busy ? 'Recibiendo...' : 'Recibir y actualizar stock',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(
    AppPalette palette,
    String label,
    Color tone,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withOpacity(.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .35,
        ),
      ),
    );
  }

  Widget _infoRow(
    AppPalette palette,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.secondary),
        const SizedBox(width: 8),
        Text(
          label + ': ',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniMetric(
    AppPalette palette,
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: palette.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    AppPalette palette,
    Map<String, dynamic> detail,
  ) {
    final product = detail['producto']?.toString() ?? 'Producto';
    final presentation = detail['presentacion']?.toString() ?? 'und.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            product,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _qty(detail['presentaciones']) +
              ' ' +
              presentation +
              ' · ' +
              _qty(detail['unidades']) +
              ' und.',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _destinationsView(AppPalette palette, int? branchId) {
    if (branchId == null) {
      return const AppEmptyView(
        message:
            'Selecciona una sucursal. Los proveedores se parametrizan por sucursal.',
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: palette.panelDecoration(
              baseRadius: 18,
              tint: palette.secondary,
              elevated: false,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final description = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destinos de pedido',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Asocia productos con cada proveedor y define su WhatsApp predeterminado.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );

                final button = FilledButton.icon(
                  onPressed: () => _editDestination(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Agregar proveedor',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      description,
                      const SizedBox(height: 10),
                      button,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_destinations.isEmpty)
            const SizedBox(
              height: 260,
              child: AppEmptyView(
                message:
                    'Sin proveedores configurados. Agrega varios WhatsApp y asocia los productos que compras con cada uno.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final columns = constraints.maxWidth >= 1120
                    ? 3
                    : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                final cardWidth =
                    ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                        .clamp(0.0, constraints.maxWidth)
                        .toDouble();

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final destination in _destinations)
                      SizedBox(
                        width: cardWidth,
                        child: _destinationCard(palette, destination),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _destinationCard(
    AppPalette palette,
    Map<String, dynamic> destination,
  ) {
    final productCount = _ids(destination['productoIds']).length;
    final defaultCount =
        _ids(destination['productoIdsPredeterminados']).length;
    final name = destination['nombre']?.toString() ?? 'Proveedor';
    final phone = destination['whatsapp']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: palette.secondary,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_outlined,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 13,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _destinationMetric(
                  palette,
                  Icons.inventory_2_outlined,
                  productCount.toString(),
                  'Productos',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _destinationMetric(
                  palette,
                  Icons.star_rounded,
                  defaultCount.toString(),
                  'Predeterminados',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editDestination(destination),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Editar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Eliminar proveedor',
                onPressed: () => _removeDestination(destination),
                style: IconButton.styleFrom(
                  foregroundColor: palette.warning,
                  backgroundColor: palette.warning.withOpacity(.10),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _destinationMetric(
    AppPalette palette,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.secondary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.5,
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
