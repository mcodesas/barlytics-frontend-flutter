import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/lookup_dropdown.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuariosFormPage extends ConsumerStatefulWidget {
  const UsuariosFormPage({super.key, this.id, this.readOnly = false});
  final String? id;
  final bool readOnly;

  @override
  ConsumerState<UsuariosFormPage> createState() => _UsuariosFormPageState();
}

class _UsuariosFormPageState extends ConsumerState<UsuariosFormPage> {
  static const _ciudadField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.ciudades, idField: 'ciudId', displayFields: ['ciudNombre', 'ciudCodigoDane']),
  );
  static const _empresaField = CrudField(
    name: 'emprId',
    label: 'Empresa',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.empresas, idField: 'emprId', displayFields: ['empreNombreComercial', 'emprRazonSocial']),
  );
  static const _sucursalField = CrudField(
    name: 'sucuId',
    label: 'Sucursal operativa',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.sucursales, idField: 'sucuId', displayFields: ['sucuNombre', 'sucuCodigoInterno']),
  );

  final _formKey = GlobalKey<FormState>();
  final _primerNombreController = TextEditingController();
  final _segundoNombreController = TextEditingController();
  final _primerApellidoController = TextEditingController();
  final _segundoApellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _empresaController = TextEditingController();
  final _sucursalController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoPrincipalController = TextEditingController();
  final _telefonoSecundarioController = TextEditingController();
  final _fotoController = TextEditingController();

  final Map<String, List<CrudLookupOption>> _lookupOptions = <String, List<CrudLookupOption>>{};
  final Set<String> _loadingLookups = <String>{};
  final Map<String, String> _lookupErrors = <String, String>{};
  final Set<String> _selectedSucursalIds = <String>{};

  int _currentStep = 0;
  int _estado = 1;
  int _bloqueado = 0;
  DateTime? _fechaNacimiento;
  bool _loadingInitial = false;
  bool _loadingRoles = false;
  bool _saving = false;
  String? _error;
  List<_RoleOption> _roles = const <_RoleOption>[];
  String? _managerEmpresaId;

  bool get _isEditing => widget.id != null;
  bool get _isReadOnly => widget.readOnly;
  bool get _isManager {
    final roles = ref.read(authControllerProvider).roles
        .map((role) => role.toUpperCase().replaceFirst('ROLE_', '').trim())
        .toList(growable: false);
    final isAdmin = roles.any((role) =>
        role == 'ADMIN' ||
        role == 'ADMINISTRADOR' ||
        role == 'SUPERADMIN' ||
        role == 'SUPER_ADMIN');
    return !isAdmin && roles.contains('GERENTE');
  }

  String get _currentName {
    final value = <String>[
      _primerNombreController.text.trim(),
      _segundoNombreController.text.trim(),
      _primerApellidoController.text.trim(),
      _segundoApellidoController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? 'Nuevo usuario' : value;
  }

  List<CrudLookupOption> get _ciudadOptions => _lookupOptions[_ciudadField.name] ?? const <CrudLookupOption>[];

  List<CrudLookupOption> get _empresaOptions {
    final all = _lookupOptions[_empresaField.name] ?? const <CrudLookupOption>[];
    if (_isManager) {
      return all
          .where((option) => option.id?.toString() == _managerEmpresaId)
          .toList(growable: false);
    }
    final ciudadId = _ciudadController.text.trim();
    if (ciudadId.isEmpty) return const <CrudLookupOption>[];
    return all
        .where((option) => option.raw['ciudId']?.toString() == ciudadId)
        .toList(growable: false);
  }

  List<CrudLookupOption> get _sucursalOptions {
    final empresaId = _empresaController.text.trim();
    if (empresaId.isEmpty) return const <CrudLookupOption>[];
    return (_lookupOptions[_sucursalField.name] ?? const <CrudLookupOption>[])
        .where((option) => option.raw['emprId']?.toString() == empresaId)
        .toList(growable: false);
  }

  List<CrudLookupOption> get _selectedSucursalOptions => _sucursalOptions
      .where((option) => _selectedSucursalIds.contains(option.id?.toString()))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadManagerScope();
    await Future.wait([_loadLookups(), _loadRoles()]);
    if (_isEditing) {
      await _loadUsuario();
    }
  }

  Future<void> _loadManagerScope() async {
    if (!_isManager) return;
    final raw = await ref.read(secureStorageProvider).read(StorageKeys.empresaId);
    final empresaId = int.tryParse(raw ?? '')?.toString();
    if (empresaId == null) {
      if (mounted) {
        setState(() => _error = 'No fue posible identificar la empresa asignada al gerente.');
      }
      return;
    }
    _managerEmpresaId = empresaId;
    _empresaController.text = empresaId;
  }

  @override
  void dispose() {
    _primerNombreController.dispose();
    _segundoNombreController.dispose();
    _primerApellidoController.dispose();
    _segundoApellidoController.dispose();
    _emailController.dispose();
    _ciudadController.dispose();
    _empresaController.dispose();
    _sucursalController.dispose();
    _fechaNacimientoController.dispose();
    _direccionController.dispose();
    _telefonoPrincipalController.dispose();
    _telefonoSecundarioController.dispose();
    _fotoController.dispose();
    super.dispose();
  }

  Future<void> _loadUsuario() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<UsuariosResponseModel>(
        '${ApiPaths.usuarios}/${widget.id}',
        (json) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
      );
      final usuario = response.data;
      if (usuario == null) return;
      _primerNombreController.text = usuario.usuaPrimerNombre ?? '';
      _segundoNombreController.text = usuario.usuaSegundoNombre ?? '';
      _primerApellidoController.text = usuario.usuaPrimerApellido ?? '';
      _segundoApellidoController.text = usuario.usuaSegundoApellido ?? '';
      _emailController.text = usuario.usuaEmail ?? '';
      _ciudadController.text = usuario.ciudId?.toString() ?? '';
      _empresaController.text = _isManager ? (_managerEmpresaId ?? '') : (usuario.emprId?.toString() ?? '');
      _sucursalController.text = usuario.sucuId?.toString() ?? '';
      _selectedSucursalIds
        ..clear()
        ..addAll(usuario.sucursalIds.map((id) => id.toString()));
      if (_selectedSucursalIds.isEmpty && usuario.sucuId != null) {
        _selectedSucursalIds.add(usuario.sucuId.toString());
      }
      _estado = usuario.usuaEstado ?? 1;
      _bloqueado = usuario.usuaBloqueado ?? 0;
      _direccionController.text = usuario.usuaDireccion ?? '';
      _telefonoPrincipalController.text = usuario.usuaTelefonoPrincipal ?? '';
      _telefonoSecundarioController.text = usuario.usuaTelefonoSecundario ?? '';
      _fotoController.text = usuario.usuaFoto ?? '';
      _setFechaNacimiento(_parseDate(usuario.usuaFechaNacimiento));
    } catch (e) {
      _error = 'No fue posible cargar el usuario: $e';
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadLookups() async {
    await Future.wait([
      _loadLookup(_ciudadField),
      _loadLookup(_empresaField),
      _loadLookup(_sucursalField),
    ]);
  }

  Future<void> _loadLookup(CrudField field) async {
    final lookup = field.lookup!;
    setState(() => _loadingLookups.add(field.name));
    try {
      final api = ref.read(apiClientProvider);
      final endpoint = _isManager && field.name == _sucursalField.name
          ? '${ApiPaths.sucursales}/mis-sucursales'
          : lookup.endpoint;
      final response = await api.get<List<CrudLookupOption>>(
        endpoint,
        (json) {
          final items = json is List ? json : const [];
          return items.whereType<Map>().map((item) {
            final raw = Map<String, dynamic>.from(item);
            final id = raw[lookup.idField];
            if (id == null) return null;
            final labelParts = lookup.displayFields
                .map((displayField) => raw[displayField]?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .toList();
            return CrudLookupOption(id: id, label: labelParts.isEmpty ? 'Opción disponible' : labelParts.join(' - '), raw: raw);
          }).whereType<CrudLookupOption>().toList(growable: false);
        },
      );
      _lookupOptions[field.name] = response.data ?? const <CrudLookupOption>[];
      _lookupErrors.remove(field.name);
    } catch (_) {
      _lookupErrors[field.name] = 'No fue posible cargar ${field.label.toLowerCase()}';
    } finally {
      _loadingLookups.remove(field.name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loadingRoles = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final endpoint = _isEditing ? '${ApiPaths.usuarios}/${widget.id}/roles' : ApiPaths.roles;
      final response = await api.get<List<_RoleOption>>(
        endpoint,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => _RoleOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
      _roles = response.data ?? const <_RoleOption>[];
    } catch (e) {
      _error = 'No fue posible cargar los roles: $e';
    } finally {
      if (mounted) setState(() => _loadingRoles = false);
    }
  }

  void _goToRoles() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateDependentLookups()) return;
    setState(() => _currentStep = 1);
  }

  void _goToConfirmation() {
    if (!_validateUserData()) return;
    final incompatible = _roles
        .where((role) => role.assigned && !role.compatibleWith(_selectedSucursalIds, _empresaController.text.trim()))
        .map((role) => role.name)
        .toList(growable: false);
    if (incompatible.isNotEmpty) {
      _showMessage('Estos roles no son compatibles con la empresa o las sucursales del usuario: ${incompatible.join(', ')}.');
      return;
    }
    setState(() => _currentStep = 2);
  }

  bool _validateUserData() {
    final email = _emailController.text.trim();
    final requiredValues = <String, String>{
      'Primer nombre': _primerNombreController.text.trim(),
      'Primer apellido': _primerApellidoController.text.trim(),
      'Segundo apellido': _segundoApellidoController.text.trim(),
      'Correo electrónico': email,
      'Ciudad': _ciudadController.text.trim(),
      'Empresa': _empresaController.text.trim(),
      'Sucursal principal': _sucursalController.text.trim(),
    };
    final missing = requiredValues.entries.where((entry) => entry.value.isEmpty).map((entry) => entry.key).toList();
    if (missing.isNotEmpty) {
      _showMessage('Faltan campos obligatorios: ${missing.join(', ')}');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showMessage('El correo electrónico no tiene un formato válido.');
      return false;
    }
    return _validateDependentLookups();
  }

  bool _validateDependentLookups() {
    if (_ciudadController.text.trim().isEmpty) {
      _showMessage('Selecciona primero la ciudad.');
      return false;
    }
    if (_empresaController.text.trim().isEmpty) {
      _showMessage('Selecciona la empresa después de seleccionar la ciudad.');
      return false;
    }
    if (_selectedSucursalIds.isEmpty) {
      _showMessage('Selecciona al menos una sucursal para el usuario.');
      return false;
    }
    if (_sucursalController.text.trim().isEmpty) {
      _showMessage('Selecciona la sucursal principal del usuario.');
      return false;
    }
    if (!_selectedSucursalIds.contains(_sucursalController.text.trim())) {
      _showMessage('La sucursal principal debe estar incluida entre las sucursales asignadas.');
      return false;
    }
    return true;
  }

  Future<void> _saveWizard() async {
    if (!_validateUserData()) {
      setState(() => _currentStep = 0);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'usuario': _buildUserPayload(),
        'roleIds': _roles.where((r) => r.assigned).map((r) => r.roleId).toList(growable: false),
        'sucursalIds': _selectedSucursalIds.map(int.parse).toList(growable: false)..sort(),
      };

      if (_isEditing) {
        await api.put<UsuariosResponseModel>(
          '${ApiPaths.usuarios}/${widget.id}/wizard',
          body,
          (json) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      } else {
        await api.post<UsuariosResponseModel>(
          '${ApiPaths.usuarios}/wizard',
          body,
          (json) => UsuariosResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Usuario, sucursales y roles actualizados correctamente. Si el correo cambió, se envió un nuevo correo para registrar la contraseña.'
              : 'Usuario creado con sus sucursales y roles. Se envió el correo para activar la cuenta y registrar la contraseña.'),
        ),
      );
      context.go('/usuarios');
    } catch (e) {
      _error = 'No fue posible guardar el usuario: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildUserPayload() {
    final payload = <String, dynamic>{
      'ciudId': int.tryParse(_ciudadController.text.trim()),
      'emprId': int.tryParse((_isManager ? _managerEmpresaId : _empresaController.text)?.trim() ?? ''),
      'sucuId': int.tryParse(_sucursalController.text.trim()),
      'usuaEstado': _estado,
      'usuaBloqueado': _bloqueado,
      'usuaPrimerNombre': _primerNombreController.text.trim(),
      'usuaSegundoNombre': _segundoNombreController.text.trim().isEmpty ? null : _segundoNombreController.text.trim(),
      'usuaPrimerApellido': _primerApellidoController.text.trim(),
      'usuaSegundoApellido': _segundoApellidoController.text.trim(),
      'usuaEmail': _emailController.text.trim(),
      'usuaFechaNacimiento': _fechaNacimiento == null ? null : _formatIsoDate(_fechaNacimiento!),
      'usuaDireccion': _direccionController.text.trim().isEmpty ? null : _direccionController.text.trim(),
      'usuaTelefonoPrincipal': _telefonoPrincipalController.text.trim().isEmpty ? null : _telefonoPrincipalController.text.trim(),
      'usuaTelefonoSecundario': _telefonoSecundarioController.text.trim().isEmpty ? null : _telefonoSecundarioController.text.trim(),
      // Siempre se envía la foto: conserva la actual, reemplaza con una nueva o
      // la elimina de forma explícita cuando el valor está vacío.
      'usuaFoto': _fotoController.text.trim(),
    };
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  Future<void> _pickFechaNacimiento() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Seleccionar fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (selected != null) {
      setState(() => _setFechaNacimiento(selected));
    }
  }

  void _setFechaNacimiento(DateTime? value) {
    _fechaNacimiento = value;
    _fechaNacimientoController.text = value == null ? '' : _formatIsoDate(value);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(normalized);
    if (iso != null) return DateTime.tryParse('${iso.group(1)}-${iso.group(2)}-${iso.group(3)}');
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(normalized);
    if (slash != null) return DateTime(int.parse(slash.group(3)!), int.parse(slash.group(2)!), int.parse(slash.group(1)!));
    return DateTime.tryParse(normalized);
  }

  String _formatIsoDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loadingInitial) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [Positioned.fill(child: AppPageBackground()), Positioned.fill(child: AppLoader())]),
      );
    }

    final pageTitle = _isReadOnly ? 'Detalle del usuario' : (_isEditing ? 'Modificar usuario' : 'Crear usuario');
    final pageSubtitle = _isReadOnly
        ? 'Consulta los datos, las sucursales y los roles asignados.'
        : 'Completa los datos y confirma los roles antes de guardar.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UserFormContextHeader(
                      title: pageTitle,
                      subtitle: pageSubtitle,
                      name: _currentName,
                      photo: _fotoController.text,
                      active: _estado == 1,
                      blocked: _bloqueado == 1,
                      palette: palette,
                      onBack: () => context.go('/usuarios'),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: palette.cardBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _WizardHeader(
                                currentStep: _currentStep,
                                palette: palette,
                                onStepSelected: (step) {
                                  if (_isReadOnly) {
                                    setState(() => _currentStep = step);
                                    return;
                                  }
                                  if (step == 0) {
                                    setState(() => _currentStep = 0);
                                    return;
                                  }
                                  if (step == 1) {
                                    if (_currentStep == 0) {
                                      _goToRoles();
                                    } else {
                                      setState(() => _currentStep = 1);
                                    }
                                    return;
                                  }
                                  if (step == 2 && _validateUserData()) {
                                    setState(() => _currentStep = 2);
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(18)),
                                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Expanded(
                                child: switch (_currentStep) {
                                  0 => _buildUserStep(),
                                  1 => _buildRolesStep(),
                                  _ => _buildConfirmationStep(),
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

  Widget _buildUserStep() {
    final palette = ref.watch(selectedAppPaletteProvider);

    Widget fieldsContent(double availableWidth) {
      final columns = availableWidth >= 920 ? 3 : availableWidth >= 620 ? 2 : 1;
      final gap = 12.0;
      final fieldWidth = columns == 1 ? availableWidth : (availableWidth - (gap * (columns - 1))) / columns;

      Widget grid(List<Widget> children) => Wrap(
            spacing: gap,
            runSpacing: gap,
            children: children.map((child) => SizedBox(width: fieldWidth, child: child)).toList(growable: false),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            _isReadOnly ? 'Información registrada' : 'Datos del usuario',
            _isReadOnly
                ? 'Consulta la información personal, operativa y de acceso.'
                : 'Edita la información en bloques compactos. La foto se conserva mientras no la elimines.',
          ),
          const SizedBox(height: 14),
          _formSectionCard(
            title: 'Identificación',
            subtitle: 'Nombre, apellidos y fecha de nacimiento.',
            icon: Icons.badge_outlined,
            child: grid([
              _textField(_primerNombreController, 'Primer nombre', Icons.person_outline_rounded, required: true, maxLength: 20),
              _textField(_segundoNombreController, 'Segundo nombre', Icons.person_outline_rounded, maxLength: 20),
              _textField(_primerApellidoController, 'Primer apellido', Icons.badge_outlined, required: true, maxLength: 20),
              _textField(_segundoApellidoController, 'Segundo apellido', Icons.badge_outlined, required: true, maxLength: 20),
              _dateField(),
            ]),
          ),
          const SizedBox(height: 12),
          _formSectionCard(
            title: 'Contacto',
            subtitle: 'Canales de comunicación y ubicación del usuario.',
            icon: Icons.contact_phone_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                grid([
                  _emailField(),
                  _textField(_telefonoPrincipalController, 'Teléfono principal', Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 13),
                  _textField(_telefonoSecundarioController, 'Teléfono secundario', Icons.phone_android_outlined, keyboardType: TextInputType.phone, maxLength: 13),
                ]),
                const SizedBox(height: 12),
                _textField(_direccionController, 'Dirección', Icons.location_on_outlined, maxLength: 200),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _formSectionCard(
            title: 'Asignación operativa',
            subtitle: 'Empresa, ciudad y sedes donde podrá trabajar.',
            icon: Icons.store_mall_directory_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                grid([
                  _lookupField(
                    _ciudadField,
                    _ciudadController,
                    _ciudadOptions,
                    onSelected: (_) => _onCiudadChanged(),
                  ),
                  _lookupField(
                    _empresaField,
                    _empresaController,
                    _empresaOptions,
                    enabled: !_isManager && _ciudadController.text.trim().isNotEmpty,
                    helperText: _isManager
                        ? 'Empresa asignada a tu perfil de gerente'
                        : 'Selecciona primero la ciudad',
                    onSelected: (_) => _onEmpresaChanged(),
                  ),
                ]),
                const SizedBox(height: 12),
                _branchesField(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _formSectionCard(
            title: 'Estado y acceso',
            subtitle: 'Controla la disponibilidad de la cuenta sin borrar al usuario.',
            icon: Icons.security_outlined,
            child: LayoutBuilder(
              builder: (context, sectionConstraints) {
                final stack = sectionConstraints.maxWidth < 620;
                final status = _accessStateCard(
                  title: 'Usuario activo',
                  description: _estado == 1
                      ? 'Puede utilizar las funciones asignadas.'
                      : 'Permanece registrado, pero está inactivo.',
                  icon: _estado == 1 ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                  value: _estado == 1,
                  color: _estado == 1 ? AppColors.success : AppColors.warning,
                  onChanged: _isReadOnly ? null : (value) => setState(() => _estado = value ? 1 : 0),
                );
                final access = _accessStateCard(
                  title: 'Acceso habilitado',
                  description: _bloqueado == 0
                      ? 'Puede iniciar sesión normalmente.'
                      : 'No podrá iniciar sesión hasta habilitarlo.',
                  icon: _bloqueado == 0 ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  value: _bloqueado == 0,
                  color: _bloqueado == 0 ? AppColors.info : AppColors.danger,
                  onChanged: _isReadOnly ? null : (value) => setState(() => _bloqueado = value ? 0 : 1),
                );
                if (stack) return Column(children: [status, const SizedBox(height: 10), access]);
                return Row(children: [Expanded(child: status), const SizedBox(width: 10), Expanded(child: access)]);
              },
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, buttonConstraints) {
              final back = OutlinedButton.icon(
                onPressed: _saving ? null : () => context.go('/usuarios'),
                icon: Icon(_isReadOnly ? Icons.arrow_back_rounded : Icons.close_rounded),
                label: Text(_isReadOnly ? 'Volver al listado' : 'Cancelar'),
              );
              final next = AppButton(
                label: _isReadOnly ? 'Ver roles' : 'Continuar a roles',
                icon: Icons.arrow_forward_rounded,
                compact: true,
                onPressed: _isReadOnly ? () => setState(() => _currentStep = 1) : _goToRoles,
              );
              if (buttonConstraints.maxWidth < 560) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [back, const SizedBox(height: 10), next]);
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(width: 140, child: back),
                  const SizedBox(width: 10),
                  SizedBox(width: 185, child: next),
                ],
              );
            },
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 286,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _profileEditorCard(palette, compact: false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: fieldsContent(constraints.maxWidth - 300),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _profileEditorCard(palette, compact: constraints.maxWidth < 620),
                const SizedBox(height: 14),
                fieldsContent(constraints.maxWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileEditorCard(AppPalette palette, {required bool compact}) {
    final photo = _fotoController.text.trim();
    final name = _currentName;
    final email = _emailController.text.trim();

    final preview = Container(
      width: compact ? 92 : 132,
      height: compact ? 92 : 132,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(color: palette.secondary.withOpacity(0.42), width: 2),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: ClipOval(child: _UserPhotoPreview(value: photo, name: name, size: compact ? 84 : 124, palette: palette)),
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: compact ? WrapAlignment.start : WrapAlignment.center,
      children: [
        if (!_isReadOnly)
          FilledButton.tonalIcon(
            onPressed: _saving ? null : _pickProfilePhoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(photo.isEmpty ? 'Agregar foto' : 'Cambiar foto'),
          ),
        if (!_isReadOnly && photo.isNotEmpty)
          IconButton.outlined(
            onPressed: _saving ? null : _removeProfilePhoto,
            tooltip: 'Eliminar foto',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    );

    final identity = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          email.isEmpty ? 'Correo pendiente' : email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: compact ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _FormStatusChip(
              label: _estado == 1 ? 'Activo' : 'Inactivo',
              color: _estado == 1 ? AppColors.success : AppColors.warning,
              icon: _estado == 1 ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
            ),
            _FormStatusChip(
              label: _bloqueado == 1 ? 'Bloqueado' : 'Con acceso',
              color: _bloqueado == 1 ? AppColors.danger : AppColors.info,
              icon: _bloqueado == 1 ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.64),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 12), actions],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                preview,
                const SizedBox(height: 14),
                identity,
                const SizedBox(height: 14),
                actions,
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: palette.surface.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: palette.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.isEmpty
                              ? 'Puedes cargar JPG, PNG o WEBP de máximo 2 MB.'
                              : 'La foto actual se conservará al modificar los demás datos.',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > InputConstraints.imageMaxBytes) {
        _showMessage('La foto no puede superar 2 MB.');
        return;
      }
      final extension = (file?.extension ?? 'png').toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/png',
      };
      setState(() => _fotoController.text = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (e) {
      _showMessage('No fue posible cargar la foto: $e');
    }
  }

  void _removeProfilePhoto() {
    setState(_fotoController.clear);
    _showMessage('La foto se eliminará cuando confirmes la modificación.');
  }

  Widget _buildRolesStep() {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loadingRoles) return const AppLoader();
    final selectedCount = _roles.where((role) => role.assigned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _sectionTitle(
                'Roles y permisos',
                _isReadOnly
                    ? 'Consulta los perfiles funcionales asignados actualmente.'
                    : 'Selecciona únicamente los perfiles necesarios para sus responsabilidades.',
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
                '$selectedCount seleccionados',
                style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _roles.isEmpty
              ? Center(
                  child: Text(
                    'No hay roles parametrizados para asignar.',
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 4),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: constraints.maxWidth < 560 ? constraints.maxWidth : 390,
                        mainAxisExtent: 142,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _roles.length,
                      itemBuilder: (_, index) {
                        final role = _roles[index];
                        final incompatibility = role.incompatibilityReason(
                          _selectedSucursalIds,
                          _empresaController.text.trim(),
                        );
                        final available = incompatibility == null;
                        return _RoleSelectionCard(
                          palette: palette,
                          role: role,
                          readOnly: _isReadOnly,
                          available: available,
                          unavailableMessage: incompatibility,
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
            final back = OutlinedButton.icon(
              onPressed: _saving ? null : () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver a datos'),
            );
            final next = AppButton(
              label: _isReadOnly ? 'Ver resumen' : 'Revisar información',
              icon: Icons.fact_check_outlined,
              compact: true,
              onPressed: _isReadOnly ? () => setState(() => _currentStep = 2) : _goToConfirmation,
            );
            if (constraints.maxWidth < 560) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [back, const SizedBox(height: 10), next]);
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(width: 140, child: back),
                const SizedBox(width: 10),
                SizedBox(width: 185, child: next),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    final palette = ref.watch(selectedAppPaletteProvider);
    final selectedRoles = _roles.where((role) => role.assigned).toList(growable: false);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Revisión final', _isReadOnly ? 'Vista de resumen del usuario. Esta pantalla no realiza cambios.' : (_isEditing ? 'Revisa los cambios. Solo al confirmar se actualizan usuario y roles. Si cambiaste el correo, se enviará un nuevo correo para registrar contraseña.' : 'Revisa la información. Solo al confirmar se crea el usuario, se asignan roles y se envía el correo de activación.')),
          const SizedBox(height: 16),
          _summaryCard('Identificación', [
            _SummaryItem('Nombre', '${_primerNombreController.text.trim()} ${_segundoNombreController.text.trim()} ${_primerApellidoController.text.trim()} ${_segundoApellidoController.text.trim()}'.replaceAll(RegExp(r'\s+'), ' ').trim()),
            _SummaryItem('Correo', _emailController.text.trim()),
            _SummaryItem('Fecha nacimiento', _fechaNacimientoController.text.trim().isEmpty ? 'No registrada' : _fechaNacimientoController.text.trim()),
            _SummaryItem('Foto de perfil', _fotoController.text.trim().isEmpty ? 'Sin foto' : 'Configurada'),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Ubicación operativa', [
            _SummaryItem('Ciudad', _labelOf(_ciudadOptions, _ciudadController.text)),
            _SummaryItem('Empresa', _labelOf(_empresaOptions, _empresaController.text)),
            _SummaryItem('Sucursal principal', _labelOf(_sucursalOptions, _sucursalController.text)),
            _SummaryItem('Sucursales asignadas', _selectedBranchLabels()),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Estado y contacto', [
            _SummaryItem('Estado', _estado == 1 ? 'Activo' : 'Inactivo'),
            _SummaryItem('Acceso', _bloqueado == 1 ? 'Bloqueado' : 'Habilitado'),
            _SummaryItem('Teléfono principal', _telefonoPrincipalController.text.trim().isEmpty ? 'No registrado' : _telefonoPrincipalController.text.trim()),
            _SummaryItem('Teléfono secundario', _telefonoSecundarioController.text.trim().isEmpty ? 'No registrado' : _telefonoSecundarioController.text.trim()),
            _SummaryItem('Dirección', _direccionController.text.trim().isEmpty ? 'No registrada' : _direccionController.text.trim()),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Roles asignados', selectedRoles.isEmpty ? [_SummaryItem('Roles', 'Sin roles seleccionados')] : selectedRoles.map((role) => _SummaryItem(role.name, role.description.isEmpty ? 'Sin descripción' : role.description)).toList()),
          if (!_isReadOnly && !_isEditing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.secondary.withOpacity(0.18))),
              child: Text(
                'Al confirmar, el sistema enviará un correo para que el usuario active la cuenta registrando su contraseña.',
                style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
              ),
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final back = OutlinedButton.icon(onPressed: _saving ? null : () => setState(() => _currentStep = 1), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Volver a roles'));
              final confirm = _isReadOnly
                  ? AppButton(label: 'Volver al listado', icon: Icons.list_alt_rounded, compact: true, onPressed: () => context.go('/usuarios'))
                  : AppButton(
                      label: _isEditing ? 'Guardar usuario' : 'Crear usuario',
                      icon: Icons.save_rounded,
                      compact: true,
                      loading: _saving,
                      onPressed: _saveWizard,
                    );
              if (constraints.maxWidth < 520) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [back, const SizedBox(height: 10), confirm]);
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(width: 140, child: back),
                  const SizedBox(width: 10),
                  SizedBox(width: 190, child: confirm),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _formSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.35 : 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: palette.secondary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _accessStateCard({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required Color color,
    required ValueChanged<bool>? onChanged,
  }) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.08) : palette.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: value ? color.withOpacity(0.28) : palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(value: value, activeColor: color, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, List<_SummaryItem> items) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.62),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary)),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              const spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.surface.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(item.value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: palette.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    final formatters = keyboardType == TextInputType.phone
        ? <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ]
        : null;
    return TextFormField(
      controller: controller,
      readOnly: _isReadOnly,
      enabled: !_isReadOnly,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: formatters,
      onChanged: (_) => setState(() {}),
      validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), counterText: maxLength == null ? null : '').compactFilter(fixedHeight: false),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      readOnly: _isReadOnly,
      enabled: !_isReadOnly,
      keyboardType: TextInputType.emailAddress,
      maxLength: 100,
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Campo obligatorio';
        if (!text.contains('@') || !text.contains('.')) return 'Correo inválido';
        return null;
      },
      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined), counterText: '').compactFilter(fixedHeight: false),
    );
  }

  Widget _lookupField(
    CrudField field,
    TextEditingController controller,
    List<CrudLookupOption> options, {
    bool enabled = true,
    String? helperText,
    ValueChanged<CrudLookupOption>? onSelected,
  }) {
    return LookupDropdown(
      controller: controller,
      field: field,
      options: options,
      loading: _loadingLookups.contains(field.name),
      errorMessage: _lookupErrors[field.name],
      enabled: enabled && !_isReadOnly,
      helperText: _isReadOnly ? 'Solo lectura' : (enabled ? null : helperText),
      onSelected: onSelected,
      compact: true,
    );
  }

  Widget _branchesField() {
    final palette = ref.watch(selectedAppPaletteProvider);
    final companySelected = _empresaController.text.trim().isNotEmpty;
    final loading = _loadingLookups.contains(_sucursalField.name);
    final selectedOptions = _selectedSucursalOptions;
    final primaryValue = selectedOptions.any((option) => option.id?.toString() == _sucursalController.text.trim())
        ? _sucursalController.text.trim()
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.store_mall_directory_outlined, color: palette.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sucursales asignadas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      _selectedSucursalIds.isEmpty
                          ? 'Selecciona las sedes donde podrá trabajar este usuario.'
                          : '${_selectedSucursalIds.length} ${_selectedSucursalIds.length == 1 ? 'sucursal seleccionada' : 'sucursales seleccionadas'}',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (!_isReadOnly)
                FilledButton.tonalIcon(
                  onPressed: companySelected && !loading ? _showBranchPicker : null,
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(_selectedSucursalIds.isEmpty ? 'Seleccionar' : 'Cambiar'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!companySelected)
            _branchNotice('Selecciona primero la empresa para cargar sus sucursales.', Icons.info_outline_rounded, palette)
          else if (loading)
            const LinearProgressIndicator(minHeight: 3)
          else if (_sucursalOptions.isEmpty)
            _branchNotice('La empresa seleccionada no tiene sucursales disponibles.', Icons.store_mall_directory_outlined, palette)
          else if (_selectedSucursalIds.isEmpty)
            _branchNotice('Todavía no hay sucursales asignadas.', Icons.add_business_outlined, palette)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedOptions.map((option) {
                final id = option.id?.toString() ?? '';
                final isPrimary = id == _sucursalController.text.trim();
                return InputChip(
                  avatar: Icon(isPrimary ? Icons.star_rounded : Icons.storefront_outlined, size: 18, color: isPrimary ? palette.warning : palette.secondary),
                  label: Text(option.label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
                  onDeleted: _isReadOnly ? null : () => _removeBranch(id),
                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                  side: BorderSide(color: isPrimary ? palette.warning.withOpacity(0.48) : palette.cardBorder),
                  backgroundColor: isPrimary ? palette.warning.withOpacity(0.10) : palette.surface.withOpacity(0.70),
                  deleteButtonTooltipMessage: 'Quitar sucursal',
                );
              }).toList(growable: false),
            ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: primaryValue,
            decoration: const InputDecoration(
              labelText: 'Sucursal principal',
              prefixIcon: Icon(Icons.star_outline_rounded),
              helperText: 'Se usa como sede inicial al ingresar al sistema.',
            ),
            items: selectedOptions
                .map((option) => DropdownMenuItem<String>(value: option.id?.toString(), child: Text(option.label, overflow: TextOverflow.ellipsis)))
                .toList(growable: false),
            onChanged: _isReadOnly || selectedOptions.isEmpty
                ? null
                : (value) => setState(() => _sucursalController.text = value ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _branchNotice(String text, IconData icon, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: palette.surface.withOpacity(0.55), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 19, color: palette.textSecondary),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _showBranchPicker() async {
    if (_empresaController.text.trim().isEmpty) {
      _showMessage('Selecciona primero la empresa.');
      return;
    }
    final palette = ref.read(selectedAppPaletteProvider);
    final options = [..._sucursalOptions]..sort((a, b) => a.label.compareTo(b.label));
    if (options.isEmpty) {
      _showMessage('La empresa no tiene sucursales disponibles.');
      return;
    }

    final initial = Set<String>.from(_selectedSucursalIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var selected = Set<String>.from(initial);
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final visible = options
                .where((option) => option.label.toLowerCase().contains(query.trim().toLowerCase()))
                .toList(growable: false);
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 28, offset: const Offset(0, -8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(color: palette.textSecondary.withOpacity(0.28), borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Asignar sucursales', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                                Text('${selected.length} seleccionadas', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded), tooltip: 'Cerrar'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        maxLength: 120,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar sucursal',
                          prefixIcon: Icon(Icons.search_rounded),
                        ).compactFilter(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => setSheetState(() => selected = options.map((option) => option.id.toString()).toSet()),
                            icon: const Icon(Icons.done_all_rounded),
                            label: const Text('Seleccionar todas'),
                          ),
                          const Spacer(),
                          TextButton(onPressed: () => setSheetState(selected.clear), child: const Text('Limpiar')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: visible.isEmpty
                            ? Center(child: Text('No se encontraron sucursales.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)))
                            : ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 7),
                                itemBuilder: (_, index) {
                                  final option = visible[index];
                                  final id = option.id.toString();
                                  final checked = selected.contains(id);
                                  return CheckboxListTile(
                                    value: checked,
                                    onChanged: (value) => setSheetState(() {
                                      if (value == true) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    }),
                                    title: Text(option.label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                                    subtitle: option.raw['sucuDireccion'] == null
                                        ? null
                                        : Text(option.raw['sucuDireccion'].toString(), style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                                    secondary: Icon(Icons.storefront_outlined, color: checked ? palette.secondary : palette.textSecondary),
                                    activeColor: palette.actionColor,
                                    tileColor: palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.62),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: checked ? palette.secondary.withOpacity(0.45) : palette.cardBorder)),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancelar'))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: selected.isEmpty ? null : () => Navigator.pop(sheetContext, Set<String>.from(selected)),
                              icon: const Icon(Icons.check_rounded),
                              label: Text('Aplicar (${selected.length})'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _selectedSucursalIds
        ..clear()
        ..addAll(result);
      if (!_selectedSucursalIds.contains(_sucursalController.text.trim())) {
        _sucursalController.text = _selectedSucursalIds.first;
      }
    });
  }

  void _removeBranch(String id) {
    setState(() {
      _selectedSucursalIds.remove(id);
      if (_sucursalController.text.trim() == id) {
        _sucursalController.text = _selectedSucursalIds.isEmpty ? '' : _selectedSucursalIds.first;
      }
    });
  }

  String _selectedBranchLabels() {
    if (_selectedSucursalIds.isEmpty) return 'Sin sucursales seleccionadas';
    final labels = _selectedSucursalOptions.map((option) => option.label).toList(growable: false);
    if (labels.isNotEmpty) return labels.join(', ');
    return _selectedSucursalIds.map((id) => 'ID $id').join(', ');
  }

  Widget _statusField() {
    return DropdownButtonFormField<int>(
      value: _estado,
      decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.toggle_on_outlined)),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Activo')),
        DropdownMenuItem(value: 0, child: Text('Inactivo')),
      ],
      onChanged: _isReadOnly ? null : (value) => setState(() => _estado = value ?? 1),
    );
  }

  Widget _blockedField() {
    return DropdownButtonFormField<int>(
      value: _bloqueado,
      decoration: const InputDecoration(labelText: 'Bloqueo', prefixIcon: Icon(Icons.lock_outline_rounded)),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Activo')),
        DropdownMenuItem(value: 1, child: Text('Bloqueado')),
      ],
      onChanged: _isReadOnly ? null : (value) => setState(() => _bloqueado = value ?? 0),
    );
  }

  Widget _dateField() {
    return TextFormField(
      controller: _fechaNacimientoController,
      readOnly: true,
      enabled: !_isReadOnly,
      onTap: _isReadOnly ? null : _pickFechaNacimiento,
      decoration: InputDecoration(
        labelText: 'Fecha de nacimiento',
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: _fechaNacimiento == null
            ? const Icon(Icons.calendar_month_rounded)
            : IconButton(
                tooltip: 'Limpiar fecha',
                onPressed: _isReadOnly ? null : () => setState(() => _setFechaNacimiento(null)),
                icon: const Icon(Icons.close_rounded),
              ),
      ).compactFilter(fixedHeight: false),
    );
  }

  void _onCiudadChanged() {
    if (_isManager) {
      // La ciudad pertenece al usuario que se está creando; no debe cambiar la
      // empresa ni las sucursales autorizadas del gerente.
      setState(() {});
      return;
    }
    setState(() {
      _empresaController.clear();
      _sucursalController.clear();
      _selectedSucursalIds.clear();
    });
  }

  void _onEmpresaChanged() {
    if (_isManager) return;
    setState(() {
      _sucursalController.clear();
      _selectedSucursalIds.clear();
    });
  }

  String _labelOf(List<CrudLookupOption> options, String id) {
    for (final option in options) {
      if (option.id?.toString() == id.trim()) return option.label;
    }
    return id.trim().isEmpty ? 'No seleccionado' : 'ID $id';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.currentStep, required this.onStepSelected, required this.palette});

  final int currentStep;
  final ValueChanged<int> onStepSelected;
  final AppPalette palette;

  static const _items = <({String label, IconData icon})>[
    (label: 'Información', icon: Icons.person_outline_rounded),
    (label: 'Roles', icon: Icons.admin_panel_settings_outlined),
    (label: 'Confirmar', icon: Icons.fact_check_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabels = constraints.maxWidth >= 470;
          return Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = currentStep == index;
              final completed = currentStep > index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == _items.length - 1 ? 0 : 5),
                  child: Material(
                    color: selected ? palette.actionColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onStepSelected(index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              completed && !selected ? Icons.check_circle_rounded : item.icon,
                              size: 19,
                              color: selected
                                  ? palette.onAction
                                  : completed
                                      ? palette.secondary
                                      : palette.textSecondary,
                            ),
                            if (showLabels) ...[
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? palette.onAction : palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _UserFormContextHeader extends StatelessWidget {
  const _UserFormContextHeader({
    required this.title,
    required this.subtitle,
    required this.name,
    required this.photo,
    required this.active,
    required this.blocked,
    required this.palette,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final String name;
  final String photo;
  final bool active;
  final bool blocked;
  final AppPalette palette;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final identity = Row(
            children: [
              IconButton.filledTonal(
                onPressed: onBack,
                tooltip: 'Volver a usuarios',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              _FormUserAvatar(name: name, photo: photo, palette: palette),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          );

          final states = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: [
              _FormStatusChip(
                label: active ? 'Activo' : 'Inactivo',
                color: active ? AppColors.success : AppColors.warning,
                icon: active ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
              ),
              _FormStatusChip(
                label: blocked ? 'Bloqueado' : 'Con acceso',
                color: blocked ? AppColors.danger : AppColors.info,
                icon: blocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: states),
              ],
            );
          }
          return Row(children: [Expanded(child: identity), const SizedBox(width: 12), states]);
        },
      ),
    );
  }
}

class _FormUserAvatar extends StatelessWidget {
  const _FormUserAvatar({required this.name, required this.photo, required this.palette});

  final String name;
  final String photo;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _UserPhotoPreview(value: photo, name: name, size: 44, palette: palette),
      ),
    );
  }
}

class _UserPhotoPreview extends StatelessWidget {
  const _UserPhotoPreview({required this.value, required this.name, required this.size, required this.palette});

  final String value;
  final String name;
  final double size;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final imageValue = value.trim();
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
    if (imageValue.isNotEmpty) {
      return Image.network(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _UserInitialsPreview(name: name, size: size, palette: palette),
      );
    }
    return _UserInitialsPreview(name: name, size: size, palette: palette);
  }
}

class _UserInitialsPreview extends StatelessWidget {
  const _UserInitialsPreview({required this.name, required this.size, required this.palette});

  final String name;
  final double size;
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
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary])),
      child: Text(initials, style: TextStyle(color: palette.onPrimary, fontSize: size * 0.34, fontWeight: FontWeight.w900)),
    );
  }
}

