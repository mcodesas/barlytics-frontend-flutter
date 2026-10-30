import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/tipos_producto_response_model.dart';
import '../providers/tipos_producto_provider.dart';

class TiposProductoListPage extends ConsumerStatefulWidget {
  const TiposProductoListPage({super.key});

  @override
  ConsumerState<TiposProductoListPage> createState() => _TiposProductoListPageState();
}

class _TiposProductoListPageState extends ConsumerState<TiposProductoListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([TiposProductoResponseModel? item]) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final nameController = TextEditingController(text: item?.tpprNombre ?? '');
    final descriptionController = TextEditingController(text: item?.tpprDescripcion ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    Future<bool> save(StateSetter setLocalState) async {
      if (!formKey.currentState!.validate()) return false;
      setLocalState(() => saving = true);
      final ok = await ref.read(tiposproductoProvider.notifier).save(
        id: item?.tpprId,
        body: <String, dynamic>{
          'tpprNombre': nameController.text.trim(),
          'tpprDescripcion': descriptionController.text.trim(),
        },
      );
      final currentContext = formKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        setLocalState(() => saving = false);
      }
      return ok;
    }

    Widget editor(
      BuildContext modalContext,
      StateSetter setLocalState, {
      required bool mobile,
    }) {
      return Container(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 520),
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          mobile ? MediaQuery.viewInsetsOf(modalContext).bottom + 20 : 20,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: mobile
              ? BorderRadius.vertical(top: Radius.circular(palette.radius(24)))
              : BorderRadius.circular(palette.radius(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item == null ? 'Nuevo tipo' : 'Editar tipo',
                          style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    maxLength: 30,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    autofocus: item == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del tipo',
                      hintText: 'Ej. Cervezas',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLength: 300,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descripción opcional',
                      hintText: 'Una nota corta para identificarlo',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(modalContext),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final ok = await save(setLocalState);
                                  if (!modalContext.mounted || !ok) return;
                                  Navigator.pop(modalContext, true);
                                },
                          icon: saving
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(saving ? 'Guardando...' : 'Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mobile = MediaQuery.sizeOf(context).width < 700;
    final result = mobile
        ? await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withOpacity(0.56),
            builder: (context) => StatefulBuilder(
              builder: (context, setLocalState) => editor(
                context,
                setLocalState,
                mobile: true,
              ),
            ),
          )
        : await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withOpacity(0.56),
            builder: (context) => Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, setLocalState) => editor(
                  context,
                  setLocalState,
                  mobile: false,
                ),
              ),
            ),
          );

    nameController.dispose();
    descriptionController.dispose();
    if (result == true && mounted) {
      _showMessage(item == null ? 'Tipo creado correctamente' : 'Tipo actualizado correctamente');
    }
  }

  Future<void> _delete(TiposProductoResponseModel item) async {
    final id = item.tpprId;
    if (id == null) return;
    final confirmed = await _confirmDelete(item.tpprNombre ?? 'este tipo');
    if (!confirmed) return;
    final ok = await ref.read(tiposproductoProvider.notifier).remove(id);
    if (!mounted) return;
    _showMessage(ok ? 'Tipo eliminado' : 'No fue posible eliminar el tipo', error: !ok);
  }

  Future<bool> _confirmDelete(String name) async {
    final palette = ref.read(selectedAppPaletteProvider);
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.56),
          builder: (context) => AlertDialog(
            scrollable: true,
        backgroundColor: palette.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(palette.radius(22)),
              side: BorderSide.none,
            ),
            title: const Text('Eliminar tipo'),
            content: Text(
              '¿Eliminar “$name”? Puede estar asociado a productos existentes.',
              style: TextStyle(color: palette.textSecondary, height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final state = ref.watch(tiposproductoProvider);
    final query = _query.trim().toLowerCase();
    final items = state.items
        .where((item) {
          if (query.isEmpty) return true;
          return '${item.tpprNombre ?? ''} ${item.tpprDescripcion ?? ''}'.toLowerCase().contains(query);
        })
        .toList(growable: false)
      ..sort((a, b) => (a.tpprNombre ?? '').toLowerCase().compareTo((b.tpprNombre ?? '').toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: () => ref.read(tiposproductoProvider.notifier).load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: _TopControls(
                            palette: palette,
                            controller: _searchController,
                            total: state.items.length,
                            visible: items.length,
                            loading: state.loading,
                            onBack: () => context.go('/tablas_parametricas'),
                            onChanged: (value) => setState(() => _query = value),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            onAdd: () => _openEditor(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: _buildContent(
                            palette,
                            state.loading,
                            state.failure?.message,
                            items,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AppPalette palette,
    bool loading,
    String? error,
    List<TiposProductoResponseModel> items,
  ) {
    if (loading && ref.read(tiposproductoProvider).items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _StatePanel(
        palette: palette,
        icon: Icons.error_outline_rounded,
        title: 'No fue posible cargar los tipos',
        message: error,
        action: FilledButton.icon(
          onPressed: () => ref.read(tiposproductoProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (items.isEmpty) {
      return _StatePanel(
        palette: palette,
        icon: _query.isEmpty ? Icons.category_outlined : Icons.search_off_rounded,
        title: _query.isEmpty ? 'No hay tipos registrados' : 'No encontramos coincidencias',
        message: _query.isEmpty
            ? 'Crea el primer tipo para organizar los productos.'
            : 'Cambia la búsqueda o limpia el texto.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(palette.radius(22)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _TypeRow(
              palette: palette,
              item: items[index],
              disabled: loading,
              onEdit: () => _openEditor(items[index]),
              onDelete: () => _delete(items[index]),
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 66,
                color: palette.textSecondary.withOpacity(0.12),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.palette,
    required this.controller,
    required this.total,
    required this.visible,
    required this.loading,
    required this.onBack,
    required this.onChanged,
    required this.onClear,
    required this.onAdd,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final int total;
  final int visible;
  final bool loading;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        final back = TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Parámetros'),
        );
        final search = TextField(
          maxLength: 120,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar tipo',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ).compactFilter(),
        );
        final count = Text(
          visible == total ? '$total tipos' : '$visible de $total',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        );
        final add = FilledButton.icon(
          onPressed: loading ? null : onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo tipo'),
        );

        if (mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: back),
              const SizedBox(height: 8),
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: count),
                  add,
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: back),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 14),
                count,
                const SizedBox(width: 14),
                add,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.palette,
    required this.item,
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
  });

  final AppPalette palette;
  final TiposProductoResponseModel item;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (item.tpprNombre ?? '').trim();
    final description = (item.tpprDescripcion ?? '').trim();
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(palette.radius(12)),
                ),
                child: Icon(Icons.category_rounded, color: palette.secondary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Tipo sin nombre' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  enabled: !disabled,
                  color: palette.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(palette.radius(16)),
                    side: BorderSide.none,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_rounded),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              else ...[
                IconButton(
                  tooltip: 'Editar',
                  onPressed: disabled ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: disabled ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.palette,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(palette.radius(22)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: palette.secondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
