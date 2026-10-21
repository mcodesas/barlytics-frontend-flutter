import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Permite armar un pedido aunque el stock esté cubierto. Solo devuelve
/// borradores: confirmar el pedido sigue siendo una acción independiente.
class ManualPurchaseOrderDialog extends StatefulWidget {
  const ManualPurchaseOrderDialog({
    super.key,
    required this.products,
    required this.initialSelection,
  });

  final List<Map<String, dynamic>> products;
  final Map<int, int> initialSelection;

  @override
  State<ManualPurchaseOrderDialog> createState() => _ManualPurchaseOrderDialogState();
}

class _ManualPurchaseOrderDialogState extends State<ManualPurchaseOrderDialog> {
  final TextEditingController _search = TextEditingController();
  late final Map<int, int> _selected = Map<int, int>.from(widget.initialSelection);

  static int? _id(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _amount(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(int id, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selected.remove(id);
      } else {
        _selected[id] = quantity.clamp(1, 99999).toInt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.products.where((product) {
      final name = (product['producto'] ?? '').toString().toLowerCase();
      final desc = (product['presentacion_compra'] ?? '').toString().toLowerCase();
      final id = _id(product['producto_id'])?.toString() ?? '';
      return query.isEmpty || name.contains(query) || desc.contains(query) || id.contains(query);
    }).toList(growable: false);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: SizedBox(
        width: math.min(width - 24, 750),
        height: math.min(
          730,
          math.max(
            310,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom - 65,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Crear pedido manual',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sin aplicar cambios',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Elige los productos y las cantidades de compra. No es necesario que el inventario esté por debajo del mínimo.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por nombre, presentación o código',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                          tooltip: 'Limpiar búsqueda',
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.length.toString() + ' productos seleccionados',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
                    child: const Text('Limpiar selección'),
                  ),
                ],
              ),
              const Divider(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.products.isEmpty
                              ? 'No hay productos disponibles en el catálogo de esta sucursal.'
                              : 'No encontramos productos para esa búsqueda.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final id = _id(product['producto_id']);
                          if (id == null) return const SizedBox.shrink();
                          final selectedCount = _selected[id] ?? 0;
                          final cost = _amount(product['costo_presentacion_actual']);
                          final available = cost > 0;
                          final stock = _amount(product['stock_actual']);
                          final package = (product['presentacion_compra'] ?? 'Unidad').toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selectedCount > 0,
                                  onChanged: !available
                                      ? null
                                      : (selected) => _change(id, selected == true ? 1 : 0),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (product['producto'] ?? 'Producto').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        available
                                            ? 'Compra por: ' + package + ' · Stock: ' + stock.toStringAsFixed(0)
                                            : 'Sin costo de compra configurado',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: available
                                              ? theme.colorScheme.onSurfaceVariant
                                              : theme.colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (available) ...[
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Disminuir cantidad',
                                    onPressed: selectedCount == 0
                                        ? null
                                        : () => _change(id, selectedCount - 1),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      selectedCount.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Aumentar cantidad',
                                    onPressed: () => _change(id, selectedCount + 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 470;
                  final buttons = <Widget>[
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, Map<int, int>.from(_selected)),
                      icon: const Icon(Icons.check_rounded),
                      label: Text('Agregar ' + _selected.length.toString() + (_selected.length == 1 ? ' producto' : ' productos')),
                    ),
                  ];
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buttons[1],
                        const SizedBox(height: 8),
                        buttons[0],
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [buttons[0], const SizedBox(width: 9), buttons[1]],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
