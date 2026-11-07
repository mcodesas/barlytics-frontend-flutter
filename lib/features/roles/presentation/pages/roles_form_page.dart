import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../data/default_roles_repository.dart';

/// Editor visual de permisos nativos. No cambia el identificador técnico del rol.
class RolesFormPage extends ConsumerStatefulWidget {
  const RolesFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<RolesFormPage> createState() => _RolesFormPageState();
}

class _RolesFormPageState extends ConsumerState<RolesFormPage> {
  final _description = TextEditingController();
  final _search = TextEditingController();
  Map<String, dynamic> _role = {};
  List<Map<String, dynamic>> _menus = [];
  Set<int> _selected = {};
  Set<int> _initial = {};
  List<int> _selectedOrder = [];
  List<int> _initialOrder = [];
  bool _loading = true;
  bool _saving = false;
  String _query = '';
  String? _error;

  int? get _id => int.tryParse(widget.id ?? '');
  bool get _dirty => _selected.length != _initial.length ||
    !_selected.containsAll(_initial) ||
    _selectedOrder.length != _initialOrder.length ||
    !_sameOrder() ||
    _description.text.trim() != (_role['roleDescripcion']?.toString() ?? '').trim();

  bool _sameOrder() {
    for (var index = 0; index < _selectedOrder.length; index++) {
      if (index >= _initialOrder.length ||
          _selectedOrder[index] != _initialOrder[index]) return false;
    }
    return true;
  }

