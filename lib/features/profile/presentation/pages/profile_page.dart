import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/lookup_dropdown.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _countryId = TextEditingController();
  final _regionId = TextEditingController();
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
  String? _tipoUsuarioNombre;
  String? _tipoUsuarioDescripcion;
  String? _empresaNombreComercial;
  String? _empresaRazonSocial;
  String? _empresaIdentificacion;
  List<String> _roles = const <String>[];

  List<CrudLookupOption> _countries = const <CrudLookupOption>[];
  List<CrudLookupOption> _regions = const <CrudLookupOption>[];
  List<CrudLookupOption> _cities = const <CrudLookupOption>[];

  static const _countryField = CrudField(
    name: 'paisId',
    label: 'País',
    type: CrudFieldType.number,
    lookup: CrudLookupConfig(endpoint: ApiPaths.paises, idField: 'paisId', displayFields: ['paisNombre', 'paisCodigo']),
  );
  static const _regionField = CrudField(
    name: 'regiId',
    label: 'Región / departamento',
    type: CrudFieldType.number,
    lookup: CrudLookupConfig(endpoint: ApiPaths.regiones, idField: 'regiId', displayFields: ['regiNombre', 'regiCodigo']),
  );
  static const _cityField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    lookup: CrudLookupConfig(endpoint: ApiPaths.ciudades, idField: 'ciudId', displayFields: ['ciudNombre', 'ciudCodigoDane']),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadLookups(), _loadProfile()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          ApiPaths.profile,
          (json) => Map<String, dynamic>.from(json as Map),
        );
    final data = response.data ?? <String, dynamic>{};
    _countryId.text = data['paisId']?.toString() ?? '';
    _regionId.text = data['regionId']?.toString() ?? '';
    _cityId.text = data['ciudadId']?.toString() ?? '';
    _firstName.text = data['primerNombre']?.toString() ?? '';
    _secondName.text = data['segundoNombre']?.toString() ?? '';
    _firstLastName.text = data['primerApellido']?.toString() ?? '';
    _secondLastName.text = data['segundoApellido']?.toString() ?? '';
    _email.text = data['email']?.toString() ?? '';
    _address.text = data['direccion']?.toString() ?? '';
    _phone.text = data['telefonoPrincipal']?.toString() ?? '';
    _phone2.text = data['telefonoSecundario']?.toString() ?? '';
    _tipoUsuarioNombre = data['tipoUsuarioNombre']?.toString();
    _tipoUsuarioDescripcion = data['tipoUsuarioDescripcion']?.toString();
    _empresaNombreComercial = data['empresaNombreComercial']?.toString();
    _empresaRazonSocial = data['empresaRazonSocial']?.toString();
    _empresaIdentificacion = data['empresaIdentificacion']?.toString();
    final roles = data['roles'];
    _roles = roles is List ? roles.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList() : const <String>[];
  }

  Future<void> _loadLookups() async {
    final apiClient = ref.read(apiClientProvider);
    final results = await Future.wait([
      _loadLookup(ApiPaths.paises, 'paisId', ['paisNombre', 'paisCodigo']),
      _loadLookup(ApiPaths.regiones, 'regiId', ['regiNombre', 'regiCodigo']),
      _loadLookup(ApiPaths.ciudades, 'ciudId', ['ciudNombre', 'ciudCodigoDane']),
    ]);
    _countries = results[0];
    _regions = results[1];
    _cities = results[2];
  }

  Future<List<CrudLookupOption>> _loadLookup(String endpoint, String idField, List<String> displayFields) async {
    final response = await ref.read(apiClientProvider).get<List<CrudLookupOption>>(
      endpoint,
      (json) {
        final list = (json as List? ?? const <Object?>[]);
        return list.map((item) {
          if (item is! Map) return null;
          final raw = Map<String, dynamic>.from(item);
          final id = raw[idField];
          final label = displayFields.map((field) => raw[field]?.toString()).where((value) => value != null && value.trim().isNotEmpty).join(' - ');
          return CrudLookupOption(id: id, label: label.isEmpty ? (id?.toString() ?? 'Sin nombre') : label, raw: raw);
        }).whereType<CrudLookupOption>().toList();
      },
    );
    return response.data ?? const <CrudLookupOption>[];
  }

  List<CrudLookupOption> get _filteredRegions {
    final country = _countryId.text.trim();
    if (country.isEmpty) return _regions;
    return _regions.where((option) => option.raw['paisId']?.toString() == country).toList();
  }

  List<CrudLookupOption> get _filteredCities {
    final region = _regionId.text.trim();
    if (region.isEmpty) return _cities;
    return _cities.where((option) => option.raw['regiId']?.toString() == region).toList();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put(ApiPaths.profile, {
        'paisId': int.tryParse(_countryId.text),
        'regiId': int.tryParse(_regionId.text),
        'ciudId': int.tryParse(_cityId.text),
        'primerNombre': _firstName.text.trim(),
        'segundoNombre': _secondName.text.trim().isEmpty ? null : _secondName.text.trim(),
        'primerApellido': _firstLastName.text.trim(),
        'segundoApellido': _secondLastName.text.trim(),
        'email': _email.text.trim(),
        'direccion': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'telefonoPrincipal': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'telefonoSecundario': _phone2.text.trim().isEmpty ? null : _phone2.text.trim(),
      }, (json) => json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente')));
      await _loadProfile();
      if (mounted) setState(() {});
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
    for (final c in [_currentPassword, _newPassword, _countryId, _regionId, _cityId, _firstName, _secondName, _firstLastName, _secondLastName, _email, _address, _phone, _phone2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoader();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              _header(context),
              const SizedBox(height: 16),
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
                          _field(_email, 'Correo', email: true),
                          _lookup(_countryId, _countryField, _countries, onChanged: () {
                            _regionId.clear();
                            _cityId.clear();
                            setState(() {});
                          }),
                          _lookup(_regionId, _regionField, _filteredRegions, onChanged: () {
                            _cityId.clear();
                            setState(() {});
                          }),
                          _lookup(_cityId, _cityField, _filteredCities),
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
              _securityInfo(),
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
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mi perfil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('Actualiza tus datos personales y revisa tu acceso al sistema', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Atrás'),
          ),
        ],
      ),
    );
  }

  String get _companyLabel {
    final parts = [_empresaNombreComercial, _empresaRazonSocial, _empresaIdentificacion]
        .where((item) => item != null && item!.trim().isNotEmpty)
        .map((item) => item!.trim())
        .toList();
    return parts.isEmpty ? 'No definida' : parts.join(' - ');
  }

  Widget _securityInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Empresa, tipo de usuario y roles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Empresa', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _companyLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  const Text('Tipo de usuario', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    [_tipoUsuarioNombre, _tipoUsuarioDescripcion].where((item) => item != null && item!.trim().isNotEmpty).join(' - ').isEmpty
                        ? 'No definido'
                        : [_tipoUsuarioNombre, _tipoUsuarioDescripcion].where((item) => item != null && item!.trim().isNotEmpty).join(' - '),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  const Text('Roles asignados', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  _roles.isEmpty
                      ? const Text('No tienes roles asignados', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _roles.map((role) => Chip(label: Text(role), avatar: const Icon(Icons.verified_user_rounded, size: 18))).toList(),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estos datos son solo de consulta. Los roles y el tipo de usuario los administra un usuario con permisos de seguridad.',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lookup(TextEditingController controller, CrudField field, List<CrudLookupOption> options, {VoidCallback? onChanged}) {
    return SizedBox(
      width: 410,
      child: _LookupWithCallback(
        controller: controller,
        field: field,
        options: options,
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool required = true, bool obscure = false, bool email = false}) => SizedBox(
        width: 410,
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) return 'Campo obligatorio';
            if (email && value != null && value.trim().isNotEmpty) {
              final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
              if (!isValid) return 'Correo inválido';
            }
            return null;
          },
        ),
      );
}

class _LookupWithCallback extends StatefulWidget {
  const _LookupWithCallback({required this.controller, required this.field, required this.options, this.onChanged});

  final TextEditingController controller;
  final CrudField field;
  final List<CrudLookupOption> options;
  final VoidCallback? onChanged;

  @override
  State<_LookupWithCallback> createState() => _LookupWithCallbackState();
}

class _LookupWithCallbackState extends State<_LookupWithCallback> {
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    _lastValue = widget.controller.text;
    widget.controller.addListener(_notifyWhenChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_notifyWhenChanged);
    super.dispose();
  }

  void _notifyWhenChanged() {
    final current = widget.controller.text;
    if (current == _lastValue) return;
    _lastValue = current;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LookupDropdown(controller: widget.controller, field: widget.field, options: widget.options);
  }
}
