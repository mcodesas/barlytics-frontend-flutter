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
  const PedidosCompraPage({super.key});

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
      final orders = await api.get<Object?>(
        '/api/v1/pedidos-compra/sucursal/' + branchId.toString(),
        (json) => json,
        queryParameters: const <String, dynamic>{'conSaldo': false},
      );
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
        _orders = _maps(orders.data);
        _destinations = _maps(destinations.data);
        _products = productRows;
        _loading = false;
      });
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(palette.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: palette.panelDecoration(
                      baseRadius: 22,
                      tint: palette.secondary,
                      elevated: true,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            color: palette.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pedidos de compra',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                (branchState.activeBranch?.sucuNombre ?? 'Sucursal') +
                                    ' · recepción y proveedores',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: palette.panelDecoration(
                      baseRadius: 18,
                      elevated: false,
                    ),
                    child: TabBar(
                      labelColor: palette.secondary,
                      unselectedLabelColor: palette.textSecondary,
                      indicatorColor: palette.secondary,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.inventory_2_outlined),
                          text: 'Por recibir',
                        ),
                        Tab(
                          icon: Icon(Icons.message_outlined),
                          text: 'Proveedores / WhatsApp',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loading
                        ? const AppLoader(message: 'Cargando pedidos...')
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No fue posible cargar la información.',
                                      style: TextStyle(color: palette.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _error.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: palette.textSecondary),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: _reload,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              )
                            : TabBarView(
                                children: [
                                  _pendingView(palette, activeBranchId),
                                  _destinationsView(palette, activeBranchId),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingView(AppPalette palette, int? branchId) {
    if (branchId == null) {
      return const AppEmptyView(
        message: 'Selecciona una sucursal. La recepción siempre afecta el inventario de una sucursal.',
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
        message: 'No hay pedidos por recibir. Los pedidos confirmados aparecerán aquí hasta su recepción.',
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = pending[index];
          final id = (order['pediId'] as num?)?.toInt();
          final details = _maps(order['detalles']);
          final busy = id != null && _receiving.contains(id);
          final provider =
              order['destinoNombre']?.toString().trim().isNotEmpty == true
                  ? order['destinoNombre'].toString()
                  : 'Destino general';
          final phone = order['whatsappDestino']?.toString().trim() ?? '';

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
                  children: [
                    Icon(Icons.local_shipping_outlined, color: palette.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            id == null ? 'Pedido' : 'Pedido #' + id.toString(),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            provider + (phone.isEmpty ? '' : ' · ' + phone),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money.format(_number(order['totalEstimado'])),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _date(order['fecha']),
                  style: TextStyle(color: palette.textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 10),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail['producto']?.toString() ?? 'Producto',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _qty(detail['presentaciones']) +
                              ' ' +
                              (detail['presentacion']?.toString() ?? 'und.') +
                              ' · ' +
                              _qty(detail['unidades']) +
                              ' und.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: busy || id == null ? null : () => _receive(order),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_rounded),
                  label: Text(
                    busy ? 'Recibiendo...' : 'Recibir pedido y actualizar stock',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _destinationsView(AppPalette palette, int? branchId) {
    if (branchId == null) {
      return const AppEmptyView(
        message: 'Selecciona una sucursal. Los proveedores se parametrizan por sucursal.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _editDestination(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar proveedor / WhatsApp'),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _destinations.isEmpty
              ? const AppEmptyView(
                  message:
                      'Sin proveedores configurados. Agrega varios WhatsApp y asocia los productos que compras con cada uno.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _destinations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final destination = _destinations[index];
                    final productCount = _ids(destination['productoIds']).length;
                    final defaultCount =
                        _ids(destination['productoIdsPredeterminados']).length;
                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: palette.panelDecoration(
                        baseRadius: 18,
                        elevated: false,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.message_outlined, color: palette.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destination['nombre']?.toString() ?? 'Proveedor',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  (destination['whatsapp']?.toString() ?? '') +
                                      ' · ' +
                                      productCount.toString() +
                                      ' productos · ' +
                                      defaultCount.toString() +
                                      ' predeterminados',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _editDestination(destination),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _removeDestination(destination),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