class _FormStatusChip extends StatelessWidget {
  const _FormStatusChip({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  const _RoleSelectionCard({
    required this.palette,
    required this.role,
    required this.readOnly,
    required this.available,
    required this.unavailableMessage,
    required this.onChanged,
  });

  final AppPalette palette;
  final _RoleOption role;
  final bool readOnly;
  final bool available;
  final String? unavailableMessage;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = role.assigned;
    final disabled = readOnly || (!available && !selected);
    return Opacity(
      opacity: available || readOnly || selected ? 1 : 0.58,
      child: Material(
        color: selected
            ? palette.secondary.withOpacity(palette.darkBackground ? 0.13 : 0.08)
            : palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: disabled ? null : () => onChanged(!selected),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              role.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (role.custom) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.secondary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                role.sucuId == null ? 'Empresa' : 'Sucursal',
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !available
                            ? (unavailableMessage ?? 'Este rol no es compatible con la asignación operativa del usuario.')
                            : (role.description.isEmpty ? 'Sin descripción' : role.description),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: !available ? palette.warning : palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: selected,
                  activeColor: palette.actionColor,
                  onChanged: disabled ? null : (value) => onChanged(value ?? false),
                ),
              ],
            ),
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
    required this.roleTipo,
    this.emprId,
    this.sucuId,
  });

  final int roleId;
  final String name;
  final String description;
  final bool assigned;
  final String roleTipo;
  final int? emprId;
  final int? sucuId;

  bool get custom => roleTipo.toUpperCase() == 'PERSONALIZADO';

  String? incompatibilityReason(Set<String> selectedBranchIds, String selectedCompanyId) {
    if (!custom) return null;
    if (emprId != null && selectedCompanyId.isNotEmpty && emprId.toString() != selectedCompanyId) {
      return 'Este rol pertenece a otra empresa.';
    }
    if (sucuId != null && !selectedBranchIds.contains(sucuId.toString())) {
      return 'Asigna la sucursal #$sucuId para habilitar este rol.';
    }
    return null;
  }

  bool compatibleWith(Set<String> selectedBranchIds, String selectedCompanyId) =>
      incompatibilityReason(selectedBranchIds, selectedCompanyId) == null;

  factory _RoleOption.fromJson(Map<String, dynamic> json) => _RoleOption(
        roleId: int.tryParse(json['roleId']?.toString() ?? '') ?? 0,
        name: json['roleNombre']?.toString() ?? 'Rol',
        description: json['roleDescripcion']?.toString() ?? '',
        assigned: json['asignado'] == true,
        roleTipo: json['roleTipo']?.toString() ?? 'PREDEFINIDO',
        emprId: int.tryParse(json['emprId']?.toString() ?? ''),
        sucuId: int.tryParse(json['sucuId']?.toString() ?? ''),
      );

  _RoleOption copyWith({bool? assigned}) => _RoleOption(
        roleId: roleId,
        name: name,
        description: description,
        assigned: assigned ?? this.assigned,
        roleTipo: roleTipo,
        emprId: emprId,
        sucuId: sucuId,
      );
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;
}
