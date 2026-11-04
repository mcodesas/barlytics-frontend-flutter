import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/data/models/bottom_menu_priority.dart';
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
  final Map<int, String> _pendingPositionDrafts = {};
  final GlobalKey _orderSectionKey = GlobalKey();

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
        _pendingPositionDrafts.clear();
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
    if (from < 0 || from >= _items.length) return;
    final menuId = _items[from].menuId;
    if (menuId == null) return;
    _moveByMenuId(menuId, to + 1, reveal: false);
  }

  // El ID es estable aunque Flutter reconstruya la lista al editar un campo.
  // No dependemos de un índice capturado antes de otro reordenamiento.
  void _moveByMenuId(int menuId, int position, {bool reveal = true}) {
    final current = _items.indexWhere((item) => item.menuId == menuId);
    if (current < 0 || position < 1 || position > _items.length) return;
    _pendingPositionDrafts.remove(menuId);
    if (current == position - 1) return;
    setState(() {
      _items = moveMenuItemByIdToPosition(
          _items, menuId: menuId, position: position);
    });
    // Al escribir 1 debe verse el elemento en el inicio del listado, no
    // permanecer la pantalla desplazada en la ubicación anterior.
    if (reveal && position <= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _orderSectionKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target,
              duration: const Duration(milliseconds: 280),
              alignment: 0.02,
              curve: Curves.easeOutCubic);
        }
      });
    }
  }

  // Si pulsan Guardar mientras siguen escribiendo, no se pierde el número.
  String? _applyPendingPositions() {
    if (_pendingPositionDrafts.isEmpty) return null;
    final pending = Map<int, String>.of(_pendingPositionDrafts);
    for (final entry in pending.entries) {
      final number = int.tryParse(entry.value.trim());
      if (number == null || number < 1 || number > _items.length) {
        return 'Escribe una posición entre 1 y ${_items.length} antes de guardar.';
      }
    }
    final positions = <int, int>{
      for (final entry in pending.entries)
        entry.key: int.parse(entry.value.trim()),
    };
    setState(() {
      _items = applyMenuPositionDrafts(_items, positions);
      _pendingPositionDrafts.clear();
    });
    return null;
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
    final validationError = _applyPendingPositions();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
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
            if (reorderable)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.drag_indicator_rounded,
                      color: palette.textSecondary)),
              ),
          ]),
          if (reorderable) ...[
            const SizedBox(height: 5),
            Row(children: [
              Text('Posición', style: TextStyle(
                color: palette.textSecondary, fontSize: 12,
                fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              MenuPositionField(
                key: ValueKey('position-${item.menuId}'),
                position: index + 1,
                maxPosition: _items.length,
                onDraftChanged: (text) =>
                    _pendingPositionDrafts[item.menuId!] = text,
                onCommit: (position) =>
                    _moveByMenuId(item.menuId!, position)),
              const Spacer(),
              IconButton(
                iconSize: 21,
                tooltip: 'Subir módulo',
                onPressed: index == 0 ? null : () => _move(index, index - 1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded)),
              IconButton(
                iconSize: 21,
                tooltip: 'Bajar módulo',
                onPressed: index == _items.length - 1
                    ? null : () => _move(index, index + 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded)),
            ]),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'guardar-menu-personalizado',
              onPressed: _saving ? null : _save,
              backgroundColor: palette.secondary,
              foregroundColor: palette.secondary.computeLuminance() > .5
                  ? Colors.black : Colors.white,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Guardando...' : 'Guardar mi menú')),
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
                                    label: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.sizeOf(context).width * .54),
                                      child: Text(item.title, maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
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
                  Row(key: _orderSectionKey, children: [
                    Expanded(child: Text('Orden de los módulos',
                      style: TextStyle(color: palette.textPrimary,
                        fontSize: 17, fontWeight: FontWeight.w900))),
                    TextButton.icon(
                      onPressed: _saving ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restablecer')),
                  ]),
                  const SizedBox(height: 5),
                  Text(_onlyFavorites
                      ? 'Para cambiar el orden vuelve a Todos los módulos. '
                        'Aquí puedes quitar favoritos con la estrella.'
                      : 'Escribe una posición y confirma con ✓, arrastra los '
                        'puntos o usa las flechas. Los grupos originales se mantienen.',
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
                  const SizedBox(height: 92),
                  Align(alignment: Alignment.centerRight,
                    child: Text('El botón Guardar permanece visible mientras navegas.',
                      style: TextStyle(color: palette.textSecondary,
                        fontSize: 11))),

                ]),
            ),
      ))),
    );
  }
}

/// Campo numérico que reordena automáticamente después de terminar de
/// escribir. El ✓, Enter, tocar fuera y Guardar también confirman el valor.
class MenuPositionField extends StatefulWidget {
  const MenuPositionField({
    super.key,
    required this.position,
    required this.maxPosition,
    required this.onDraftChanged,
    required this.onCommit,
  });

  final int position;
  final int maxPosition;
  final ValueChanged<String> onDraftChanged;
  final ValueChanged<int> onCommit;

  @override
  State<MenuPositionField> createState() => _MenuPositionFieldState();
}

class _MenuPositionFieldState extends State<MenuPositionField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.position.toString());
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant MenuPositionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _debounce?.cancel();
      if (_controller.text != widget.position.toString()) {
        _controller.value = TextEditingValue(
          text: widget.position.toString(),
          selection: TextSelection.collapsed(
            offset: widget.position.toString().length),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    widget.onDraftChanged(text);
    _debounce?.cancel();
    final position = int.tryParse(text.trim());
    if (position != null && position >= 1 &&
        position <= widget.maxPosition && position != widget.position) {
      // Evita mover a 1 mientras la persona todavía está escribiendo 10.
      _debounce = Timer(const Duration(milliseconds: 650), _commit);
    }
  }

  void _commit() {
    _debounce?.cancel();
    if (!mounted) return;
    final position = int.tryParse(_controller.text.trim());
    if (position == null ||
        position < 1 || position > widget.maxPosition) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Escribe una posición entre 1 y ${widget.maxPosition}.')));
      return;
    }
    widget.onCommit(position);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: TextField(
      controller: _controller,
      key: const ValueKey('menu-position-number'),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onChanged: _onChanged,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _commit(),
      decoration: InputDecoration(
        isDense: true,
        hintText: '1-${widget.maxPosition}',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 34, minHeight: 36),
        suffixIcon: IconButton(
          tooltip: 'Mover a posición',
          iconSize: 19,
          padding: EdgeInsets.zero,
          onPressed: _commit,
          icon: const Icon(Icons.check_circle_outline_rounded)),
      ),
    ),
  );
}
