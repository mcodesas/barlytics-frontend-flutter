import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/lookup_dropdown.dart';
import '../../../../core/widgets/tech_background.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
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
  final _photo = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _passwordChangeEnabled = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
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
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.paises,
      idField: 'paisId',
      displayFields: ['paisNombre', 'paisCodigo'],
    ),
  );
  static const _regionField = CrudField(
    name: 'regiId',
    label: 'Región / departamento',
    type: CrudFieldType.number,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.regiones,
      idField: 'regiId',
      displayFields: ['regiNombre', 'regiCodigo'],
    ),
  );
  static const _cityField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.ciudades,
      idField: 'ciudId',
      displayFields: ['ciudNombre', 'ciudCodigoDane'],
    ),
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
    _photo.text = data['foto']?.toString() ?? data['usuaFoto']?.toString() ?? '';
    _tipoUsuarioNombre = data['tipoUsuarioNombre']?.toString();
    _tipoUsuarioDescripcion = data['tipoUsuarioDescripcion']?.toString();
    _empresaNombreComercial = data['empresaNombreComercial']?.toString();
    _empresaRazonSocial = data['empresaRazonSocial']?.toString();
    _empresaIdentificacion = data['empresaIdentificacion']?.toString();
    final roles = data['roles'];
    _roles = roles is List
        ? roles
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList()
        : const <String>[];
  }

  Future<void> _loadLookups() async {
    final results = await Future.wait([
      _loadLookup(ApiPaths.paises, 'paisId', ['paisNombre', 'paisCodigo']),
      _loadLookup(ApiPaths.regiones, 'regiId', ['regiNombre', 'regiCodigo']),
      _loadLookup(ApiPaths.ciudades, 'ciudId', ['ciudNombre', 'ciudCodigoDane']),
    ]);
    _countries = results[0];
    _regions = results[1];
    _cities = results[2];
  }

  Future<List<CrudLookupOption>> _loadLookup(
    String endpoint,
    String idField,
    List<String> displayFields,
  ) async {
    final response = await ref.read(apiClientProvider).get<List<CrudLookupOption>>(
      endpoint,
      (json) {
        final list = (json as List? ?? const <Object?>[]);
        return list
            .map((item) {
              if (item is! Map) return null;
              final raw = Map<String, dynamic>.from(item);
              final id = raw[idField];
              final label = displayFields
                  .map((field) => raw[field]?.toString())
                  .where((value) => value != null && value.trim().isNotEmpty)
                  .join(' - ');
              return CrudLookupOption(
                id: id,
                label: label.isEmpty ? (id?.toString() ?? 'Sin nombre') : label,
                raw: raw,
              );
            })
            .whereType<CrudLookupOption>()
            .toList();
      },
    );
    return response.data ?? const <CrudLookupOption>[];
  }

  List<CrudLookupOption> get _filteredRegions {
    final country = _countryId.text.trim();
    if (country.isEmpty) return _regions;
    return _regions
        .where((option) => option.raw['paisId']?.toString() == country)
        .toList();
  }

  List<CrudLookupOption> get _filteredCities {
    final region = _regionId.text.trim();
    if (region.isEmpty) return _cities;
    return _cities
        .where((option) => option.raw['regiId']?.toString() == region)
        .toList();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await ref.read(apiClientProvider).put(
        ApiPaths.profile,
        {
          'paisId': int.tryParse(_countryId.text),
          'regiId': int.tryParse(_regionId.text),
          'ciudId': int.tryParse(_cityId.text),
          'primerNombre': _firstName.text.trim(),
          'segundoNombre':
              _secondName.text.trim().isEmpty ? null : _secondName.text.trim(),
          'primerApellido': _firstLastName.text.trim(),
          'segundoApellido': _secondLastName.text.trim(),
          'email': _email.text.trim(),
          'direccion':
              _address.text.trim().isEmpty ? null : _address.text.trim(),
          'telefonoPrincipal':
              _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'telefonoSecundario':
              _phone2.text.trim().isEmpty ? null : _phone2.text.trim(),
          'foto': _photo.text.trim().isEmpty ? null : _photo.text.trim(),
        },
        (json) => json,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
      await _loadProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _togglePasswordChange(bool enabled) {
    setState(() {
      _passwordChangeEnabled = enabled;
      if (!enabled) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        _hideCurrentPassword = true;
        _hideNewPassword = true;
        _hideConfirmPassword = true;
      }
    });
  }

  Future<void> _changePassword() async {
    if (!_passwordChangeEnabled) return;
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    setState(() => _savingPassword = true);
    try {
      await ref.read(apiClientProvider).post(
        '${ApiPaths.profile}/change-password',
        {
          'currentPassword': _currentPassword.text,
          'newPassword': _newPassword.text,
        },
        (json) => json,
      );
      if (!mounted) return;
      _togglePasswordChange(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible cambiar contraseña: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _currentPassword,
      _newPassword,
      _confirmPassword,
      _countryId,
      _regionId,
      _cityId,
      _firstName,
      _secondName,
      _firstLastName,
      _secondLastName,
      _email,
      _address,
      _phone,
      _phone2,
      _photo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _fullName {
    final parts = [
      _firstName.text,
      _secondName.text,
      _firstLastName.text,
      _secondLastName.text,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    return parts.isEmpty ? 'Usuario BarLytics' : parts.join(' ');
  }

  String get _companyLabel {
    final parts = [
      _empresaNombreComercial,
      _empresaRazonSocial,
      _empresaIdentificacion,
    ]
        .where((item) => item != null && item!.trim().isNotEmpty)
        .map((item) => item!.trim())
        .toList();
    return parts.isEmpty ? 'No definida' : parts.join(' - ');
  }

  String get _userTypeLabel {
    final parts = [_tipoUsuarioNombre, _tipoUsuarioDescripcion]
        .where((item) => item != null && item!.trim().isNotEmpty)
        .map((item) => item!.trim())
        .toList();
    return parts.isEmpty ? 'No definido' : parts.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoader();
    final palette = ref.watch(selectedAppPaletteProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileOverview(palette),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 940;
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _accessPanel(palette),
                        const SizedBox(height: 16),
                        _personalInformationPanel(palette),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 330, child: _accessPanel(palette)),
                      const SizedBox(width: 16),
                      Expanded(child: _personalInformationPanel(palette)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _passwordPanel(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileOverview(AppPalette palette) {
    return TechGlassPanel(
      dark: palette.darkBackground,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 78 : 92,
                height: compact ? 78 : 92,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.secondary.withOpacity(0.45),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.secondary.withOpacity(0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _ProfileImagePreview(
                    value: _photo.text,
                    size: compact ? 72 : 86,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: compact ? 22 : 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 17,
                          color: palette.secondary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _email.text.trim().isEmpty
                                ? 'Correo no registrado'
                                : _email.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProfileTag(
                          icon: Icons.badge_outlined,
                          label: _tipoUsuarioNombre?.trim().isNotEmpty == true
                              ? _tipoUsuarioNombre!.trim()
                              : 'Usuario',
                        ),
                        _ProfileTag(
                          icon: Icons.verified_user_outlined,
                          label: _roles.isEmpty
                              ? 'Sin roles'
                              : '${_roles.length} ${_roles.length == 1 ? 'rol' : 'roles'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final backButton = OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Volver'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: backButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 20),
              backButton,
            ],
          );
        },
      ),
    );
  }

  Widget _accessPanel(AppPalette palette) {
    return TechGlassPanel(
      dark: palette.darkBackground,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading(
            palette: palette,
            icon: Icons.admin_panel_settings_outlined,
            title: 'Acceso y organización',
            subtitle: 'Información administrada por seguridad.',
          ),
          const SizedBox(height: 16),
          _ProfileInfoBlock(
            icon: Icons.business_outlined,
            label: 'Empresa',
            value: _companyLabel,
          ),
          const SizedBox(height: 10),
          _ProfileInfoBlock(
            icon: Icons.account_tree_outlined,
            label: 'Tipo de usuario',
            value: _userTypeLabel,
          ),
          const SizedBox(height: 16),
          Text(
            'Roles asignados',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (_roles.isEmpty)
            Text(
              'No tienes roles asignados',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles
                  .map(
                    (role) => Chip(
                      avatar: Icon(
                        Icons.verified_user_rounded,
                        size: 17,
                        color: palette.secondary,
                      ),
                      label: Text(role),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: palette.secondary.withOpacity(0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: palette.secondary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'La empresa, el tipo de usuario y los roles son datos de consulta.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _personalInformationPanel(AppPalette palette) {
    return TechGlassPanel(
      dark: palette.darkBackground,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeading(
              palette: palette,
              icon: Icons.person_outline_rounded,
              title: 'Información personal',
              subtitle: 'Actualiza tus datos básicos, ubicación y contacto.',
            ),
            const SizedBox(height: 18),
            _ProfileImageField(controller: _photo),
            const SizedBox(height: 20),
            _subsectionLabel(
              palette,
              icon: Icons.badge_outlined,
              text: 'Datos personales',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = _fieldWidth(constraints.maxWidth);
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _field(_firstName, 'Primer nombre', width: width),
                    _field(
                      _secondName,
                      'Segundo nombre',
                      required: false,
                      width: width,
                    ),
                    _field(_firstLastName, 'Primer apellido', width: width),
                    _field(_secondLastName, 'Segundo apellido', width: width),
                    _field(
                      _email,
                      'Correo',
                      email: true,
                      width: width,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Divider(color: palette.cardBorder),
            const SizedBox(height: 18),
            _subsectionLabel(
              palette,
              icon: Icons.location_on_outlined,
              text: 'Ubicación y contacto',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = _fieldWidth(constraints.maxWidth);
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _lookup(
                      _countryId,
                      _countryField,
                      _countries,
                      width: width,
                      onChanged: () {
                        _regionId.clear();
                        _cityId.clear();
                        setState(() {});
                      },
                    ),
                    _lookup(
                      _regionId,
                      _regionField,
                      _filteredRegions,
                      width: width,
                      onChanged: () {
                        _cityId.clear();
                        setState(() {});
                      },
                    ),
                    _lookup(
                      _cityId,
                      _cityField,
                      _filteredCities,
                      width: width,
                    ),
                    _field(
                      _address,
                      'Dirección',
                      required: false,
                      width: width,
                    ),
                    _field(
                      _phone,
                      'Teléfono principal',
                      required: false,
                      width: width,
                      keyboardType: TextInputType.phone,
                    ),
                    _field(
                      _phone2,
                      'Teléfono secundario',
                      required: false,
                      width: width,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: AppButton(
                  label: 'Guardar cambios',
                  icon: Icons.save_rounded,
                  loading: _savingProfile,
                  onPressed: _savingPassword ? null : _saveProfile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordPanel(AppPalette palette) {
    return TechGlassPanel(
      dark: palette.darkBackground,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final title = _sectionHeading(
                palette: palette,
                icon: Icons.lock_outline_rounded,
                title: 'Seguridad de la cuenta',
                subtitle: _passwordChangeEnabled
                    ? 'Completa los campos para registrar una nueva contraseña.'
                    : 'La contraseña permanece sin cambios mientras esta opción esté desactivada.',
              );
              final toggle = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _passwordChangeEnabled
                      ? palette.secondary.withOpacity(0.12)
                      : palette.background.withOpacity(
                          palette.darkBackground ? 0.34 : 0.68,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _passwordChangeEnabled
                        ? palette.secondary.withOpacity(0.30)
                        : palette.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cambiar contraseña',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _passwordChangeEnabled,
                      onChanged: _savingPassword ? null : _togglePasswordChange,
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: toggle),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 18),
                  toggle,
                ],
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: !_passwordChangeEnabled
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Form(
                      key: _passwordFormKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.background.withOpacity(
                                palette.darkBackground ? 0.34 : 0.68,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = _fieldWidth(constraints.maxWidth);
                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    _passwordField(
                                      controller: _currentPassword,
                                      label: 'Contraseña actual',
                                      width: width,
                                      obscure: _hideCurrentPassword,
                                      onToggleVisibility: () => setState(
                                        () => _hideCurrentPassword =
                                            !_hideCurrentPassword,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu contraseña actual';
                                        }
                                        return null;
                                      },
                                    ),
                                    _passwordField(
                                      controller: _newPassword,
                                      label: 'Nueva contraseña',
                                      width: width,
                                      obscure: _hideNewPassword,
                                      onToggleVisibility: () => setState(
                                        () => _hideNewPassword =
                                            !_hideNewPassword,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa la nueva contraseña';
                                        }
                                        if (value.length < 8) {
                                          return 'Debe tener mínimo 8 caracteres';
                                        }
                                        if (value == _currentPassword.text) {
                                          return 'Debe ser diferente a la actual';
                                        }
                                        return null;
                                      },
                                    ),
                                    _passwordField(
                                      controller: _confirmPassword,
                                      label: 'Confirmar contraseña',
                                      width: width,
                                      obscure: _hideConfirmPassword,
                                      onToggleVisibility: () => setState(
                                        () => _hideConfirmPassword =
                                            !_hideConfirmPassword,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Confirma la nueva contraseña';
                                        }
                                        if (value != _newPassword.text) {
                                          return 'Las contraseñas no coinciden';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Guardar el perfil no cambia tu contraseña. Esta acción se procesa de forma independiente.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 520;
                              final cancel = OutlinedButton.icon(
                                onPressed: _savingPassword
                                    ? null
                                    : () => _togglePasswordChange(false),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Cancelar'),
                              );
                              final save = ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: compact
                                      ? double.infinity
                                      : 300,
                                ),
                                child: AppButton(
                                  label: 'Actualizar contraseña',
                                  icon: Icons.lock_reset_rounded,
                                  loading: _savingPassword,
                                  onPressed:
                                      _savingProfile ? null : _changePassword,
                                ),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    save,
                                    const SizedBox(height: 10),
                                    cancel,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  cancel,
                                  const SizedBox(width: 12),
                                  Expanded(child: Align(alignment: Alignment.centerRight, child: save)),
                                ],
                              );
                            },
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

  Widget _sectionHeading({
    required AppPalette palette,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: palette.secondary.withOpacity(0.16)),
          ),
          child: Icon(icon, color: palette.secondary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subsectionLabel(
    AppPalette palette, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: palette.secondary, size: 19),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  double _fieldWidth(double maxWidth) {
    if (maxWidth < 620) return maxWidth;
    return (maxWidth - 14) / 2;
  }

  Widget _lookup(
    TextEditingController controller,
    CrudField field,
    List<CrudLookupOption> options, {
    required double width,
    VoidCallback? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: _LookupWithCallback(
        controller: controller,
        field: field,
        options: options,
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required double width,
    bool required = true,
    bool email = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            email ? Icons.mail_outline_rounded : Icons.edit_outlined,
          ),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Campo obligatorio';
          }
          if (email && value != null && value.trim().isNotEmpty) {
            final isValid = RegExp(
              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
            ).hasMatch(value.trim());
            if (!isValid) return 'Correo inválido';
          }
          return null;
        },
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required double width,
    required bool obscure,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
            onPressed: onToggleVisibility,
            icon: Icon(
              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _ProfileTag extends ConsumerWidget {
  const _ProfileTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoBlock extends ConsumerWidget {
  const _ProfileInfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.66 : 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: palette.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupWithCallback extends StatefulWidget {
  const _LookupWithCallback({
    required this.controller,
    required this.field,
    required this.options,
    this.onChanged,
  });

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
    return LookupDropdown(
      controller: widget.controller,
      field: widget.field,
      options: widget.options,
    );
  }
}

class _ProfileImageField extends ConsumerStatefulWidget {
  const _ProfileImageField({required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<_ProfileImageField> createState() =>
      _ProfileImageFieldState();
}

class _ProfileImageFieldState extends ConsumerState<_ProfileImageField> {
  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final ext = (file?.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    widget.controller.text = 'data:$mime;base64,${base64Encode(bytes)}';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final value = widget.controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.34 : 0.68,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final preview = Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.secondary.withOpacity(0.34),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _ProfileImagePreview(value: value, size: 76),
            ),
          );

          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto de perfil',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Usa una imagen clara para identificar rápidamente tu cuenta.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(value.isEmpty ? 'Cargar foto' : 'Reemplazar'),
              ),
              if (value.isNotEmpty)
                IconButton.outlined(
                  tooltip: 'Quitar foto',
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    preview,
                    const SizedBox(width: 14),
                    Expanded(child: description),
                  ],
                ),
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            children: [
              preview,
              const SizedBox(width: 14),
              Expanded(child: description),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ProfileImagePreview extends StatelessWidget {
  const _ProfileImagePreview({required this.value, required this.size});

  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageValue = value.trim();
    if (imageValue.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: const Color(0xFF0B2634),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withOpacity(0.72),
          size: size * 0.52,
        ),
      );
    }
    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          return Image.memory(
            base64Decode(imageValue.substring(commaIndex + 1)),
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      imageValue,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: const Color(0xFF0B2634),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withOpacity(0.72),
          size: size * 0.52,
        ),
      ),
    );
  }
}
