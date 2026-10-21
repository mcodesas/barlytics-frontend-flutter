import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuarioRolesPage extends ConsumerStatefulWidget {
  const UsuarioRolesPage({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  ConsumerState<UsuarioRolesPage> createState() => _UsuarioRolesPageState();
}

class _UsuarioRolesPageState extends ConsumerState<UsuarioRolesPage> {
  bool _loading = true;
  bool _saving = false;
  List<_RoleOption> _roles = const <_RoleOption>[];
  String _userName = 'Usuario';
  String _userEmail = 'Correo no disponible';
  String? _error;

  int get _selectedCount => _roles.where((role) => role.assigned).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait<Object>([
        api.get<List<_RoleOption>>(
          '${ApiPaths.usuarios}/${widget.usuarioId}/roles',
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => _RoleOption.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false),
        ),
        api.get<UsuariosResponseModel>(
          '${ApiPaths.usuarios}/${widget.usuarioId}',
          (json) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        ),
      ]);

      _roles = (results[0] as dynamic).data as List<_RoleOption>? ?? const <_RoleOption>[];
      final usuario = (results[1] as dynamic).data as UsuariosResponseModel?;
      if (usuario != null) {
        _userName = <String?>[
          usuario.usuaPrimerNombre,
          usuario.usuaSegundoNombre,
          usuario.usuaPrimerApellido,
          usuario.usuaSegundoApellido,
        ]
            .where((value) => value != null && value.trim().isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (_userName.isEmpty) _userName = 'Usuario';
        _userEmail = usuario.usuaEmail?.trim().isNotEmpty == true
            ? usuario.usuaEmail!.trim()
            : 'Correo no registrado';
      }
    } catch (error) {
      _error = 'No fue posible cargar los roles del usuario: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final roleIds = _roles.where((role) => role.assigned).map((role) => role.roleId).toList(growable: false);
      await api.put(
        '${ApiPaths.usuarios}/${widget.usuarioId}/roles',
        <String, dynamic>{'roleIds': roleIds},
        (json) => json,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roles actualizados correctamente.')),
      );
      // Este formulario es exclusivo de roles: al guardar regresamos al listado.
      context.go('/usuarios');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar los roles: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _randomPassword() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post<Map<String, dynamic>>(
        '${ApiPaths.usuarios}/${widget.usuarioId}/password/random',
        const <String, dynamic>{
          'longitud': 12,
          'forzarCambioPrimerIngreso': true,
        },
        (json) => Map<String, dynamic>.from(json as Map),
      );
      final password = response.data?['passwordTemporal']?.toString() ?? '';
      if (!mounted) return;
      await _showPasswordPanel(password);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar la contraseña: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPasswordPanel(String password) async {
    final palette = ref.read(selectedAppPaletteProvider);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Icons.password_rounded, color: palette.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contraseña temporal',
                              style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'El usuario deberá cambiarla al iniciar sesión.',
                              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.68),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: SelectableText(
                      password.isEmpty ? 'No fue posible obtener la contraseña.' : password,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: password.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: password));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Contraseña copiada.')),
                            );
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar contraseña'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectAll(bool selected) {
    setState(() {
      _roles = _roles.map((role) => role.copyWith(assigned: selected)).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppPageBackground()),
            Positioned.fill(child: AppLoader()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RolesHeader(
                      palette: palette,
                      userName: _userName,
                      userEmail: _userEmail,
                      selectedCount: _selectedCount,
                      total: _roles.length,
                      onBack: () => context.go('/usuarios'),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final title = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Permisos funcionales',
                                      style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'El menú y las operaciones disponibles se construyen a partir de estos roles.',
                                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                );
                                final tools = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _saving ? null : () => _selectAll(true),
                                      icon: const Icon(Icons.done_all_rounded),
                                      label: const Text('Seleccionar todos'),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      onPressed: _saving ? null : () => _selectAll(false),
                                      icon: const Icon(Icons.remove_done_rounded),
                                      label: const Text('Limpiar'),
                                    ),
                                  ],
                                );
                                if (constraints.maxWidth < 720) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [title, const SizedBox(height: 8), SingleChildScrollView(scrollDirection: Axis.horizontal, child: tools)],
                                  );
                                }
                                return Row(children: [Expanded(child: title), const SizedBox(width: 10), tools]);
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.09),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.danger.withOpacity(0.18)),
                                ),
                                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Expanded(
                              child: _roles.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No hay roles disponibles.',
                                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GridView.builder(
                                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: constraints.maxWidth < 560 ? constraints.maxWidth : 390,
                                            mainAxisExtent: 128,
                                            mainAxisSpacing: 10,
                                            crossAxisSpacing: 10,
                                          ),
                                          itemCount: _roles.length,
                                          itemBuilder: (_, index) {
                                            final role = _roles[index];
                                            return _RoleCard(
                                              palette: palette,
                                              role: role,
                                              onChanged: (value) => setState(() => _roles[index] = role.copyWith(assigned: value)),
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final close = OutlinedButton.icon(
                                  onPressed: _saving ? null : () => context.go('/usuarios'),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('Volver'),
                                );
                                final password = OutlinedButton.icon(
                                  onPressed: _saving ? null : _randomPassword,
                                  icon: const Icon(Icons.password_rounded),
                                  label: const Text('Nueva contraseña'),
                                );
                                final save = AppButton(
                                  label: 'Guardar roles',
                                  icon: Icons.save_rounded,
                                  loading: _saving,
                                  onPressed: _save,
                                );
                                if (constraints.maxWidth < 720) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [close, const SizedBox(height: 9), password, const SizedBox(height: 9), save],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: close),
                                    const SizedBox(width: 10),
                                    Expanded(child: password),
                                    const SizedBox(width: 10),
                                    Expanded(child: save),
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
          ),
        ],
      ),
    );
  }
}

