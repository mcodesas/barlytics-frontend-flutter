import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _deleting ? null : () => context.go('/usuarios/nuevo'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            foregroundColor: Colors.white,
            expandedHeight: 218,
            title: const Text('Usuarios'),
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar')],
            flexibleSpace: FlexibleSpaceBar(
              background: TechBackground(
                padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.tertiary]),
                            borderRadius: BorderRadius.circular(23),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: const Icon(Icons.people_alt_outlined, color: Colors.white, size: 31),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Usuarios', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                              const SizedBox(height: 3),
                              Text('Consulta simplificada: nombre, empresa, sucursal, ciudad, estado y bloqueo.', style: TextStyle(color: Colors.white.withOpacity(0.74), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        _CountPill(label: '${filtered.length}/${_usuarios.length}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(0.16), blurRadius: 22, offset: const Offset(0, 12))],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, empresa, sucursal, ciudad, estado o bloqueo...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildContent(filtered)),
        ],
      ),
    );
  }

  Widget _buildContent(List<UsuariosResponseModel> usuarios) {
    if (_loading) return const Padding(padding: EdgeInsets.all(32), child: AppLoader());
    if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: AppErrorView(message: _error!, onRetry: _load));
    if (usuarios.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: AppEmptyView(message: 'No hay usuarios para mostrar.'));

    final isNarrow = MediaQuery.sizeOf(context).width < 820;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: isNarrow ? _buildCards(usuarios) : _buildTable(usuarios),
    );
  }

  Widget _buildTable(List<UsuariosResponseModel> usuarios) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
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
                    DataCell(_Actions(usuario: usuario, onDelete: () => _delete(usuario))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(List<UsuariosResponseModel> usuarios) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.go('/usuarios/${usuario.usuaId}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_fullName(usuario), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniInfo(icon: Icons.business_outlined, label: _label(_empresas, usuario.emprId)),
                      _MiniInfo(icon: Icons.store_mall_directory_outlined, label: _label(_sucursales, usuario.sucuId)),
                      _MiniInfo(icon: Icons.location_city_outlined, label: _label(_ciudades, usuario.ciudId)),
                      _StatusChip(label: _statusLabel(usuario.usuaEstado), positive: usuario.usuaEstado == 1),
                      _StatusChip(label: _blockedLabel(usuario.usuaBloqueado), positive: usuario.usuaBloqueado != 1),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: _Actions(usuario: usuario, onDelete: () => _delete(usuario))),
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
  const _Actions({required this.usuario, required this.onDelete});
  final UsuariosResponseModel usuario;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final id = usuario.usuaId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(color: AppColors.primary, icon: Icons.visibility_rounded, tooltip: 'Ver', onPressed: id == null ? null : () => context.go('/usuarios/$id')),
        _ActionIcon(color: AppColors.warning, icon: Icons.edit_rounded, tooltip: 'Modificar', onPressed: id == null ? null : () => context.go('/usuarios/$id/editar')),
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
  const _MiniInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.accent.withOpacity(0.22))),
        child: Text(label, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
      );
}
