import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuariosListPage extends ConsumerStatefulWidget {
  const UsuariosListPage({super.key});

  @override
  ConsumerState<UsuariosListPage> createState() => _UsuariosListPageState();
}

class _UsuariosListPageState extends ConsumerState<UsuariosListPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  List<UsuariosResponseModel> _usuarios = const <UsuariosResponseModel>[];
  Map<String, String> _ciudades = const <String, String>{};
  Map<String, String> _empresas = const <String, String>{};
  Map<String, String> _sucursales = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<Object>([
        api.get<List<UsuariosResponseModel>>(
          ApiPaths.usuarios,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((e) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false),
        ),
        _loadLabels(ApiPaths.ciudades, 'ciudId', const ['ciudNombre', 'ciudCodigoDane']),
        _loadLabels(ApiPaths.empresas, 'emprId', const ['empreNombreComercial', 'emprRazonSocial']),
        _loadLabels(ApiPaths.sucursales, 'sucuId', const ['sucuNombre', 'sucuCodigoInterno']),
      ]);

      _usuarios = (results[0] as dynamic).data as List<UsuariosResponseModel>? ?? const <UsuariosResponseModel>[];
      _ciudades = results[1] as Map<String, String>;
      _empresas = results[2] as Map<String, String>;
      _sucursales = results[3] as Map<String, String>;
    } catch (e) {
      _error = 'No fue posible cargar usuarios: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, String>> _loadLabels(String path, String idField, List<String> labelFields) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get<Map<String, String>>(
      path,
      (json) {
        final items = json as List? ?? const <Object?>[];
        final labels = <String, String>{};
        for (final item in items.whereType<Map>()) {
          final raw = Map<String, dynamic>.from(item);
          final id = raw[idField]?.toString();
          if (id == null || id.isEmpty) continue;
          final parts = labelFields
              .map((field) => raw[field]?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
          labels[id] = parts.isEmpty ? 'ID $id' : parts.join(' - ');
        }
        return labels;
      },
    );
    return response.data ?? const <String, String>{};
  }

  List<UsuariosResponseModel> get _filteredUsuarios {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _usuarios;
    return _usuarios.where((usuario) {
      final values = [
        _fullName(usuario),
        _empresas[usuario.emprId?.toString()] ?? '',
        _sucursales[usuario.sucuId?.toString()] ?? '',
        _ciudades[usuario.ciudId?.toString()] ?? '',
        _statusLabel(usuario.usuaEstado),
        _blockedLabel(usuario.usuaBloqueado),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsuarios;
    final palette = ref.watch(selectedAppPaletteProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        onPressed: _deleting ? null : () => context.go('/usuarios/nuevo'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear usuario'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _UsuariosToolbar(
                          total: _usuarios.length,
                          visible: filtered.length,
                          controller: _searchController,
                          palette: palette,
                          loading: _loading,
                          onChanged: (_) => setState(() {}),
                          onRefresh: _load,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildContent(filtered, palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<UsuariosResponseModel> usuarios, AppPalette palette) {
    if (_loading) return const Padding(padding: EdgeInsets.all(32), child: AppLoader());
    if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: AppErrorView(message: _error!, onRetry: _load));
    if (usuarios.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: AppEmptyView(message: 'No hay usuarios para mostrar.'));

    final isNarrow = MediaQuery.sizeOf(context).width < 820;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: isNarrow ? _buildCards(usuarios, palette) : _buildTable(usuarios, palette),
    );
  }

  Widget _buildTable(List<UsuariosResponseModel> usuarios, AppPalette palette) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(palette.secondary.withOpacity(palette.darkBackground ? 0.12 : 0.07)),
            headingTextStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
            dataTextStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
            headingRowHeight: 58,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 78,
            horizontalMargin: 18,
            columnSpacing: 18,
            columns: const [
              DataColumn(label: SizedBox(width: 220, child: Text('Nombres'))),
              DataColumn(label: SizedBox(width: 220, child: Text('Empresa'))),
              DataColumn(label: SizedBox(width: 200, child: Text('Sucursal'))),
              DataColumn(label: SizedBox(width: 180, child: Text('Ciudad'))),
              DataColumn(label: SizedBox(width: 120, child: Text('Estado'))),
              DataColumn(label: SizedBox(width: 130, child: Text('Bloqueo'))),
              DataColumn(label: SizedBox(width: 180, child: Text('Acciones'))),
            ],
            rows: [
              for (final usuario in usuarios)
                DataRow(
                  onSelectChanged: (_) => context.go('/usuarios/${usuario.usuaId}'),
                  cells: [
                    DataCell(SizedBox(width: 220, child: Text(_fullName(usuario), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)))),
                    DataCell(SizedBox(width: 220, child: Text(_label(_empresas, usuario.emprId), maxLines: 2, overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(width: 200, child: Text(_label(_sucursales, usuario.sucuId), maxLines: 2, overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(width: 180, child: Text(_label(_ciudades, usuario.ciudId), maxLines: 2, overflow: TextOverflow.ellipsis))),
                    DataCell(_StatusChip(label: _statusLabel(usuario.usuaEstado), positive: usuario.usuaEstado == 1)),
                    DataCell(_StatusChip(label: _blockedLabel(usuario.usuaBloqueado), positive: usuario.usuaBloqueado != 1)),
                    DataCell(_Actions(usuario: usuario, onDelete: () => _delete(usuario), palette: palette)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(List<UsuariosResponseModel> usuarios, AppPalette palette) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        return Card(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: palette.cardBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.go('/usuarios/${usuario.usuaId}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_fullName(usuario), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniInfo(icon: Icons.business_outlined, label: _label(_empresas, usuario.emprId), palette: palette),
                      _MiniInfo(icon: Icons.store_mall_directory_outlined, label: _label(_sucursales, usuario.sucuId), palette: palette),
                      _MiniInfo(icon: Icons.location_city_outlined, label: _label(_ciudades, usuario.ciudId), palette: palette),
                      _StatusChip(label: _statusLabel(usuario.usuaEstado), positive: usuario.usuaEstado == 1),
                      _StatusChip(label: _blockedLabel(usuario.usuaBloqueado), positive: usuario.usuaBloqueado != 1),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: _Actions(usuario: usuario, onDelete: () => _delete(usuario), palette: palette)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(UsuariosResponseModel usuario) async {
    final id = usuario.usuaId;
    if (id == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirmar eliminación',
      message: '¿Deseas eliminar o inactivar este usuario?',
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete<void>('${ApiPaths.usuarios}/$id', (_) {});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario procesado correctamente.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible procesar el usuario: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _fullName(UsuariosResponseModel usuario) => [
        usuario.usuaPrimerNombre,
        usuario.usuaSegundoNombre,
        usuario.usuaPrimerApellido,
        usuario.usuaSegundoApellido,
      ].where((value) => value != null && value.trim().isNotEmpty).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  String _label(Map<String, String> labels, int? id) => id == null ? '-' : labels[id.toString()] ?? 'ID $id';
  String _statusLabel(int? value) => value == 1 ? 'Activo' : 'Inactivo';
  String _blockedLabel(int? value) => value == 1 ? 'Bloqueado' : 'Activo';
}

class _Actions extends StatelessWidget {
  const _Actions({required this.usuario, required this.onDelete, required this.palette});
  final UsuariosResponseModel usuario;
  final VoidCallback onDelete;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final id = usuario.usuaId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(color: palette.secondary, icon: Icons.visibility_rounded, tooltip: 'Ver', onPressed: id == null ? null : () => context.go('/usuarios/$id')),
        _ActionIcon(color: palette.primary, icon: Icons.edit_rounded, tooltip: 'Modificar', onPressed: id == null ? null : () => context.go('/usuarios/$id/editar')),
        _ActionIcon(color: AppColors.danger, icon: Icons.delete_outline_rounded, tooltip: 'Eliminar/Inactivar', onPressed: id == null ? null : onDelete),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.color, required this.icon, required this.tooltip, required this.onPressed});
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton.filledTonal(
          tooltip: tooltip,
          style: IconButton.styleFrom(backgroundColor: color.withOpacity(0.12), foregroundColor: color),
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.18))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.label, required this.palette});
  final IconData icon;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: palette.secondary.withOpacity(0.09), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: palette.secondary),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textPrimary))),
          ],
        ),
      );
}

class _UsuariosToolbar extends StatelessWidget {
  const _UsuariosToolbar({
    required this.total,
    required this.visible,
    required this.controller,
    required this.palette,
    required this.loading,
    required this.onChanged,
    required this.onRefresh,
  });

  final int total;
  final int visible;
  final TextEditingController controller;
  final AppPalette palette;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final info = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.people_alt_rounded, color: palette.onPrimary, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Administración de usuarios', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text('Consulta usuarios, sucursales asignadas, estado y bloqueo.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CountPill(label: '$visible/$total', palette: palette),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: loading ? null : onRefresh,
                tooltip: 'Actualizar',
                icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
              ),
            ],
          );
          final search = TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre, empresa, sucursal, ciudad o estado...',
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 14), search]);
          return Row(children: [Expanded(flex: 5, child: info), const SizedBox(width: 16), Expanded(flex: 4, child: search)]);
        },
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.palette});
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.secondary.withOpacity(0.22))),
        child: Text(label, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
      );
}
