import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../navigation/presentation/providers/menu_preferences_provider.dart';

/// Preferencias privadas: jamás cambia OPCIONMENU ni permisos de un rol.
class PersonalizarMenuPage extends ConsumerStatefulWidget {
  const PersonalizarMenuPage({super.key});

  @override
  ConsumerState<PersonalizarMenuPage> createState() =>
      _PersonalizarMenuPageState();
}

class _PersonalizarMenuPageState extends ConsumerState<PersonalizarMenuPage> {
  List<UserMenuItem> _items = [];
  Set<int> _favorites = {};
  String _visibility = 'AMBOS';
  bool _loading = true;
  bool _saving = false;
  bool _onlyFavorites = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      // Obtener toda la lista autorizada del servidor, no solo el rol
      // seleccionado. Los roles siguen resolviéndose en userMenuProvider.
      final authorized = await ref.read(userMenuRepositoryProvider)
          .findMyMenu();
      final prefs = await ref.read(menuPreferencesRepositoryProvider).load();
      final available = personalizeAuthorizedMenu(
        authorized.where((item) =>
          item.menuId != null && item.keyName != 'home'
            && item.path.isNotEmpty).toList(), prefs);
      if (!mounted) return;
      setState(() {
        _items = available;
        _favorites = {
          for (final item in available)
            if (item.isFavorite && item.menuId != null) item.menuId!,
        };
        _visibility = prefs.visibility;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'No se pudo recuperar tu configuración: $e';
        _loading = false;
      });
    }
  }

  void _move(int from, int to) {
    if (from < 0 || to < 0 || from >= _items.length || to >= _items.length ||
        from == to) return;
    setState(() {
      final element = _items.removeAt(from);
      _items.insert(to, element);
    });
  }

  void _toggleFavorite(UserMenuItem item) {
    final id = item.menuId;
    if (id == null) return;
    setState(() {
      if (!_favorites.add(id)) _favorites.remove(id);
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      await ref.read(menuPreferencesRepositoryProvider).save(
        [
          for (var i = 0; i < _items.length; i++)
            MenuPreferenceEntry(
              menuId: _items[i].menuId!, order: i,
              favorite: _favorites.contains(_items[i].menuId),
            ),
        ], _visibility);
      ref.invalidate(menuPreferencesProvider);
      ref.invalidate(userMenuProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu menú personalizado se guardó correctamente.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar los cambios: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Restablecer mi menú'),
        content: const Text('Volverás a ver el orden definido por tus roles '
            'y se quitarán todos los favoritos personales. '
            'No se modificarán tus permisos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restablecer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(menuPreferencesRepositoryProvider).reset();
      ref.invalidate(menuPreferencesProvider);
      ref.invalidate(userMenuProvider);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se restauró el orden original del menú.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible restablecer el menú: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _iconFor(UserMenuItem item) => switch (item.keyName) {
    'ventas' || 'mesero' || 'venta_directa' => Icons.point_of_sale_rounded,
    'inventario' || 'inventario_admin' => Icons.inventory_2_outlined,
    'reportes' || 'ganancias' => Icons.bar_chart_rounded,
    'pedidos_compra' || 'proximo_pedido' => Icons.local_shipping_outlined,
    'menu_digital' => Icons.menu_book_rounded,
    'eventos' => Icons.event_available_rounded,
    'usuarios' => Icons.people_alt_rounded,
    'precios' => Icons.sell_rounded,
    'comandas' => Icons.restaurant_menu_rounded,
    _ => Icons.grid_view_rounded,
  };

  Widget _itemTile(UserMenuItem item, int index, AppPalette palette,
      {bool reorderable = true}) {
    final fav = item.menuId != null && _favorites.contains(item.menuId);
    return Container(
      key: ValueKey<int>(item.menuId!),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: fav
          ? palette.secondary.withOpacity(.55) : palette.cardBorder)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.1),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(_iconFor(item), size: 19, color: palette.secondary)),
          const SizedBox(width: 9),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary,
                  fontWeight: FontWeight.w800)),
              Text(item.groupName, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary,
                  fontSize: 11)),
            ],
          )),
          IconButton(
            tooltip: fav ? 'Quitar de favoritos' : 'Marcar como favorito',
            onPressed: () => _toggleFavorite(item),
            icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
              color: fav ? const Color(0xFFE0A12A) : palette.textSecondary)),
          if (reorderable) ...[
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                tooltip: 'Subir módulo',
                onPressed: index == 0 ? null : () => _move(index, index - 1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded)),
              IconButton(
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                tooltip: 'Bajar módulo',
                onPressed: index == _items.length - 1
                    ? null : () => _move(index, index + 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded)),
            ]),
            ReorderableDragStartListener(
              index: index, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(Icons.drag_indicator_rounded,
                    color: palette.textSecondary))),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final favorites = _items.where((item) =>
        item.menuId != null && _favorites.contains(item.menuId)).toList();
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 15),
                FilledButton(onPressed: _load, child: const Text('Reintentar')),
              ]),
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 44),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded, size: 29, color: palette.secondary),
                    const SizedBox(width: 9),
                    Expanded(child: Text('Personalizar mi menú',
                      style: TextStyle(fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary))),
                    IconButton(
                      tooltip: 'Regresar',
                      onPressed: () => context.canPop()
                          ? context.pop() : context.go('/home'),
                      icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Organiza las opciones que ya tienes autorizadas. '
                      'Tu orden y tus favoritos se sincronizan en todos tus dispositivos.',
                    style: TextStyle(color: palette.textSecondary, height: 1.4)),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.cardBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.star_rounded,
                            color: Color(0xFFE0A12A)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Mis favoritos',
                            style: TextStyle(color: palette.textPrimary,
                              fontWeight: FontWeight.w900, fontSize: 16))),
                          Text('${favorites.length} seleccionados',
                            style: TextStyle(color: palette.textSecondary,
                              fontSize: 12)),
                        ]),
                        const SizedBox(height: 12),
                        favorites.isEmpty
                          ? Text('Marca una estrella para agregar accesos rápidos.',
                              style: TextStyle(color: palette.textSecondary))
                          : Wrap(spacing: 7, runSpacing: 8,
                              children: [
                                for (final item in favorites)
                                  InputChip(
                                    label: Text(item.title,
                                      overflow: TextOverflow.ellipsis),
                                    onDeleted: () => _toggleFavorite(item),
                                  ),
                              ]),
                      ]),
                  ),
                  const SizedBox(height: 22),
                  Text('¿Dónde mostrar los favoritos?',
                    style: TextStyle(fontWeight: FontWeight.w900,
                      color: palette.textPrimary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final option in const [
                      ('MENU', 'Solo menú'),
                      ('INICIO', 'Solo inicio'),
                      ('AMBOS', 'En ambos'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: _visibility == option.$1,
                        onSelected: (_) => setState(() => _visibility = option.$1)),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: Text('Orden de los módulos',
                      style: TextStyle(color: palette.textPrimary,
                        fontSize: 17, fontWeight: FontWeight.w900))),
                    TextButton.icon(
                      onPressed: _saving ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restablecer')),
                  ]),
                  const SizedBox(height: 5),
                  Text('Arrastra el icono de puntos o usa las flechas para ordenar. '
                      'Los cambios se aplican al guardar.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 9, children: [
                    ChoiceChip(
                      label: const Text('Todos los módulos'),
                      selected: !_onlyFavorites,
                      onSelected: (_) => setState(() => _onlyFavorites = false)),
                    ChoiceChip(
                      label: const Text('Solo favoritos'),
                      selected: _onlyFavorites,
                      onSelected: (_) => setState(() => _onlyFavorites = true)),
                  ]),
                  const SizedBox(height: 10),
                  if (_onlyFavorites)
                    for (final item in favorites)
                      _itemTile(item, _items.indexOf(item), palette,
                        reorderable: false)
                  else
                    ReorderableListView.builder(
                      key: const ValueKey('user-menu-reorder-list'),
                      buildDefaultDragHandles: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      onReorder: (from, to) {
                        if (to > from) to--;
                        _move(from, to);
                      },
                      itemBuilder: (context, index) =>
                        _itemTile(_items[index], index, palette),
                    ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No hay módulos disponibles para este usuario.')),
                  const SizedBox(height: 22),
                  Wrap(spacing: 10, runSpacing: 10,
                    alignment: WrapAlignment.end, children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => context.go('/home'),
                        child: const Text('Volver')),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Guardar mi menú')),
                    ]),
                ]),
            ),
      ))),
    );
  }
}
