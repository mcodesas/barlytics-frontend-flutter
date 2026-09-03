import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../data/models/marcas_response_model.dart';
import '../providers/marcas_provider.dart';

class MarcasListPage extends ConsumerStatefulWidget {
  const MarcasListPage({super.key});

  @override
  ConsumerState<MarcasListPage> createState() => _MarcasListPageState();
}

class _MarcasListPageState extends ConsumerState<MarcasListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([MarcasResponseModel? item]) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final nameController = TextEditingController(text: item?.mrcaNombre ?? '');
    final identificationController = TextEditingController(text: item?.mrcaIdentificacion ?? '');
    final formKey = GlobalKey<FormState>();
    String logo = (item?.mrcaLogo ?? '').trim();
    var saving = false;

    Future<void> pickLogo(StateSetter setLocalState) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showMessage('No fue posible leer la imagen.', error: true);
        return;
      }
      if (bytes.length > InputConstraints.imageMaxBytes) {
        _showMessage('El logo no puede superar 2 MB.', error: true);
        return;
      }
      final extension = (file.extension ?? 'png').toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/png',
      };
      setLocalState(() => logo = 'data:$mime;base64,${base64Encode(bytes)}');
    }

    Future<bool> save(StateSetter setLocalState) async {
      if (!formKey.currentState!.validate()) return false;
      setLocalState(() => saving = true);
      final ok = await ref.read(marcasProvider.notifier).save(
        id: item?.mrcaId,
        body: <String, dynamic>{
          'mrcaNombre': nameController.text.trim(),
          'mrcaIdentificacion': identificationController.text.trim(),
          'mrcaLogo': logo,
        },
      );
      final currentContext = formKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        setLocalState(() => saving = false);
      }
      return ok;
    }

    Widget editor(BuildContext modalContext, StateSetter setLocalState, {required bool mobile}) {
      return Container(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 620),
        padding: EdgeInsets.fromLTRB(22, 18, 22, mobile ? MediaQuery.viewInsetsOf(modalContext).bottom + 22 : 22),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: mobile
              ? BorderRadius.vertical(top: Radius.circular(palette.radius(28)))
              : BorderRadius.circular(palette.radius(28)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 32, offset: const Offset(0, 14))],
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
                      _BrandAvatar(palette: palette, name: nameController.text, logo: logo, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item == null ? 'Nueva marca' : 'Editar marca',
                              style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Identifica rápidamente los productos dentro del catálogo.',
                              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: saving ? null : () => Navigator.pop(modalContext), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final fields = Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            maxLength: 30,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            autofocus: item == null,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (_) => setLocalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la marca',
                              hintText: 'Ej. Bavaria',
                              prefixIcon: Icon(Icons.verified_outlined),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe el nombre de la marca' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: identificationController,
                            maxLength: 50,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Identificación o código',
                              hintText: 'Opcional',
                              prefixIcon: Icon(Icons.tag_rounded),
                            ),
                          ),
                        ],
                      );
                      final logoPanel = _LogoEditor(
                        palette: palette,
                        name: nameController.text,
                        logo: logo,
                        onPick: saving ? null : () => pickLogo(setLocalState),
                        onRemove: saving || logo.isEmpty ? null : () => setLocalState(() => logo = ''),
                      );
                      if (compact) {
                        return Column(children: [logoPanel, const SizedBox(height: 18), fields]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 190, child: logoPanel),
                          const SizedBox(width: 18),
                          Expanded(child: fields),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: saving ? null : () => Navigator.pop(modalContext), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
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
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
              builder: (context, setLocalState) => editor(context, setLocalState, mobile: true),
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
                builder: (context, setLocalState) => editor(context, setLocalState, mobile: false),
              ),
            ),
          );

    nameController.dispose();
    identificationController.dispose();
    if (result == true && mounted) {
      _showMessage(item == null ? 'Marca creada correctamente' : 'Marca actualizada correctamente');
    }
  }

  Future<void> _delete(MarcasResponseModel item) async {
    final id = item.mrcaId;
    if (id == null) return;
    final confirmed = await _confirmDelete(item.mrcaNombre ?? 'esta marca');
    if (!confirmed) return;
    final ok = await ref.read(marcasProvider.notifier).remove(id);
    if (!mounted) return;
    _showMessage(ok ? 'Marca eliminada' : 'No fue posible eliminar la marca', error: !ok);
  }

  Future<bool> _confirmDelete(String name) async {
    final palette = ref.read(selectedAppPaletteProvider);
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.56),
          builder: (context) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(palette.radius(26)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 30, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                        child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Eliminar marca',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¿Eliminar “$name”? Esta acción puede fallar si existen productos asociados.',
                    style: TextStyle(color: palette.textSecondary, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.delete_rounded),
                          label: const Text('Eliminar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final state = ref.watch(marcasProvider);
    final query = _query.trim().toLowerCase();
    final items = state.items
        .where((item) {
          if (query.isEmpty) return true;
          return '${item.mrcaNombre ?? ''} ${item.mrcaIdentificacion ?? ''}'.toLowerCase().contains(query);
        })
        .toList(growable: false)
      ..sort((a, b) => (a.mrcaNombre ?? '').toLowerCase().compareTo((b.mrcaNombre ?? '').toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: () => ref.read(marcasProvider.notifier).load(),
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
    List<MarcasResponseModel> items,
  ) {
    if (loading && ref.read(marcasProvider).items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _StatePanel(
        palette: palette,
        icon: Icons.error_outline_rounded,
        title: 'No fue posible cargar las marcas',
        message: error,
        action: FilledButton.icon(
          onPressed: () => ref.read(marcasProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (items.isEmpty) {
      return _StatePanel(
        palette: palette,
        icon: _query.isEmpty ? Icons.verified_outlined : Icons.search_off_rounded,
        title: _query.isEmpty ? 'No hay marcas registradas' : 'No encontramos coincidencias',
        message: _query.isEmpty
            ? 'Crea la primera marca para organizar el catálogo.'
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
            _BrandRow(
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
                indent: 76,
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
            hintText: 'Buscar marca o código',
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
          visible == total ? '$total marcas' : '$visible de $total',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        );
        final add = FilledButton.icon(
          onPressed: loading ? null : onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva marca'),
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

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.palette,
    required this.item,
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
  });

  final AppPalette palette;
  final MarcasResponseModel item;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (item.mrcaNombre ?? '').trim();
    final identification = (item.mrcaIdentificacion ?? '').trim();
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _BrandAvatar(
                palette: palette,
                name: name,
                logo: item.mrcaLogo ?? '',
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Marca sin nombre' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      identification.isEmpty ? 'Sin código de referencia' : identification,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
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

class _LogoEditor extends StatelessWidget {
  const _LogoEditor({
    required this.palette,
    required this.name,
    required this.logo,
    required this.onPick,
    required this.onRemove,
  });

  final AppPalette palette;
  final String name;
  final String logo;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.32 : 0.62),
        borderRadius: BorderRadius.circular(palette.radius(20)),
      ),
      child: Column(
        children: [
          _BrandAvatar(palette: palette, name: name, logo: logo, size: 104),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_rounded),
            label: Text(logo.isEmpty ? 'Cargar logo' : 'Cambiar logo'),
          ),
          if (logo.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Quitar')),
          ],
        ],
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.palette, required this.name, required this.logo, required this.size});

  final AppPalette palette;
  final String name;
  final String logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeImage(logo);
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => _fallback());
    } else if (logo.startsWith('http://') || logo.startsWith('https://')) {
      child = Image.network(logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback());
    } else {
      child = _fallback();
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size > 70 ? 10 : 7),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(palette.radius(size > 70 ? 24 : 17)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(palette.radius(size > 70 ? 16 : 11)), child: child),
    );
  }

  Widget _fallback() {
    final initial = name.trim().isEmpty ? 'M' : name.trim().substring(0, 1).toUpperCase();
    return Center(
      child: Text(initial, style: TextStyle(color: palette.primary, fontSize: size * 0.40, fontWeight: FontWeight.w900)),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.palette, required this.icon, required this.title, required this.message, this.action});

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        gradient: palette.panelGradient(tint: palette.primary),
        borderRadius: BorderRadius.circular(palette.radius(24)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.30), blurRadius: 20, offset: const Offset(0, 9))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: palette.primary),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

Uint8List? _decodeImage(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;
  try {
    if (clean.startsWith('data:image')) {
      final comma = clean.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(clean.substring(comma + 1));
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return base64Decode(clean);
    }
  } catch (_) {
    return null;
  }
  return null;
}

