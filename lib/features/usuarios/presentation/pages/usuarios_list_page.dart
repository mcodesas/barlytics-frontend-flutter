import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_control_metrics.dart';
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
  static const int _pageSize = 12;

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _deleting = false;
  String? _error;
  int? _statusFilter;
  bool? _blockedFilter;
  int _page = 0;

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
              .map((item) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false),
        ),
        _loadLabels(
          ApiPaths.ciudades,
          'ciudId',
          const <String>['ciudNombre', 'ciudCodigoDane'],
        ),
        _loadLabels(
          ApiPaths.empresas,
          'emprId',
          const <String>['empreNombreComercial', 'emprRazonSocial'],
        ),
        _loadLabels(
          ApiPaths.sucursales,
          'sucuId',
          const <String>['sucuNombre', 'sucuCodigoInterno'],
        ),
      ]);

      final usuarios = (results[0] as dynamic).data as List<UsuariosResponseModel>? ??
          const <UsuariosResponseModel>[];
      usuarios.sort((a, b) => _fullName(a).toLowerCase().compareTo(_fullName(b).toLowerCase()));

      _usuarios = usuarios;
      _ciudades = results[1] as Map<String, String>;
      _empresas = results[2] as Map<String, String>;
      _sucursales = results[3] as Map<String, String>;
      _normalizePage();
    } catch (error) {
      _error = 'No fue posible cargar los usuarios: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, String>> _loadLabels(
    String path,
    String idField,
    List<String> labelFields,
  ) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get<Map<String, String>>(
      path,
      (json) {
        final labels = <String, String>{};
        for (final item in (json as List? ?? const <Object?>[]).whereType<Map>()) {
          final raw = Map<String, dynamic>.from(item);
          final id = raw[idField]?.toString();
          if (id == null || id.isEmpty) continue;
          final parts = labelFields
              .map((field) => raw[field]?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
          labels[id] = parts.isEmpty ? 'ID $id' : parts.join(' · ');
        }
        return labels;
      },
    );
    return response.data ?? const <String, String>{};
  }

  List<UsuariosResponseModel> get _filteredUsuarios {
    final query = _searchController.text.trim().toLowerCase();
    return _usuarios.where((usuario) {
      if (_statusFilter != null && usuario.usuaEstado != _statusFilter) return false;
      final isBlocked = usuario.usuaBloqueado == 1;
      if (_blockedFilter != null && isBlocked != _blockedFilter) return false;
      if (query.isEmpty) return true;

      final values = <String>[
        _fullName(usuario),
        usuario.usuaEmail ?? '',
        usuario.usuaTelefonoPrincipal ?? '',
        usuario.usuaTelefonoSecundario ?? '',
        _label(_empresas, usuario.emprId),
        _label(_sucursales, usuario.sucuId),
        _label(_ciudades, usuario.ciudId),
        ..._branchLabels(usuario),
        _statusLabel(usuario.usuaEstado),
        _blockedLabel(usuario.usuaBloqueado),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList(growable: false);
  }

  List<UsuariosResponseModel> get _pagedUsuarios {
    final filtered = _filteredUsuarios;
    final start = _page * _pageSize;
    if (start >= filtered.length) return const <UsuariosResponseModel>[];
    final end = (start + _pageSize).clamp(0, filtered.length).toInt();
    return filtered.sublist(start, end);
  }

  int get _pageCount {
    final count = _filteredUsuarios.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  int get _activeCount => _usuarios.where((usuario) => usuario.usuaEstado == 1).length;
  int get _inactiveCount => _usuarios.where((usuario) => usuario.usuaEstado != 1).length;
  int get _blockedCount => _usuarios.where((usuario) => usuario.usuaBloqueado == 1).length;
  int get _availableCount => _usuarios.where((usuario) => usuario.usuaEstado == 1 && usuario.usuaBloqueado != 1).length;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final filtered = _filteredUsuarios;
    final pageItems = _pagedUsuarios;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 104),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _UsersHeader(
                          palette: palette,
                          loading: _loading,
                          onRefresh: _load,
                          onCreate: _deleting ? null : () => context.go('/usuarios/nuevo'),
                        ),
                        const SizedBox(height: 12),
                        _UsersSummary(
                          palette: palette,
                          total: _usuarios.length,
                          active: _activeCount,
                          available: _availableCount,
                          blocked: _blockedCount,
                          onTotal: () => _applyQuickFilter(),
                          onActive: () => _applyQuickFilter(status: 1),
                          onAvailable: () => _applyQuickFilter(status: 1, blocked: false),
                          onBlocked: () => _applyQuickFilter(blocked: true),
                        ),
                        const SizedBox(height: 12),
                        _UsersFilters(
                          palette: palette,
                          controller: _searchController,
                          statusFilter: _statusFilter,
                          blockedFilter: _blockedFilter,
                          visible: filtered.length,
                          total: _usuarios.length,
                          onSearchChanged: (_) => _filtersChanged(),
                          onStatusChanged: (value) {
                            _statusFilter = value;
                            _filtersChanged();
                          },
                          onBlockedChanged: (value) {
                            _blockedFilter = value;
                            _filtersChanged();
                          },
                          onClear: _clearFilters,
                        ),
                        const SizedBox(height: 12),
                        _buildContent(pageItems, palette),
                        if (!_loading && _error == null && filtered.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _PaginationBar(
                            palette: palette,
                            currentPage: _page,
                            pageCount: _pageCount,
                            pageSize: _pageSize,
                            total: filtered.length,
                            onPrevious: _page == 0 ? null : () => setState(() => _page--),
                            onNext: _page + 1 >= _pageCount ? null : () => setState(() => _page++),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<UsuariosResponseModel> usuarios, AppPalette palette) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: AppLoader(),
      );
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }
    if (_filteredUsuarios.isEmpty) {
      return _EmptyUsersResult(
        palette: palette,
        hasFilters: _hasFilters,
        onClear: _clearFilters,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final usuario in usuarios)
              SizedBox(
                width: width,
                child: _UserCard(
                  usuario: usuario,
                  palette: palette,
                  fullName: _fullName(usuario),
                  company: _label(_empresas, usuario.emprId),
                  primaryBranch: _label(_sucursales, usuario.sucuId),
                  city: _label(_ciudades, usuario.ciudId),
                  branchCount: _branchLabels(usuario).length,
                  onOpen: () => _showUserPanel(usuario),
                  onEdit: usuario.usuaId == null
                      ? null
                      : () => context.go('/usuarios/${usuario.usuaId}/editar'),
                  onRoles: usuario.usuaId == null
                      ? null
                      : () => context.go('/usuarios/${usuario.usuaId}/roles'),
                  onDeactivate: usuario.usuaId == null ? null : () => _delete(usuario),
                ),
              ),
          ],
        );
      },
    );
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      _statusFilter != null ||
      _blockedFilter != null;

  void _filtersChanged() {
    setState(() => _page = 0);
  }

  void _applyQuickFilter({int? status, bool? blocked}) {
    setState(() {
      _statusFilter = status;
      _blockedFilter = blocked;
      _page = 0;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _blockedFilter = null;
      _page = 0;
    });
  }

  void _normalizePage() {
    final maxPage = _pageCount - 1;
    if (_page > maxPage) _page = maxPage < 0 ? 0 : maxPage;
  }

  Future<void> _showUserPanel(UsuariosResponseModel usuario) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final branches = _branchLabels(usuario);
    final id = usuario.usuaId;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
              ),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: 32,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _UserPanelHeader(
                            palette: palette,
                            name: _fullName(usuario),
                            email: usuario.usuaEmail ?? 'Correo no registrado',
                            status: _statusLabel(usuario.usuaEstado),
                            blocked: usuario.usuaBloqueado == 1,
                            photo: usuario.usuaFoto,
                            onClose: () => Navigator.pop(sheetContext),
                          ),
                          const SizedBox(height: 16),
                          _PanelSection(
                            palette: palette,
                            title: 'Acceso y operación',
                            icon: Icons.badge_outlined,
                            children: [
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Empresa',
                                value: _label(_empresas, usuario.emprId),
                                icon: Icons.business_outlined,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Sucursal principal',
                                value: _label(_sucursales, usuario.sucuId),
                                icon: Icons.star_outline_rounded,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Sucursales asignadas',
                                value: branches.isEmpty ? 'Sin sucursales asignadas' : branches.join(', '),
                                icon: Icons.store_mall_directory_outlined,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Ciudad',
                                value: _label(_ciudades, usuario.ciudId),
                                icon: Icons.location_city_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PanelSection(
                            palette: palette,
                            title: 'Contacto',
                            icon: Icons.contact_phone_outlined,
                            children: [
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Correo',
                                value: usuario.usuaEmail ?? 'No registrado',
                                icon: Icons.alternate_email_rounded,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Teléfono principal',
                                value: _display(usuario.usuaTelefonoPrincipal),
                                icon: Icons.phone_outlined,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Teléfono secundario',
                                value: _display(usuario.usuaTelefonoSecundario),
                                icon: Icons.phone_android_outlined,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Dirección',
                                value: _display(usuario.usuaDireccion),
                                icon: Icons.location_on_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PanelSection(
                            palette: palette,
                            title: 'Información adicional',
                            icon: Icons.info_outline_rounded,
                            children: [
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Fecha de nacimiento',
                                value: _display(usuario.usuaFechaNacimiento),
                                icon: Icons.cake_outlined,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Último cambio',
                                value: _display(usuario.usuaFechaCambio),
                                icon: Icons.update_rounded,
                              ),
                              _PanelInfoRow(
                                palette: palette,
                                label: 'Registrado por',
                                value: _display(usuario.usuaRegistradoPor),
                                icon: Icons.person_pin_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final actions = <Widget>[
                                OutlinedButton.icon(
                                  onPressed: id == null
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                          context.go('/usuarios/$id/roles');
                                        },
                                  icon: const Icon(Icons.admin_panel_settings_outlined),
                                  label: const Text('Roles'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: id == null
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                          context.go('/usuarios/$id/editar');
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: BorderSide(color: AppColors.danger.withOpacity(0.35)),
                                  ),
                                  onPressed: id == null || _deleting
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                          _delete(usuario);
                                        },
                                  icon: const Icon(Icons.person_off_outlined),
                                  label: const Text('Inactivar'),
                                ),
                              ];
                              if (constraints.maxWidth < 560) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var index = 0; index < actions.length; index++) ...[
                                      if (index > 0) const SizedBox(height: 9),
                                      actions[index],
                                    ],
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  for (var index = 0; index < actions.length; index++) ...[
                                    if (index > 0) const SizedBox(width: 9),
                                    Expanded(child: actions[index]),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
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
      title: 'Inactivar usuario',
      message: '¿Deseas inactivar a ${_fullName(usuario)}? El usuario dejará de tener acceso al sistema.',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete<void>('${ApiPaths.usuarios}/$id', (_) {});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario inactivado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible inactivar el usuario: $error')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  List<String> _branchLabels(UsuariosResponseModel usuario) {
    final ids = usuario.sucursalIds.isEmpty
        ? <int>[if (usuario.sucuId != null) usuario.sucuId!]
        : usuario.sucursalIds;
    return ids
        .map((id) => _sucursales[id.toString()] ?? 'Sucursal $id')
        .toSet()
        .toList(growable: false);
  }

  String _fullName(UsuariosResponseModel usuario) {
    final name = <String?>[
      usuario.usuaPrimerNombre,
      usuario.usuaSegundoNombre,
      usuario.usuaPrimerApellido,
      usuario.usuaSegundoApellido,
    ]
        .where((value) => value != null && value.trim().isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return name.isEmpty ? 'Usuario sin nombre' : name;
  }

  String _label(Map<String, String> labels, int? id) =>
      id == null ? 'No asignado' : labels[id.toString()] ?? 'ID $id';

  String _display(String? value) =>
      value == null || value.trim().isEmpty ? 'No registrado' : value.trim();

  String _statusLabel(int? value) => value == 1 ? 'Activo' : 'Inactivo';
  String _blockedLabel(int? value) => value == 1 ? 'Bloqueado' : 'Disponible';
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.palette,
    required this.loading,
    required this.onRefresh,
    required this.onCreate,
  });

  final AppPalette palette;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final title = Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.manage_accounts_rounded, color: palette.onPrimary, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administración de usuarios',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Controla accesos, sucursales, estado y roles desde un solo lugar.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Actualizar usuarios',
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nuevo usuario'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 14),
                actions,
              ],
            );
          }
          return Row(children: [Expanded(child: title), const SizedBox(width: 14), actions]);
        },
      ),
    );
  }
}