class _RolesHeader extends StatelessWidget {
  const _RolesHeader({
    required this.palette,
    required this.userName,
    required this.userEmail,
    required this.selectedCount,
    required this.total,
    required this.onBack,
  });

  final AppPalette palette;
  final String userName;
  final String userEmail;
  final int selectedCount;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 9))],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Volver a usuarios',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          _RolesAvatar(name: userName, palette: palette),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.secondary.withOpacity(0.2)),
            ),
            child: Text(
              '$selectedCount/$total roles',
              style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolesAvatar extends StatelessWidget {
  const _RolesAvatar({required this.name, required this.palette});

  final String name;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(initials, style: TextStyle(color: palette.onPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.palette, required this.role, required this.onChanged});

  final AppPalette palette;
  final _RoleOption role;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = role.assigned;
    return Material(
      color: selected
          ? palette.secondary.withOpacity(palette.darkBackground ? 0.13 : 0.08)
          : palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? palette.secondary.withOpacity(0.46) : palette.cardBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? palette.secondary.withOpacity(0.15) : palette.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: selected ? palette.secondary : palette.textSecondary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.description.isEmpty ? 'Sin descripción' : role.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: selected,
                activeColor: palette.actionColor,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.roleId,
    required this.name,
    required this.description,
    required this.assigned,
  });

  final int roleId;
  final String name;
  final String description;
  final bool assigned;

  factory _RoleOption.fromJson(Map<String, dynamic> json) => _RoleOption(
        roleId: int.tryParse(json['roleId']?.toString() ?? '') ?? 0,
        name: json['roleNombre']?.toString() ?? 'Rol',
        description: json['roleDescripcion']?.toString() ?? '',
        assigned: json['asignado'] == true,
      );

  _RoleOption copyWith({bool? assigned}) => _RoleOption(
        roleId: roleId,
        name: name,
        description: description,
        assigned: assigned ?? this.assigned,
      );
}
