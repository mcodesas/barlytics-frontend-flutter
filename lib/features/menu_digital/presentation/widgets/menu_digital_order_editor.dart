import 'package:flutter/material.dart';

import '../../domain/menu_digital_ordering.dart';

/// Editor explícito del orden visible en la carta. No modifica el orden
/// global del catálogo ni los tipos de producto del negocio.
class MenuDigitalOrderEditor extends StatefulWidget {
  const MenuDigitalOrderEditor({
    super.key,
    required this.products,
    required this.categoryOrder,
    required this.onApply,
  });

  final List<Map<String, dynamic>> products;
  final List<String> categoryOrder;
  final void Function(List<String> categories, List<int> productIds) onApply;

  @override
  State<MenuDigitalOrderEditor> createState() => _MenuDigitalOrderEditorState();
}

class _MenuDigitalOrderEditorState extends State<MenuDigitalOrderEditor> {
  late List<int> _productIds;
  late List<String> _categoryOrder;
  bool _editingCategories = true;
  String? _selectedCategory;

  late final Map<int, Map<String, dynamic>> _byId = {
    for (final product in widget.products)
      if (MenuDigitalOrdering.productId(product) != null)
        MenuDigitalOrdering.productId(product)!: product,
  };

  @override
  void initState() {
    super.initState();
    _productIds = [
      for (final p in widget.products)
        if (MenuDigitalOrdering.productId(p) != null)
          MenuDigitalOrdering.productId(p)!,
    ];
    _categoryOrder = MenuDigitalOrdering.categories(
      widget.products, widget.categoryOrder);
    if (_categoryOrder.isNotEmpty) {
      _selectedCategory = _categoryOrder.first;
    }
  }

  List<T> _reordered<T>(List<T> source, int from, int to) {
    final result = [...source];
    if (to > from) to -= 1;
    if (from < 0 || from >= result.length) return result;
    to = to.clamp(0, result.length - 1).toInt();
    final item = result.removeAt(from);
    result.insert(to, item);
    return result;
  }

  void _moveType(int from, int to) {
    setState(() {
      _categoryOrder = _reordered(_categoryOrder, from, to);
    });
  }

  List<int> _idsForCategory(String category) => [
    for (final id in _productIds)
      if (_byId[id] != null &&
          MenuDigitalOrdering.category(_byId[id]!) == category) id,
  ];

  void _moveProduct(int from, int to) {
    final category = _selectedCategory;
    if (category == null) return;
    final ids = _idsForCategory(category);
    final reordered = _reordered(ids, from, to);
    var cursor = 0;
    setState(() {
      _productIds = [
        for (final id in _productIds)
          if (_byId[id] != null &&
              MenuDigitalOrdering.category(_byId[id]!) == category)
            reordered[cursor++]
          else
            id,
      ];
    });
  }

  Widget _reorderControls(
    int index, int count, void Function(int, int) change,
  ) => Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Subir una posición',
      onPressed: index == 0 ? null : () => change(index, index - 1),
      icon: const Icon(Icons.keyboard_arrow_up_rounded),
    ),
    IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Bajar una posición',
      onPressed: index >= count - 1 ? null : () => change(index, index + 2),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
    ),
    ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Icon(Icons.drag_indicator_rounded),
      ),
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = _categoryOrder;
    final category = types.contains(_selectedCategory)
        ? _selectedCategory : (types.isEmpty ? null : types.first);
    final ids = category == null ? <int>[] : _idsForCategory(category);
    final accent = theme.colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 690,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.format_list_numbered_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text('Organiza tu carta',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            const SizedBox(height: 7),
            Text('Lo que ubiques primero será lo primero que verá tu cliente. '
                'Arrastra los elementos o utiliza las flechas.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: _tab('1. Categorías', _editingCategories,
                  () => setState(() => _editingCategories = true))),
              const SizedBox(width: 8),
              Expanded(child: _tab('2. Productos', !_editingCategories,
                  () => setState(() => _editingCategories = false))),
            ]),
            const SizedBox(height: 12),
            if (!_editingCategories && types.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Productos de la categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final type in types)
                      DropdownMenuItem(value: type,
                        child: Text(type, maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
              ),
            Expanded(child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editingCategories)
                    Text('Orden de las secciones · ${types.length}',
                        style: theme.textTheme.labelLarge)
                  else
                    Text('Orden dentro de ${category ?? "tu carta"} · ${ids.length}',
                        style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (_editingCategories)
                    ReorderableListView.builder(
                      key: const ValueKey('reorder-categories'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: types.length,
                      onReorder: _moveType,
                      itemBuilder: (context, i) => Card(
                        key: ValueKey('cat-${types[i]}'),
                        margin: const EdgeInsets.only(bottom: 7),
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 12, right: 4),
                          leading: CircleAvatar(radius: 17,
                              child: Text('${i + 1}')),
                          title: Text(types[i], maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${widget.products.where((p) =>
                                MenuDigitalOrdering.category(p) == types[i]).length} productos'),
                          trailing: _reorderControls(i, types.length, _moveType),
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      key: ValueKey('reorder-products-$category'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: ids.length,
                      onReorder: _moveProduct,
                      itemBuilder: (context, i) {
                        final item = _byId[ids[i]]!;
                        return Card(
                          key: ValueKey('product-${ids[i]}'),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 7),
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 12, right: 4),
                            leading: CircleAvatar(radius: 17,
                                child: Text('${i + 1}')),
                            title: Text((item['nombre'] ?? 'Producto').toString(),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: _reorderControls(i, ids.length, _moveProduct),
                          ),
                        );
                      },
                    ),
                  if (types.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Selecciona productos antes de ordenar la carta.'),
                    ),
                ],
              ),
            )),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aplicar orden'),
                onPressed: () {
                  final ordered = MenuDigitalOrdering.arrange(
                    widget.products,
                    productIds: _productIds,
                    categoryOrder: _categoryOrder,
                  );
                  widget.onApply([..._categoryOrder], [
                    for (final p in ordered)
                      if (MenuDigitalOrdering.productId(p) != null)
                        MenuDigitalOrdering.productId(p)!,
                  ]);
                  Navigator.pop(context);
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tab(String title, bool selected, VoidCallback action) =>
      selected
          ? FilledButton.tonal(onPressed: action, child: Text(title))
          : OutlinedButton(onPressed: action, child: Text(title));
}