class _UsersSummary extends StatelessWidget {
  const _UsersSummary({
    required this.palette,
    required this.total,
    required this.active,
    required this.available,
    required this.blocked,
    required this.onTotal,
    required this.onActive,
    required this.onAvailable,
    required this.onBlocked,
  });

  final AppPalette palette;
  final int total;
  final int active;
  final int available;
  final int blocked;
  final VoidCallback onTotal;
  final VoidCallback onActive;
  final VoidCallback onAvailable;
  final VoidCallback onBlocked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = <Widget>[
          _SummaryTile(
            palette: palette,
            label: 'Usuarios',
            value: total,
            icon: Icons.groups_2_outlined,
            color: palette.secondary,
            onTap: onTotal,
          ),
          _SummaryTile(
            palette: palette,
            label: 'Activos',
            value: active,
            icon: Icons.verified_user_outlined,
            color: AppColors.success,
            onTap: onActive,
          ),
          _SummaryTile(
            palette: palette,
            label: 'Con acceso',
            value: available,
            icon: Icons.lock_open_rounded,
            color: AppColors.info,
            onTap: onAvailable,
          ),
          _SummaryTile(
            palette: palette,
            label: 'Bloqueados',
            value: blocked,
            icon: Icons.lock_outline_rounded,
            color: AppColors.warning,
            onTap: onBlocked,
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersFilters extends StatelessWidget {
  const _UsersFilters({
    required this.palette,
    required this.controller,
    required this.statusFilter,
    required this.blockedFilter,
    required this.visible,
    required this.total,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onBlockedChanged,
    required this.onClear,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final int? statusFilter;
  final bool? blockedFilter;
  final int visible;
  final int total;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final ValueChanged<bool?> onBlockedChanged;
  final VoidCallback onClear;

  bool get hasFilters =>
      controller.text.trim().isNotEmpty || statusFilter != null || blockedFilter != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar nombre, correo, empresa o sucursal',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );

          final status = DropdownButtonFormField<int?>(
            value: statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.toggle_on_outlined),
              hintText: 'Estado',
            ).compactFilter(),
            items: const <DropdownMenuItem<int?>>[
              DropdownMenuItem<int?>(value: null, child: Text('Todos los estados')),
              DropdownMenuItem<int?>(value: 1, child: Text('Activos')),
              DropdownMenuItem<int?>(value: 0, child: Text('Inactivos')),
            ],
            onChanged: onStatusChanged,
          );

          final access = DropdownButtonFormField<bool?>(
            value: blockedFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline_rounded),
              hintText: 'Acceso',
            ).compactFilter(),
            items: const <DropdownMenuItem<bool?>>[
              DropdownMenuItem<bool?>(value: null, child: Text('Todos los accesos')),
              DropdownMenuItem<bool?>(value: false, child: Text('Disponibles')),
              DropdownMenuItem<bool?>(value: true, child: Text('Bloqueados')),
            ],
            onChanged: onBlockedChanged,
          );

          final result = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$visible de $total',
                  style: TextStyle(
                    color: palette.secondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Limpiar filtros',
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 9),
                    Expanded(child: access),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: result),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: search),
              const SizedBox(width: 9),
              Expanded(flex: 2, child: status),
              const SizedBox(width: 9),
              Expanded(flex: 2, child: access),
              const SizedBox(width: 9),
              result,
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.usuario,
    required this.palette,
    required this.fullName,
    required this.company,
    required this.primaryBranch,
    required this.city,
    required this.branchCount,
    required this.onOpen,
    required this.onEdit,
    required this.onRoles,
    required this.onDeactivate,
  });

  final UsuariosResponseModel usuario;
  final AppPalette palette;
  final String fullName;
  final String company;
  final String primaryBranch;
  final String city;
  final int branchCount;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onRoles;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final active = usuario.usuaEstado == 1;
    final blocked = usuario.usuaBloqueado == 1;

    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow.withOpacity(0.55),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UserAvatar(name: fullName, photo: usuario.usuaFoto, palette: palette, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          usuario.usuaEmail?.trim().isNotEmpty == true
                              ? usuario.usuaEmail!.trim()
                              : 'Correo no registrado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          onOpen();
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'roles':
                          onRoles?.call();
                          break;
                        case 'deactivate':
                          onDeactivate?.call();
                          break;
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'view',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_outlined),
                          title: Text('Ver información'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modificar'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'roles',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.admin_panel_settings_outlined),
                          title: Text('Administrar roles'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'deactivate',
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_off_outlined, color: AppColors.danger),
                          title: const Text('Inactivar', style: TextStyle(color: AppColors.danger)),
                          enabled: onDeactivate != null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusBadge(
                    label: active ? 'Activo' : 'Inactivo',
                    icon: active ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                    color: active ? AppColors.success : AppColors.warning,
                  ),
                  _StatusBadge(
                    label: blocked ? 'Bloqueado' : 'Con acceso',
                    icon: blocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                    color: blocked ? AppColors.danger : AppColors.info,
                  ),
                  _StatusBadge(
                    label: '$branchCount ${branchCount == 1 ? 'sucursal' : 'sucursales'}',
                    icon: Icons.storefront_outlined,
                    color: palette.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _UserInfoLine(
                palette: palette,
                icon: Icons.business_outlined,
                label: company,
              ),
              const SizedBox(height: 7),
              _UserInfoLine(
                palette: palette,
                icon: Icons.store_mall_directory_outlined,
                label: primaryBranch,
              ),
              const SizedBox(height: 7),
              _UserInfoLine(
                palette: palette,
                icon: Icons.location_city_outlined,
                label: city,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRoles,
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                      label: const Text('Roles'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, required this.palette, required this.size, this.photo});

  final String name;
  final String? photo;
  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageValue = photo?.trim() ?? '';
    Widget fallback() {
      final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
      final initials = parts.isEmpty
          ? 'U'
          : parts.length == 1
              ? parts.first.substring(0, 1).toUpperCase()
              : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary])),
        child: Text(initials, style: TextStyle(color: palette.onPrimary, fontSize: size * 0.34, fontWeight: FontWeight.w900)),
      );
    }

    Widget image = fallback();
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          image = Image.memory(
            base64Decode(imageValue.substring(commaIndex + 1)),
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }
    } else if (imageValue.isNotEmpty) {
      image = Image.network(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [BoxShadow(color: palette.primary.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.30), child: image),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _UserInfoLine extends StatelessWidget {
  const _UserInfoLine({required this.palette, required this.icon, required this.label});

  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: palette.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.palette,
    required this.currentPage,
    required this.pageCount,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final AppPalette palette;
  final int currentPage;
  final int pageCount;
  final int pageSize;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, total).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$start-$end de $total usuarios',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            'Página ${currentPage + 1} de $pageCount',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Página anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Página siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyUsersResult extends StatelessWidget {
  const _EmptyUsersResult({
    required this.palette,
    required this.hasFilters,
    required this.onClear,
  });

  final AppPalette palette;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (!hasFilters) {
      return const AppEmptyView(message: 'Todavía no hay usuarios registrados.');
    }
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.person_search_rounded, size: 48, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No encontramos usuarios con estos filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Limpia los filtros o cambia la búsqueda para ver más resultados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

class _UserPanelHeader extends StatelessWidget {
  const _UserPanelHeader({
    required this.palette,
    required this.name,
    required this.email,
    required this.status,
    required this.blocked,
    required this.photo,
    required this.onClose,
  });

  final AppPalette palette;
  final String name;
  final String email;
  final String status;
  final bool blocked;
  final String? photo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserAvatar(name: name, photo: photo, palette: palette, size: 58),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusBadge(
                    label: status,
                    icon: status == 'Activo'
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: status == 'Activo' ? AppColors.success : AppColors.warning,
                  ),
                  _StatusBadge(
                    label: blocked ? 'Bloqueado' : 'Con acceso',
                    icon: blocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                    color: blocked ? AppColors.danger : AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Cerrar',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.palette,
    required this.title,
    required this.icon,
    required this.children,
  });

  final AppPalette palette;
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) Divider(height: 15, color: palette.cardBorder),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _PanelInfoRow extends StatelessWidget {
  const _PanelInfoRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
  });

  final AppPalette palette;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 9),
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
