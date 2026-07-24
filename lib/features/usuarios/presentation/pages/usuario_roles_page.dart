import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<List<_RoleOption>>(
        '${ApiPaths.usuarios}/${widget.usuarioId}/roles',
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => _RoleOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
      _roles = response.data ?? const <_RoleOption>[];
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final roleIds = _roles.where((r) => r.assigned).map((r) => r.roleId).toList();
      await api.put('${ApiPaths.usuarios}/${widget.usuarioId}/roles', {'roleIds': roleIds}, (json) => json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roles asignados correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible asignar roles: $e')));
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
        {'longitud': 12, 'forzarCambioPrimerIngreso': true},
        (json) => Map<String, dynamic>.from(json as Map),
      );
      final pass = response.data?['passwordTemporal']?.toString() ?? '';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Contraseña temporal generada'),
          content: SelectableText(pass, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible generar contraseña: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [Positioned.fill(child: AppPageBackground()), Positioned.fill(child: AppLoader())]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.secondary.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          IconButton.filledTonal(onPressed: () => context.go('/usuarios'), tooltip: 'Volver', icon: const Icon(Icons.arrow_back_rounded)),
                          const SizedBox(width: 10),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(15)),
                            child: Icon(Icons.admin_panel_settings_rounded, color: palette.onPrimary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Asignar roles', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                                const SizedBox(height: 2),
                                Text('Define las funciones y opciones de menú disponibles para el usuario.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: palette.cardBorder)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Roles disponibles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: palette.textPrimary)),
                              const SizedBox(height: 6),
                              Text('Marca los roles que debe tener el usuario. El menú se construirá a partir de estas asignaciones.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.danger.withOpacity(0.18))),
                                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _roles.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: palette.cardBorder),
                                  itemBuilder: (_, index) {
                                    final role = _roles[index];
                                    return CheckboxListTile(
                                      value: role.assigned,
                                      activeColor: palette.actionColor,
                                      title: Text(role.name, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                                      subtitle: Text(role.description.isEmpty ? 'Sin descripción' : role.description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                                      onChanged: (value) => setState(() => _roles[index] = role.copyWith(assigned: value ?? false)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final buttons = <Widget>[
                                    OutlinedButton.icon(onPressed: _saving ? null : () => context.go('/usuarios'), icon: const Icon(Icons.list_rounded), label: const Text('Finalizar')),
                                    OutlinedButton.icon(onPressed: _saving ? null : _randomPassword, icon: const Icon(Icons.password_rounded), label: const Text('Contraseña aleatoria')),
                                    AppButton(label: 'Guardar roles', icon: Icons.save_rounded, loading: _saving, onPressed: _save),
                                  ];
                                  if (constraints.maxWidth < 660) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: 9), buttons[i]]],
                                    );
                                  }
                                  return Row(children: [for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: buttons[i])]]);
                                },
                              ),
                            ],
                          ),
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

class _RoleOption {
  const _RoleOption({required this.roleId, required this.name, required this.description, required this.assigned});
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

  _RoleOption copyWith({bool? assigned}) => _RoleOption(roleId: roleId, name: name, description: description, assigned: assigned ?? this.assigned);
}