  void _moveMenu(int id, int position) {
    final previous = _selectedOrder.indexOf(id);
    if (previous < 0 || position < 0 ||
        position >= _selectedOrder.length || previous == position) return;
    setState(() {
      _selectedOrder.removeAt(previous);
      _selectedOrder.insert(position, id);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _id;
    if (id == null) {
      setState(() {
        _error = 'Identificador de rol inválido';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(defaultRolesRepositoryProvider).details(id);
      if (!mounted) return;
      final role = DefaultRolesRepository.toMap(result['role']);
      final menus = DefaultRolesRepository.toList(result['menus']);
      // El backend devuelve el orden existente por rol. Al migrar desde
      // versiones sin prioridad, usa el orden de catálogo como valor inicial.
      final selectedMenus = menus.where((menu) => menu['assigned'] == true)
          .toList(growable: false);
      final orderedIds = selectedMenus
          .map((menu) => DefaultRolesRepository.asInt(menu['menuId']))
          .toList(growable: false);
      final selected = orderedIds.toSet();
      setState(() {
        _role = role;
        _menus = menus;
        _selected = selected;
        _initial = {...selected};
        _selectedOrder = [...orderedIds];
        _initialOrder = [...orderedIds];
        _description.text = role['roleDescripcion']?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _setChecked(Map<String, dynamic> menu, bool selected) {
    if (_saving) return;
    final id = DefaultRolesRepository.asInt(menu['menuId']);
    if (menu['restricted'] == true && selected) return;
    setState(() {
      if (selected) {
        if (_selected.add(id)) _selectedOrder.add(id);
      } else {
        _selected.remove(id);
        _selectedOrder.remove(id);
      }
    });
  }

  Future<void> _save() async {
    final id = _id;
    if (id == null || _saving || !_dirty) return;
    final description = _description.text.trim();
    if (description.isEmpty || description.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descripción debe tener entre 1 y 100 caracteres.')));
      return;
    }
    if (_selected.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Dejar el rol sin opciones?'),
          content: const Text('Los usuarios asignados a este rol dejarán '
            'de ver sus módulos operativos. Confirma que deseas continuar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(defaultRolesRepositoryProvider).save(
        id, List<int>.of(_selectedOrder), description);
      if (!mounted) return;
      ref.invalidate(userMenuProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos del rol actualizados correctamente.')));
      context.go('/roles');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final authorized = ref.watch(activeRolesProvider).any((role) =>
      const {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN',
        'ADMIN_Y_SOPORTE'}.contains(normalizeRoleName(role)));
    if (!authorized) {
      return const Scaffold(body: Center(child:
        Text('Solo el administrador del sistema puede editar permisos nativos.')));
    }
    if (widget.id == null) {
      return DynamicCrudFormPage(config: rolesConfig);
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _menus) {
      final title = item['grupo']?.toString().trim();
      final group = title == null || title.isEmpty ? 'Otros' : title;
      grouped.putIfAbsent(group, () => []).add(item);
    }
    final selectedMenus = [
      for (final id in _selectedOrder)
        ..._menus.where((menu) =>
          DefaultRolesRepository.asInt(menu['menuId']) == id),
    ];
    final filter = _query.trim().toLowerCase();
    final availableCount = _menus.where((m) => m['restricted'] != true).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: _loading ? null : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: palette.surface,
            boxShadow: const [BoxShadow(color: Colors.black12,
              blurRadius: 15, offset: Offset(0, -4))]),
          child: Center(heightFactor: 1, child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1190),
            child: Row(children: [
              Expanded(child: Text('${_selected.length} opciones seleccionadas',
                style: TextStyle(color: palette.textPrimary,
                  fontWeight: FontWeight.w800))),
              TextButton(onPressed: _saving ? null :
                () => context.go('/roles'), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: !_dirty || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar cambios')),
            ]),
          )),
        ),
      ),
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _role.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error ?? 'No se encontró el rol'),
                TextButton.icon(onPressed: _load,
                  icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              ]))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1190),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: palette.panelDecoration(
                          baseRadius: 26, tint: palette.primary),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            IconButton(onPressed: () => context.go('/roles'),
                              icon: const Icon(Icons.arrow_back_rounded)),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CONFIGURACIÓN DE ROL PREDEFINIDO',
                                  style: TextStyle(color: palette.secondary,
                                    fontSize: 11, fontWeight: FontWeight.w900)),
                                Text(_role['roleNombre']?.toString() ?? 'Rol',
                                  style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: palette.textPrimary,
                                      fontWeight: FontWeight.w900)),
                              ],
                            )),
                            const Icon(Icons.shield_rounded, size: 36),
                          ]),
                          const SizedBox(height: 10),
                          Text('Selecciona los módulos que estarán disponibles '
                            'para quienes tengan este rol. Los permisos de '
                            'administración de plataforma no pueden delegarse a '
                            'roles operativos.',
                            style: TextStyle(color: palette.textSecondary,
                              height: 1.4)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _description,
                            maxLength: 100,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Descripción del rol',
                              prefixIcon: Icon(Icons.notes_rounded)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(spacing: 10, runSpacing: 9, children: [
                            Chip(avatar: const Icon(Icons.apps_rounded, size: 17),
                              label: Text('${_selected.length} asignadas')),
                            Chip(avatar: const Icon(Icons.view_module_rounded, size: 17),
                              label: Text('$availableCount delegables')),
                            Chip(avatar: const Icon(Icons.category_rounded, size: 17),
                              label: Text('${grouped.length} grupos')),
                          ]),
                        ]),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        MaterialBanner(
                          content: Text(_error!),
                          leading: const Icon(Icons.error_outline_rounded),
                          actions: [TextButton(onPressed: () =>
                            setState(() => _error = null), child: const Text('Cerrar'))]),
                      ],
                      const SizedBox(height: 18),
                      Text('Prioridad y visibilidad del menú',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('Activa o desactiva opciones abajo. Aquí puedes '
                        'moverlas o asignarles una posición directamente: '
                        '1 aparece primero para este rol.',
                        style: TextStyle(color: palette.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: palette.panelDecoration(baseRadius: 18,
                          elevated: false),
                        child: selectedMenus.isEmpty
                          ? Text('Este rol no tiene módulos asignados.',
                              style: TextStyle(color: palette.textSecondary))
                          : Column(children: [
                              for (var i = 0; i < selectedMenus.length; i++) ...[
                                if (i > 0) const Divider(height: 10),
                                Row(children: [
                                  SizedBox(width: 62, child: DropdownButton<int>(
                                    value: i + 1,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: [
                                      for (var position = 1;
                                          position <= selectedMenus.length;
                                          position++)
                                        DropdownMenuItem(
                                          value: position,
                                          child: Text('
                      const SizedBox(height: 18),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          labelText: 'Buscar opciones de menú',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: filter.isEmpty ? null : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            }, icon: const Icon(Icons.clear_rounded)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final entry in grouped.entries) ...[
                        if (entry.value.any((menu) =>
                          '${menu['nombre']} ${menu['descripcion']} ${menu['parametro']}'
                            .toLowerCase().contains(filter))) ...[
                          _GroupCard(
                            title: entry.key,
                            menus: entry.value.where((menu) =>
                              '${menu['nombre']} ${menu['descripcion']} ${menu['parametro']}'
                                .toLowerCase().contains(filter)).toList(),
                            selected: _selected,
                            palette: palette,
                            onToggle: _setChecked,
                            onSelectGroup: (checked) {
                              setState(() {
                                for (final menu in entry.value) {
                                  if (menu['restricted'] == true) continue;
                                  final id = DefaultRolesRepository.asInt(menu['menuId']);
                                  if (checked) {
                                    if (_selected.add(id)) _selectedOrder.add(id);
                                  } else {
                                    _selected.remove(id);
                                    _selectedOrder.remove(id);
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ]),
                  )),
                ],
              ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.title, required this.menus,
    required this.selected, required this.palette,
    required this.onToggle, required this.onSelectGroup});
  final String title;
  final List<Map<String, dynamic>> menus;
  final Set<int> selected;
  final AppPalette palette;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final ValueChanged<bool> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final assignable = menus.where((m) => m['restricted'] != true).toList();
    final picked = menus.where((m) =>
      selected.contains(DefaultRolesRepository.asInt(m['menuId']))).length;
    final complete = assignable.isNotEmpty && assignable.every((m) =>
      selected.contains(DefaultRolesRepository.asInt(m['menuId'])));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 21,
        tint: palette.secondary, elevated: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.folder_copy_outlined, color: palette.primary),
            Text(title, style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: palette.textPrimary,
                fontWeight: FontWeight.w900)),
            Chip(label: Text('$picked/${menus.length}')),
            TextButton.icon(
              onPressed: assignable.isEmpty ? null :
                () => onSelectGroup(!complete),
              icon: Icon(complete ? Icons.deselect_rounded
                : Icons.done_all_rounded),
              label: Text(complete ? 'Quitar grupo' : 'Seleccionar grupo')),
          ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 920 ? 3
            : constraints.maxWidth >= 540 ? 2 : 1;
          final width = (constraints.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final menu in menus)
              SizedBox(width: width, child: _MenuOption(
                menu: menu, palette: palette,
                selected: selected.contains(
                  DefaultRolesRepository.asInt(menu['menuId'])),
                onToggle: (checked) => onToggle(menu, checked))),
          ]);
        }),
      ]),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.menu, required this.palette,
    required this.selected, required this.onToggle});
  final Map<String, dynamic> menu;
  final AppPalette palette;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final restricted = menu['restricted'] == true;
    final enabled = !restricted || selected;
    return InkWell(
      onTap: enabled ? () => onToggle(!selected) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: palette.panelDecoration(baseRadius: 16,
          tint: selected ? palette.primary : null, elevated: false),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: selected,
            onChanged: enabled ? (checked) => onToggle(checked == true) : null),
          const SizedBox(width: 4),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(menu['nombre']?.toString() ?? 'Opción',
                style: TextStyle(color: palette.textPrimary,
                  fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(menu['descripcion']?.toString() ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary,
                  fontSize: 11, height: 1.3)),
              if (restricted) ...[
                const SizedBox(height: 6),
                Text('Reservado para administración',
                  style: TextStyle(color: palette.secondary,
                    fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ],
          )),
        ]),
      ),
    );
  }
}
 + 'position')),
                                    ],
                                    onChanged: _saving ? null : (value) {
                                      if (value != null) {
                                        _moveMenu(_selectedOrder[i], value - 1);
                                      }
                                    },
                                  )),
                                  const SizedBox(width: 9),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(selectedMenus[i]['nombre']
                                              ?.toString() ?? 'Opción',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w800)),
                                      Text(selectedMenus[i]['grupo']
                                              ?.toString() ?? '',
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 11)),
                                    ])),
                                  IconButton(
                                    tooltip: 'Subir prioridad',
                                    onPressed: _saving || i == 0 ? null
                                      : () => _moveMenu(_selectedOrder[i], i - 1),
                                    icon: const Icon(Icons.arrow_upward_rounded)),
                                  IconButton(
                                    tooltip: 'Bajar prioridad',
                                    onPressed: _saving || i == selectedMenus.length - 1
                                      ? null : () => _moveMenu(_selectedOrder[i], i + 1),
                                    icon: const Icon(Icons.arrow_downward_rounded)),
                                  IconButton(
                                    tooltip: 'Ocultar módulo para este rol',
                                    onPressed: _saving ? null : () =>
                                      _setChecked(selectedMenus[i], false),
                                    icon: const Icon(Icons.visibility_off_outlined)),
                                ]),
                              ],
                            ]),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          labelText: 'Buscar opciones de menú',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: filter.isEmpty ? null : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            }, icon: const Icon(Icons.clear_rounded)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final entry in grouped.entries) ...[
                        if (entry.value.any((menu) =>
                          '${menu['nombre']} ${menu['descripcion']} ${menu['parametro']}'
                            .toLowerCase().contains(filter))) ...[
                          _GroupCard(
                            title: entry.key,
                            menus: entry.value.where((menu) =>
                              '${menu['nombre']} ${menu['descripcion']} ${menu['parametro']}'
                                .toLowerCase().contains(filter)).toList(),
                            selected: _selected,
                            palette: palette,
                            onToggle: _setChecked,
                            onSelectGroup: (checked) {
                              setState(() {
                                for (final menu in entry.value) {
                                  if (menu['restricted'] == true) continue;
                                  final id = DefaultRolesRepository.asInt(menu['menuId']);
                                  if (checked) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ]),
                  )),
                ],
              ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.title, required this.menus,
    required this.selected, required this.palette,
    required this.onToggle, required this.onSelectGroup});
  final String title;
  final List<Map<String, dynamic>> menus;
  final Set<int> selected;
  final AppPalette palette;
  final void Function(Map<String, dynamic>, bool) onToggle;
  final ValueChanged<bool> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final assignable = menus.where((m) => m['restricted'] != true).toList();
    final picked = menus.where((m) =>
      selected.contains(DefaultRolesRepository.asInt(m['menuId']))).length;
    final complete = assignable.isNotEmpty && assignable.every((m) =>
      selected.contains(DefaultRolesRepository.asInt(m['menuId'])));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 21,
        tint: palette.secondary, elevated: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.folder_copy_outlined, color: palette.primary),
            Text(title, style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: palette.textPrimary,
                fontWeight: FontWeight.w900)),
            Chip(label: Text('$picked/${menus.length}')),
            TextButton.icon(
              onPressed: assignable.isEmpty ? null :
                () => onSelectGroup(!complete),
              icon: Icon(complete ? Icons.deselect_rounded
                : Icons.done_all_rounded),
              label: Text(complete ? 'Quitar grupo' : 'Seleccionar grupo')),
          ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 920 ? 3
            : constraints.maxWidth >= 540 ? 2 : 1;
          final width = (constraints.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final menu in menus)
              SizedBox(width: width, child: _MenuOption(
                menu: menu, palette: palette,
                selected: selected.contains(
                  DefaultRolesRepository.asInt(menu['menuId'])),
                onToggle: (checked) => onToggle(menu, checked))),
          ]);
        }),
      ]),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.menu, required this.palette,
    required this.selected, required this.onToggle});
  final Map<String, dynamic> menu;
  final AppPalette palette;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final restricted = menu['restricted'] == true;
    final enabled = !restricted || selected;
    return InkWell(
      onTap: enabled ? () => onToggle(!selected) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: palette.panelDecoration(baseRadius: 16,
          tint: selected ? palette.primary : null, elevated: false),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: selected,
            onChanged: enabled ? (checked) => onToggle(checked == true) : null),
          const SizedBox(width: 4),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(menu['nombre']?.toString() ?? 'Opción',
                style: TextStyle(color: palette.textPrimary,
                  fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(menu['descripcion']?.toString() ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary,
                  fontSize: 11, height: 1.3)),
              if (restricted) ...[
                const SizedBox(height: 6),
                Text('Reservado para administración',
                  style: TextStyle(color: palette.secondary,
                    fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ],
          )),
        ]),
      ),
    );
  }
}
