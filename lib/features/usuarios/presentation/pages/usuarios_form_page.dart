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

  final Map<String, List<CrudLookupOption>> _lookupOptions = <String, List<CrudLookupOption>>{};
  final Set<String> _loadingLookups = <String>{};
  final Map<String, String> _lookupErrors = <String, String>{};

  int _currentStep = 0;
  int _estado = 1;
  int _bloqueado = 0;
  DateTime? _fechaNacimiento;
  bool _loadingInitial = false;
  bool _loadingRoles = false;
  bool _saving = false;
  String? _error;
  List<_RoleOption> _roles = const <_RoleOption>[];

  bool get _isEditing => widget.id != null;
  bool get _isReadOnly => widget.readOnly;

  List<CrudLookupOption> get _ciudadOptions => _lookupOptions[_ciudadField.name] ?? const <CrudLookupOption>[];

  List<CrudLookupOption> get _empresaOptions {
    final ciudadId = _ciudadController.text.trim();
    if (ciudadId.isEmpty) return const <CrudLookupOption>[];
    return (_lookupOptions[_empresaField.name] ?? const <CrudLookupOption>[])
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

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadRoles();
    if (_isEditing) {
      _loadUsuario();
    }
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
      _empresaController.text = usuario.emprId?.toString() ?? '';
      _sucursalController.text = usuario.sucuId?.toString() ?? '';
      _estado = usuario.usuaEstado ?? 1;
      _bloqueado = usuario.usuaBloqueado ?? 0;
      _direccionController.text = usuario.usuaDireccion ?? '';
      _telefonoPrincipalController.text = usuario.usuaTelefonoPrincipal ?? '';
      _telefonoSecundarioController.text = usuario.usuaTelefonoSecundario ?? '';
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
      final response = await api.get<List<CrudLookupOption>>(
        lookup.endpoint,
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
      'Sucursal': _sucursalController.text.trim(),
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
    if (_sucursalController.text.trim().isEmpty) {
      _showMessage('Selecciona la sucursal después de seleccionar la empresa.');
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
              ? 'Usuario y roles actualizados correctamente. Si el correo cambió, se envió un nuevo correo para registrar la contraseña.'
              : 'Usuario creado correctamente. Se envió el correo para activar la cuenta y registrar la contraseña.'),
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
      'emprId': int.tryParse(_empresaController.text.trim()),
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
    if (_loadingInitial) return const Scaffold(body: AppLoader());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isReadOnly ? 'Ver usuario' : (_isEditing ? 'Modificar usuario' : 'Crear usuario')),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/usuarios')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WizardHeader(
                      currentStep: _currentStep,
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
        ),
      ),
    );
  }

  Widget _buildUserStep() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final fieldWidth = isCompact ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
          final thirdWidth = isCompact ? constraints.maxWidth : (constraints.maxWidth - 32) / 3;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Paso 1: datos de la tabla usuarios', _isReadOnly ? 'Consulta la información principal del usuario. Esta vista es solo lectura.' : 'Captura los datos en memoria. Nada se guarda hasta confirmar al final.'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(width: fieldWidth, child: _textField(_primerNombreController, 'Primer nombre', Icons.person_outline_rounded, required: true)),
                    SizedBox(width: fieldWidth, child: _textField(_segundoNombreController, 'Segundo nombre', Icons.person_outline_rounded)),
                    SizedBox(width: fieldWidth, child: _textField(_primerApellidoController, 'Primer apellido', Icons.badge_outlined, required: true)),
                    SizedBox(width: fieldWidth, child: _textField(_segundoApellidoController, 'Segundo apellido', Icons.badge_outlined, required: true)),
                    SizedBox(width: constraints.maxWidth, child: _emailField()),
                    SizedBox(width: thirdWidth, child: _lookupField(_ciudadField, _ciudadController, _ciudadOptions, onSelected: (_) => _onCiudadChanged())),
                    SizedBox(width: thirdWidth, child: _lookupField(_empresaField, _empresaController, _empresaOptions, enabled: _ciudadController.text.trim().isNotEmpty, helperText: 'Primero selecciona ciudad', onSelected: (_) => _onEmpresaChanged())),
                    SizedBox(width: thirdWidth, child: _lookupField(_sucursalField, _sucursalController, _sucursalOptions, enabled: _empresaController.text.trim().isNotEmpty, helperText: 'Primero selecciona empresa')),
                    SizedBox(width: fieldWidth, child: _statusField()),
                    SizedBox(width: fieldWidth, child: _blockedField()),
                    SizedBox(width: fieldWidth, child: _dateField()),
                    SizedBox(width: fieldWidth, child: _textField(_direccionController, 'Dirección', Icons.location_on_outlined)),
                    SizedBox(width: fieldWidth, child: _textField(_telefonoPrincipalController, 'Teléfono principal', Icons.phone_outlined, keyboardType: TextInputType.phone)),
                    SizedBox(width: fieldWidth, child: _textField(_telefonoSecundarioController, 'Teléfono secundario', Icons.phone_android_outlined, keyboardType: TextInputType.phone)),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => context.go('/usuarios'),
                        icon: Icon(_isReadOnly ? Icons.arrow_back_rounded : Icons.close_rounded),
                        label: Text(_isReadOnly ? 'Volver al listado' : 'Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: _isReadOnly ? 'Ver roles' : 'Continuar a roles',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _isReadOnly ? () => setState(() => _currentStep = 1) : _goToRoles,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRolesStep() {
    if (_loadingRoles) return const AppLoader();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Paso 2: asignación de roles', _isReadOnly ? 'Consulta los roles asignados actualmente. Esta vista es solo lectura.' : 'Selecciona los roles funcionales. Todavía no se guarda nada en base de datos.'),
        const SizedBox(height: 12),
        Expanded(
          child: _roles.isEmpty
              ? const Center(child: Text('No hay roles parametrizados para asignar.'))
              : ListView.separated(
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final role = _roles[index];
                    return CheckboxListTile(
                      value: role.assigned,
                      title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(role.description.isEmpty ? 'Sin descripción' : role.description),
                      secondary: const Icon(Icons.verified_user_outlined),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      tileColor: AppColors.surfaceAlt,
                      onChanged: _isReadOnly ? null : (value) => setState(() => _roles[index] = role.copyWith(assigned: value ?? false)),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => setState(() => _currentStep = 0), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Volver a datos'))),
            const SizedBox(width: 12),
            Expanded(child: AppButton(label: _isReadOnly ? 'Ver resumen' : 'Continuar a confirmación', icon: Icons.fact_check_outlined, onPressed: _isReadOnly ? () => setState(() => _currentStep = 2) : _goToConfirmation)),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    final selectedRoles = _roles.where((role) => role.assigned).toList(growable: false);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Paso 3: resumen', _isReadOnly ? 'Vista de resumen del usuario. Esta pantalla no realiza cambios.' : (_isEditing ? 'Revisa los cambios. Solo al confirmar se actualizan usuario y roles. Si cambiaste el correo, se enviará un nuevo correo para registrar contraseña.' : 'Revisa la información. Solo al confirmar se crea el usuario, se asignan roles y se envía el correo de activación.')), 
          const SizedBox(height: 16),
          _summaryCard('Identificación', [
            _SummaryItem('Nombre', '${_primerNombreController.text.trim()} ${_segundoNombreController.text.trim()} ${_primerApellidoController.text.trim()} ${_segundoApellidoController.text.trim()}'.replaceAll(RegExp(r'\s+'), ' ').trim()),
            _SummaryItem('Correo', _emailController.text.trim()),
            _SummaryItem('Fecha nacimiento', _fechaNacimientoController.text.trim().isEmpty ? 'No registrada' : _fechaNacimientoController.text.trim()),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Ubicación operativa', [
            _SummaryItem('Ciudad', _labelOf(_ciudadOptions, _ciudadController.text)),
            _SummaryItem('Empresa', _labelOf(_empresaOptions, _empresaController.text)),
            _SummaryItem('Sucursal', _labelOf(_sucursalOptions, _sucursalController.text)),
          ]),
          const SizedBox(height: 12),
          _summaryCard('Estado y contacto', [
            _SummaryItem('Estado', _estado == 1 ? 'Activo' : 'Inactivo'),
            _SummaryItem('Bloqueo', _bloqueado == 1 ? 'Bloqueado' : 'Activo'),
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
              decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'Al confirmar, el sistema enviará un correo para que el usuario active la cuenta registrando su contraseña.',
                style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w900),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => setState(() => _currentStep = 1), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Volver a roles'))),
              const SizedBox(width: 12),
              Expanded(
                child: _isReadOnly
                    ? AppButton(label: 'Volver al listado', icon: Icons.list_alt_rounded, onPressed: () => context.go('/usuarios'))
                    : AppButton(label: _isEditing ? 'Confirmar modificación' : 'Confirmar y crear usuario', icon: Icons.save_rounded, loading: _saving, onPressed: _saveWizard),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, List<_SummaryItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 170, child: Text(item.label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800))),
                    Expanded(child: Text(item.value, style: const TextStyle(fontWeight: FontWeight.w900))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: _isReadOnly,
      enabled: !_isReadOnly,
      keyboardType: keyboardType,
      validator: required ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      readOnly: _isReadOnly,
      enabled: !_isReadOnly,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Campo obligatorio';
        if (!text.contains('@') || !text.contains('.')) return 'Correo inválido';
        return null;
      },
      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
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
    );
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
        helperText: 'Selecciona la fecha desde el calendario',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_fechaNacimiento != null)
              IconButton(
                tooltip: 'Limpiar fecha',
                onPressed: _isReadOnly ? null : () => setState(() => _setFechaNacimiento(null)),
                icon: const Icon(Icons.close_rounded),
              ),
            const Icon(Icons.calendar_month_rounded),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  void _onCiudadChanged() {
    setState(() {
      _empresaController.clear();
      _sucursalController.clear();
    });
  }

  void _onEmpresaChanged() {
    setState(() => _sucursalController.clear());
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
  const _WizardHeader({required this.currentStep, required this.onStepSelected});

  final int currentStep;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: AppColors.softTechGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(child: _step(context, 0, 'Datos del usuario', Icons.person_add_alt_1_rounded)),
          Expanded(child: _step(context, 1, 'Asignación de roles', Icons.admin_panel_settings_outlined)),
          Expanded(child: _step(context, 2, 'Confirmación', Icons.fact_check_outlined)),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, int index, String label, IconData icon) {
    final selected = currentStep == index;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onStepSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.bluePurpleGradient : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Paso ${index + 1}: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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

class _SummaryItem {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;
}
