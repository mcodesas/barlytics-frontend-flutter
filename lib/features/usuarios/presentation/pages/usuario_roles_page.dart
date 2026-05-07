import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';

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
    if (_loading) return const Scaffold(body: AppLoader());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar roles'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/usuarios')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Paso 2: selecciona los roles del usuario', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Marca las opciones que debe tener el usuario. El menú se mostrará de acuerdo con estos roles.'),
                    const SizedBox(height: 16),
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _roles.length,
                        itemBuilder: (_, index) {
                          final role = _roles[index];
                          return CheckboxListTile(
                            value: role.assigned,
                            title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(role.description),
                            onChanged: (value) => setState(() => _roles[index] = role.copyWith(assigned: value ?? false)),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => context.go('/usuarios'), icon: const Icon(Icons.list_rounded), label: const Text('Finalizar'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _randomPassword, icon: const Icon(Icons.password_rounded), label: const Text('Contraseña aleatoria'))),
                        const SizedBox(width: 12),
                        Expanded(child: AppButton(label: 'Guardar roles', icon: Icons.save_rounded, loading: _saving, onPressed: _save)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
