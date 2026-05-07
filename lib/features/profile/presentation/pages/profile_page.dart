import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _cityId = TextEditingController();
  final _firstName = TextEditingController();
  final _secondName = TextEditingController();
  final _firstLastName = TextEditingController();
  final _secondLastName = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.profile,
            (json) => Map<String, dynamic>.from(json as Map),
          );
      final data = response.data ?? <String, dynamic>{};
      _cityId.text = data['ciudadId']?.toString() ?? '';
      _firstName.text = data['primerNombre']?.toString() ?? '';
      _secondName.text = data['segundoNombre']?.toString() ?? '';
      _firstLastName.text = data['primerApellido']?.toString() ?? '';
      _secondLastName.text = data['segundoApellido']?.toString() ?? '';
      _email.text = data['email']?.toString() ?? '';
      _address.text = data['direccion']?.toString() ?? '';
      _phone.text = data['telefonoPrincipal']?.toString() ?? '';
      _phone2.text = data['telefonoSecundario']?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put(ApiPaths.profile, {
        'ciudId': int.tryParse(_cityId.text),
        'primerNombre': _firstName.text.trim(),
        'segundoNombre': _secondName.text.trim().isEmpty ? null : _secondName.text.trim(),
        'primerApellido': _firstLastName.text.trim(),
        'segundoApellido': _secondLastName.text.trim(),
        'email': _email.text.trim(),
        'direccion': _address.text.trim(),
        'telefonoPrincipal': _phone.text.trim(),
        'telefonoSecundario': _phone2.text.trim().isEmpty ? null : _phone2.text.trim(),
      }, (json) => json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible actualizar perfil: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPassword.text.isEmpty || _newPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa contraseña actual y nueva')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post('${ApiPaths.profile}/change-password', {
        'currentPassword': _currentPassword.text,
        'newPassword': _newPassword.text,
      }, (json) => json);
      _currentPassword.clear();
      _newPassword.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible cambiar contraseña: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_currentPassword, _newPassword, _cityId, _firstName, _secondName, _firstLastName, _secondLastName, _email, _address, _phone, _phone2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: AppLoader());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/home')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Información personal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 16),
                          Wrap(spacing: 16, runSpacing: 16, children: [
                            _field(_firstName, 'Primer nombre'),
                            _field(_secondName, 'Segundo nombre', required: false),
                            _field(_firstLastName, 'Primer apellido'),
                            _field(_secondLastName, 'Segundo apellido'),
                            _field(_email, 'Correo'),
                            _field(_cityId, 'Ciudad'),
                            _field(_address, 'Dirección', required: false),
                            _field(_phone, 'Teléfono', required: false),
                            _field(_phone2, 'Teléfono secundario', required: false),
                          ]),
                          const SizedBox(height: 20),
                          AppButton(label: 'Guardar perfil', icon: Icons.save_rounded, loading: _saving, onPressed: _saveProfile),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Cambiar contraseña', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        Wrap(spacing: 16, runSpacing: 16, children: [
                          _field(_currentPassword, 'Contraseña actual', obscure: true),
                          _field(_newPassword, 'Nueva contraseña', obscure: true),
                        ]),
                        const SizedBox(height: 20),
                        AppButton(label: 'Cambiar contraseña', icon: Icons.lock_reset_rounded, loading: _saving, onPressed: _changePassword),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool required = true, bool obscure = false}) => SizedBox(
        width: 410,
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null,
        ),
      );
}
