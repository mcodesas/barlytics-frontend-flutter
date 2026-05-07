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

/// Formulario guiado para crear y modificar empresas.
///
/// Reglas importantes:
/// - En creación no se envía nada al backend hasta que el usuario llegue al
///   resumen y presione "Finalizar y registrar".
/// - En edición sí se guarda por paso: datos de empresa, sucursales agregadas,
///   sucursales modificadas y sucursales eliminadas.
/// - Los campos relacionales se seleccionan con ayudas de búsqueda.
class EmpresasFormPage extends ConsumerStatefulWidget {
  const EmpresasFormPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<EmpresasFormPage> createState() => _EmpresasFormPageState();
}

class _EmpresasFormPageState extends ConsumerState<EmpresasFormPage> {
  static const _ciudadField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.ciudades, idField: 'ciudId', displayFields: ['ciudNombre', 'ciudCodigoDane']),
  );
  static const _zonaField = CrudField(
    name: 'zohoId',
    label: 'Zona horaria',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.zonashorarias, idField: 'zohoId', displayFields: ['zohoNombre', 'zohoAbreviatura', 'zohoOffsetOut']),
  );
  static const _paisTelefonoField = CrudField(
    name: 'paisIdtelefono',
    label: 'País teléfono',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.paises, idField: 'paisId', displayFields: ['paisNombre', 'paisCodigo']),
  );
  static const _tipoIdentificacionField = CrudField(
    name: 'tiidId',
    label: 'Tipo de identificación',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.tiposidentificacion, idField: 'tiidId', displayFields: ['tiidNombre', 'tiidDescripcion']),
  );
  static const _monedaField = CrudField(
    name: 'moneId',
    label: 'Moneda',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.monedas, idField: 'moneId', displayFields: ['moneCodigoiso', 'moneNombre', 'moneSimbolo']),
  );

  final _empresaFormKey = GlobalKey<FormState>();
  final _nombreComercial = TextEditingController();
  final _razonSocial = TextEditingController();
  final _identificacion = TextEditingController();
  final _direccion = TextEditingController();
  final _codigoPostal = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _sitioWeb = TextEditingController();
  final _logo = TextEditingController();
  final _estado = TextEditingController(text: '1');
  final _ciudad = TextEditingController();
  final _zona = TextEditingController();
  final _paisTelefono = TextEditingController();
  final _tipoIdentificacion = TextEditingController();

  final Map<String, List<CrudLookupOption>> _lookupOptions = <String, List<CrudLookupOption>>{};
  final Map<String, String> _lookupErrors = <String, String>{};
  final Set<String> _loadingLookupFields = <String>{};
  final List<_SucursalDraft> _sucursales = <_SucursalDraft>[];

  bool _loading = true;
  bool _saving = false;
  int _step = 0;

  bool get _isEdit => widget.id != null && widget.id!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      await _loadLookupOptions();
      if (_isEdit) {
        await Future.wait([
          _loadEmpresa(),
          _loadSucursales(),
        ]);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmpresa() async {
    final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
      '${ApiPaths.empresas}/${widget.id}',
      (json) => Map<String, dynamic>.from(json as Map),
    );
    final data = response.data ?? <String, dynamic>{};
    _nombreComercial.text = data['empreNombreComercial']?.toString() ?? '';
    _razonSocial.text = data['emprRazonSocial']?.toString() ?? '';
    _identificacion.text = data['emprIdentificacion']?.toString() ?? '';
    _direccion.text = data['emprDireccion']?.toString() ?? '';
    _codigoPostal.text = data['emprCodigoPostal']?.toString() ?? '';
    _telefono.text = data['emprTelefono']?.toString() ?? '';
    _correo.text = data['emprCorreoElectronico']?.toString() ?? '';
    _sitioWeb.text = data['emprSitioWeb']?.toString() ?? '';
    _logo.text = data['emprLogo']?.toString() ?? '';
    _estado.text = data['emprEstado']?.toString() ?? '1';
    _ciudad.text = data['ciudId']?.toString() ?? '';
    _zona.text = data['zohoId']?.toString() ?? '';
    _paisTelefono.text = data['paisIdtelefono']?.toString() ?? '';
    _tipoIdentificacion.text = data['tiidId']?.toString() ?? '';
  }

  Future<void> _loadSucursales() async {
    final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
      '${ApiPaths.sucursales}/empresa/${widget.id}',
      (json) => (json as List? ?? const <Object?>[]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(),
    );
    _sucursales
      ..clear()
      ..addAll((response.data ?? const <Map<String, dynamic>>[]).map(_SucursalDraft.fromJson));
  }

  Future<void> _loadLookupOptions() async {
    final fields = [_ciudadField, _zonaField, _paisTelefonoField, _tipoIdentificacionField, _monedaField];
    final apiClient = ref.read(apiClientProvider);

    for (final field in fields) {
      final lookup = field.lookup!;
      _loadingLookupFields.add(field.name);
      try {
        final response = await apiClient.get<List<CrudLookupOption>>(
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
              return CrudLookupOption(
                id: id,
                label: labelParts.isEmpty ? 'Opción disponible' : labelParts.join(' - '),
                raw: raw,
              );
            }).whereType<CrudLookupOption>().toList();
          },
        );
        _lookupOptions[field.name] = response.data ?? const <CrudLookupOption>[];
        _lookupErrors.remove(field.name);
      } catch (_) {
        _lookupErrors[field.name] = 'No fue posible cargar la ayuda de ${field.label}';
      } finally {
        _loadingLookupFields.remove(field.name);
      }
    }
  }

  Map<String, dynamic> _empresaPayload() => <String, dynamic>{
        'tiidId': int.tryParse(_tipoIdentificacion.text),
        'paisIdtelefono': int.tryParse(_paisTelefono.text),
        'ciudId': int.tryParse(_ciudad.text),
        'zohoId': int.tryParse(_zona.text),
        'empreNombreComercial': _nombreComercial.text.trim(),
        'emprRazonSocial': _razonSocial.text.trim(),
        'emprIdentificacion': _identificacion.text.trim(),
        'emprDireccion': _direccion.text.trim(),
        'emprCodigoPostal': _codigoPostal.text.trim().isEmpty ? null : _codigoPostal.text.trim(),
        'emprTelefono': _telefono.text.trim(),
        'emprCorreoElectronico': _correo.text.trim(),
        'emprSitioWeb': _sitioWeb.text.trim().isEmpty ? null : _sitioWeb.text.trim(),
        'emprLogo': _logo.text.trim().isEmpty ? null : _logo.text.trim(),
        'emprEstado': int.tryParse(_estado.text) ?? 1,
      };

  Future<void> _continueFromEmpresaStep() async {
    if (!_validateEmpresaStep()) return;

    if (_isEdit) {
      setState(() => _saving = true);
      try {
        await ref.read(apiClientProvider).put('${ApiPaths.empresas}/${widget.id}', _empresaPayload(), (json) => json);
        if (!mounted) return;
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos de empresa actualizados')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible actualizar la empresa: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    setState(() => _step = 1);
  }


  bool _validateEmpresaStep({bool showStep = false}) {
    final formState = _empresaFormKey.currentState;

    // Cuando el usuario está en el paso 2 o 3, el formulario del paso 1 no
    // está montado en el árbol de widgets. Por eso currentState puede ser null.
    // En ese caso validamos directamente los controladores para evitar el error
    // "Unexpected null value" al finalizar desde el resumen.
    if (formState != null) {
      final valid = formState.validate();
      if (!valid && showStep) setState(() => _step = 0);
      return valid;
    }

    final errors = <String>[];
    void required(String value, String label) {
      if (value.trim().isEmpty) errors.add(label);
    }

    required(_tipoIdentificacion.text, 'Tipo de identificación');
    required(_paisTelefono.text, 'País teléfono');
    required(_ciudad.text, 'Ciudad');
    required(_zona.text, 'Zona horaria');
    required(_nombreComercial.text, 'Nombre comercial');
    required(_razonSocial.text, 'Razón social');
    required(_identificacion.text, 'Identificación');
    required(_direccion.text, 'Dirección');
    required(_telefono.text, 'Teléfono');
    required(_correo.text, 'Correo electrónico');

    final emailError = _emailValidator(_correo.text);
    if (emailError != null && _correo.text.trim().isNotEmpty) errors.add('Correo electrónico válido');

    final urlError = _optionalUrlValidator(_sitioWeb.text);
    if (urlError != null) errors.add('Sitio web válido');

    if (errors.isEmpty) return true;

    if (showStep && mounted) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revisa los datos de empresa: ${errors.join(', ')}')),
      );
    }
    return false;
  }

  Future<void> _finalizeCreate() async {
    if (!_validateEmpresaStep(showStep: true)) return;

    setState(() => _saving = true);
    try {
      final created = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
            ApiPaths.empresas,
            _empresaPayload(),
            (json) => Map<String, dynamic>.from(json as Map),
          );
      final empresaId = (created.data?['emprId'] as num?)?.toInt();
      if (empresaId == null) throw Exception('No fue posible obtener el identificador de la empresa creada');

      for (final sucursal in _sucursales) {
        await ref.read(apiClientProvider).post(
              '${ApiPaths.empresas}/$empresaId/sucursales',
              sucursal.toPayload(empresaId: empresaId),
              (json) => json,
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa registrada correctamente')));
      context.go('/empresas');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible finalizar el registro: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEditAndFinish() async {
    if (!_validateEmpresaStep(showStep: true)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put('${ApiPaths.empresas}/${widget.id}', _empresaPayload(), (json) => json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados correctamente')));
      context.go('/empresas');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible guardar los cambios: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSucursalDialog({_SucursalDraft? sucursal, int? index}) async {
    final result = await showDialog<_SucursalDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SucursalDialog(
        sucursal: sucursal,
        lookupOptions: _lookupOptions,
        lookupErrors: _lookupErrors,
        loadingLookupFields: _loadingLookupFields,
      ),
    );
    if (result == null) return;

    if (_isEdit) {
      setState(() => _saving = true);
      try {
        final api = ref.read(apiClientProvider);
        if (result.sucuId == null) {
          final response = await api.post<Map<String, dynamic>>(
            '${ApiPaths.empresas}/${widget.id}/sucursales',
            result.toPayload(empresaId: int.tryParse(widget.id!)),
            (json) => Map<String, dynamic>.from(json as Map),
          );
          final created = _SucursalDraft.fromJson(response.data ?? <String, dynamic>{});
          setState(() => _sucursales.add(created));
        } else {
          await api.put('${ApiPaths.sucursales}/${result.sucuId}', result.toPayload(empresaId: int.tryParse(widget.id!)), (json) => json);
          setState(() => _sucursales[index!] = result);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.sucuId == null ? 'Sucursal creada' : 'Sucursal actualizada')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible guardar la sucursal: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    setState(() {
      if (index == null) {
        _sucursales.add(result);
      } else {
        _sucursales[index] = result;
      }
    });
  }

  Future<void> _deleteSucursal(int index) async {
    final sucursal = _sucursales[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar sucursal'),
        content: Text('¿Deseas eliminar ${sucursal.sucuNombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_isEdit && sucursal.sucuId != null) {
      setState(() => _saving = true);
      try {
        await ref.read(apiClientProvider).delete('${ApiPaths.sucursales}/${sucursal.sucuId}', (json) => json);
        setState(() => _sucursales.removeAt(index));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal eliminada')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible eliminar la sucursal: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    setState(() => _sucursales.removeAt(index));
  }

  @override
  void dispose() {
    for (final c in [
      _nombreComercial,
      _razonSocial,
      _identificacion,
      _direccion,
      _codigoPostal,
      _telefono,
      _correo,
      _sitioWeb,
      _logo,
      _estado,
      _ciudad,
      _zona,
      _paisTelefono,
      _tipoIdentificacion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoader();

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isEdit ? 'Modificar empresa' : 'Crear empresa',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/empresas'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Volver'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _WizardStepsTabs(currentStep: _step, editMode: _isEdit, onStepTap: (step) => setState(() => _step = step)),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (_step) {
                        0 => _empresaStep(),
                        1 => _sucursalesStep(),
                        _ => _summaryStep(),
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

  Widget _empresaStep() {
    return Form(
      key: _empresaFormKey,
      child: Column(
        key: const ValueKey('empresa-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            icon: Icons.business_rounded,
            title: 'Paso 1: datos de empresa',
            description: _isEdit
                ? 'Actualiza la información principal de la empresa. Al continuar, este paso queda guardado.'
                : 'Completa los datos de empresa. Nada se guarda todavía; el registro real se hará al finalizar.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 760;
              final fieldWidth = twoColumns ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  SizedBox(width: fieldWidth, child: _textField(_nombreComercial, 'Nombre comercial', Icons.storefront_rounded)),
                  SizedBox(width: fieldWidth, child: _textField(_razonSocial, 'Razón social', Icons.apartment_rounded)),
                  SizedBox(width: fieldWidth, child: _lookupField(_tipoIdentificacion, _tipoIdentificacionField)),
                  SizedBox(width: fieldWidth, child: _textField(_identificacion, 'Identificación', Icons.badge_outlined)),
                  SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                  SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                  SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                  SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone)),
                  SizedBox(width: fieldWidth, child: _textField(_correo, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: _emailValidator)),
                  SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined)),
                  SizedBox(width: fieldWidth, child: _textField(_codigoPostal, 'Código postal', Icons.local_post_office_outlined, required: false)),
                  SizedBox(width: fieldWidth, child: _textField(_sitioWeb, 'Sitio web (opcional)', Icons.language_rounded, required: false, validator: _optionalUrlValidator)),
                  SizedBox(width: fieldWidth, child: _textField(_logo, 'Logo / URL del logo (opcional)', Icons.image_outlined, required: false)),
                  SizedBox(width: fieldWidth, child: _textField(_estado, 'Estado', Icons.toggle_on_outlined, keyboardType: TextInputType.number)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => context.go('/empresas'), child: const Text('Cancelar'))),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: _isEdit ? 'Guardar y continuar' : 'Continuar a sucursales',
                  icon: Icons.arrow_forward_rounded,
                  loading: _saving,
                  onPressed: _continueFromEmpresaStep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sucursalesStep() {
    return Column(
      key: const ValueKey('sucursales-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          icon: Icons.storefront_rounded,
          title: 'Paso 2: sucursales',
          description: _isEdit
              ? 'Puedes crear, modificar o eliminar sucursales. Cada cambio de sucursal se guarda inmediatamente.'
              : 'Agrega las sucursales que tendrá la empresa. Siguen en borrador hasta que finalices el registro.',
        ),
        const SizedBox(height: 18),
        _BranchesList(
          sucursales: _sucursales,
          labelFor: _labelFor,
          onEdit: (index) => _openSucursalDialog(sucursal: _sucursales[index], index: index),
          onDelete: _deleteSucursal,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _openSucursalDialog(),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Agregar sucursal'),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('Volver'))),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Continuar al resumen',
                icon: Icons.summarize_rounded,
                loading: _saving,
                onPressed: () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryStep() {
    return Column(
      key: const ValueKey('summary-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          icon: Icons.fact_check_rounded,
          title: 'Paso 3: resumen y confirmación',
          description: _isEdit
              ? 'Revisa el consolidado. Los cambios de sucursales ya fueron guardados en el paso anterior; al finalizar se actualizan los datos principales de la empresa.'
              : 'Revisa el consolidado. Solo al presionar finalizar se registrará la empresa y sus sucursales en el backend.',
        ),
        const SizedBox(height: 18),
        _SummarySection(
          title: 'Empresa',
          items: {
            'Nombre comercial': _nombreComercial.text,
            'Razón social': _razonSocial.text,
            'Tipo de identificación': _labelFor(_tipoIdentificacionField.name, _tipoIdentificacion.text),
            'Identificación': _identificacion.text,
            'Ciudad': _labelFor(_ciudadField.name, _ciudad.text),
            'Zona horaria': _labelFor(_zonaField.name, _zona.text),
            'País teléfono': _labelFor(_paisTelefonoField.name, _paisTelefono.text),
            'Teléfono': _telefono.text,
            'Correo': _correo.text,
            'Dirección': _direccion.text,
            'Código postal': _codigoPostal.text,
            'Sitio web': _sitioWeb.text.isEmpty ? 'No aplica' : _sitioWeb.text,
            'Logo': _logo.text.isEmpty ? 'No aplica' : _logo.text,
          },
        ),
        const SizedBox(height: 16),
        _SummaryBranches(sucursales: _sucursales, labelFor: _labelFor),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('Volver'))),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: _isEdit ? 'Finalizar modificación' : 'Finalizar y registrar',
                icon: Icons.check_circle_rounded,
                loading: _saving,
                onPressed: _isEdit ? _saveEditAndFinish : _finalizeCreate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lookupField(TextEditingController controller, CrudField field) {
    return LookupDropdown(
      controller: controller,
      field: field,
      options: _lookupOptions[field.name] ?? const <CrudLookupOption>[],
      loading: _loadingLookupFields.contains(field.name),
      errorMessage: _lookupErrors[field.name],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator ?? (required ? _requiredValidator : null),
    );
  }

  String? _requiredValidator(String? value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  String? _emailValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;
    final email = value!.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'Ingresa un correo electrónico válido';
  }

  String? _optionalUrlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final valid = Uri.tryParse(text)?.hasAbsolutePath == true && (text.startsWith('http://') || text.startsWith('https://'));
    return valid ? null : 'Ingresa una URL válida con http:// o https://';
  }

  String _labelFor(String fieldName, Object? id) {
    final text = id?.toString() ?? '';
    if (text.isEmpty) return '-';
    final option = (_lookupOptions[fieldName] ?? const <CrudLookupOption>[]).where((item) => item.id?.toString() == text).firstOrNull;
    return option?.label ?? '-';
  }
}

class _SucursalDraft {
  const _SucursalDraft({
    this.sucuId,
    this.emprId,
    required this.ciudId,
    required this.zohoId,
    required this.moneId,
    required this.paisIdtelefono,
    required this.sucuNombre,
    required this.sucuCodigoInterno,
    required this.sucuDireccion,
    required this.sucuTelefono,
    required this.sucuEstado,
  });

  final int? sucuId;
  final int? emprId;
  final int ciudId;
  final int zohoId;
  final int moneId;
  final int paisIdtelefono;
  final String sucuNombre;
  final String sucuCodigoInterno;
  final String sucuDireccion;
  final String sucuTelefono;
  final int sucuEstado;

  factory _SucursalDraft.fromJson(Map<String, dynamic> json) => _SucursalDraft(
        sucuId: (json['sucuId'] as num?)?.toInt(),
        emprId: (json['emprId'] as num?)?.toInt(),
        ciudId: (json['ciudId'] as num?)?.toInt() ?? 0,
        zohoId: (json['zohoId'] as num?)?.toInt() ?? 0,
        moneId: (json['moneId'] as num?)?.toInt() ?? 0,
        paisIdtelefono: (json['paisIdtelefono'] as num?)?.toInt() ?? 0,
        sucuNombre: json['sucuNombre']?.toString() ?? '',
        sucuCodigoInterno: json['sucuCodigoInterno']?.toString() ?? '',
        sucuDireccion: json['sucuDireccion']?.toString() ?? '',
        sucuTelefono: json['sucuTelefono']?.toString() ?? '',
        sucuEstado: (json['sucuEstado'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toPayload({int? empresaId}) => <String, dynamic>{
        'emprId': empresaId ?? emprId,
        'ciudId': ciudId,
        'zohoId': zohoId,
        'moneId': moneId,
        'paisIdtelefono': paisIdtelefono,
        'sucuNombre': sucuNombre,
        'sucuCodigoInterno': sucuCodigoInterno,
        'sucuDireccion': sucuDireccion,
        'sucuTelefono': sucuTelefono,
        'sucuEstado': sucuEstado,
      };
}

class _SucursalDialog extends StatefulWidget {
  const _SucursalDialog({
    required this.lookupOptions,
    required this.lookupErrors,
    required this.loadingLookupFields,
    this.sucursal,
  });

  final _SucursalDraft? sucursal;
  final Map<String, List<CrudLookupOption>> lookupOptions;
  final Map<String, String> lookupErrors;
  final Set<String> loadingLookupFields;

  @override
  State<_SucursalDialog> createState() => _SucursalDialogState();
}

class _SucursalDialogState extends State<_SucursalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _codigo;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late final TextEditingController _ciudad;
  late final TextEditingController _zona;
  late final TextEditingController _moneda;
  late final TextEditingController _paisTelefono;
  late final TextEditingController _estado;

  static const _ciudadField = _EmpresasFormPageState._ciudadField;
  static const _zonaField = _EmpresasFormPageState._zonaField;
  static const _monedaField = _EmpresasFormPageState._monedaField;
  static const _paisTelefonoField = _EmpresasFormPageState._paisTelefonoField;

  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _nombre = TextEditingController(text: s?.sucuNombre ?? '');
    _codigo = TextEditingController(text: s?.sucuCodigoInterno ?? 'PRINCIPAL');
    _direccion = TextEditingController(text: s?.sucuDireccion ?? '');
    _telefono = TextEditingController(text: s?.sucuTelefono ?? '');
    _ciudad = TextEditingController(text: s?.ciudId.toString() ?? '');
    _zona = TextEditingController(text: s?.zohoId.toString() ?? '');
    _moneda = TextEditingController(text: s?.moneId.toString() ?? '');
    _paisTelefono = TextEditingController(text: s?.paisIdtelefono.toString() ?? '');
    _estado = TextEditingController(text: s?.sucuEstado.toString() ?? '1');
  }

  @override
  void dispose() {
    for (final c in [_nombre, _codigo, _direccion, _telefono, _ciudad, _zona, _moneda, _paisTelefono, _estado]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.sucursal == null ? 'Agregar sucursal' : 'Modificar sucursal', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 840,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 680;
                final fieldWidth = twoColumns ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    SizedBox(width: fieldWidth, child: _textField(_nombre, 'Nombre sucursal', Icons.storefront_outlined)),
                    SizedBox(width: fieldWidth, child: _textField(_codigo, 'Código interno', Icons.tag_rounded)),
                    SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_moneda, _monedaField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                    SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined)),
                    SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone)),
                    SizedBox(width: fieldWidth, child: _textField(_estado, 'Estado', Icons.toggle_on_outlined, keyboardType: TextInputType.number)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Aceptar')),
      ],
    );
  }

  Widget _lookupField(TextEditingController controller, CrudField field) {
    return LookupDropdown(
      controller: controller,
      field: field,
      options: widget.lookupOptions[field.name] ?? const <CrudLookupOption>[],
      loading: widget.loadingLookupFields.contains(field.name),
      errorMessage: widget.lookupErrors[field.name],
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _SucursalDraft(
        sucuId: widget.sucursal?.sucuId,
        emprId: widget.sucursal?.emprId,
        ciudId: int.tryParse(_ciudad.text) ?? 0,
        zohoId: int.tryParse(_zona.text) ?? 0,
        moneId: int.tryParse(_moneda.text) ?? 0,
        paisIdtelefono: int.tryParse(_paisTelefono.text) ?? 0,
        sucuNombre: _nombre.text.trim(),
        sucuCodigoInterno: _codigo.text.trim(),
        sucuDireccion: _direccion.text.trim(),
        sucuTelefono: _telefono.text.trim(),
        sucuEstado: int.tryParse(_estado.text) ?? 1,
      ),
    );
  }
}

class _WizardStepsTabs extends StatelessWidget {
  const _WizardStepsTabs({required this.currentStep, required this.editMode, required this.onStepTap});

  final int currentStep;
  final bool editMode;
  final ValueChanged<int> onStepTap;
  static const steps = ['Datos de empresa', 'Sucursales', 'Resumen'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final children = List.generate(steps.length, (index) {
            final selected = index == currentStep;
            final completed = index < currentStep;
            final content = InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onStepTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(
                      completed ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                      color: selected ? Colors.white : completed ? AppColors.success : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Paso ${index + 1}: ${steps[index]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return compact ? content : Expanded(child: content);
          });
          return compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children) : Row(children: children);
        },
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: AppColors.info, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchesList extends StatelessWidget {
  const _BranchesList({required this.sucursales, required this.labelFor, required this.onEdit, required this.onDelete});

  final List<_SucursalDraft> sucursales;
  final String Function(String fieldName, Object? id) labelFor;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(child: Text(sucursales.isEmpty ? 'Sucursales' : 'Sucursales (${sucursales.length})', style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            const Text('Aún no hay sucursales agregadas.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            ...List.generate(sucursales.length, (index) {
              final s = sucursales[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.successSoft, child: Icon(Icons.storefront_rounded, color: AppColors.success)),
                  title: Text(s.sucuNombre, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${s.sucuDireccion}\nCiudad: ${labelFor(_EmpresasFormPageState._ciudadField.name, s.ciudId)} · Moneda: ${labelFor(_EmpresasFormPageState._monedaField.name, s.moneId)}'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(onPressed: () => onEdit(index), icon: const Icon(Icons.edit_rounded), tooltip: 'Modificar'),
                      IconButton(onPressed: () => onDelete(index), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), tooltip: 'Eliminar'),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.items});

  final String title;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...items.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 170, child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
                    Expanded(child: Text(entry.value.isEmpty ? '-' : entry.value, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SummaryBranches extends StatelessWidget {
  const _SummaryBranches({required this.sucursales, required this.labelFor});

  final List<_SucursalDraft> sucursales;
  final String Function(String fieldName, Object? id) labelFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sucursales (${sucursales.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            const Text('No se registrarán sucursales en este momento.', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800))
          else
            ...sucursales.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: AppColors.infoSoft, child: Icon(Icons.storefront_rounded, color: AppColors.info)),
                  title: Text(s.sucuNombre, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${s.sucuDireccion}\nCiudad: ${labelFor(_EmpresasFormPageState._ciudadField.name, s.ciudId)} · Zona: ${labelFor(_EmpresasFormPageState._zonaField.name, s.zohoId)} · Moneda: ${labelFor(_EmpresasFormPageState._monedaField.name, s.moneId)} · País teléfono: ${labelFor(_EmpresasFormPageState._paisTelefonoField.name, s.paisIdtelefono)}'),
                  isThreeLine: true,
                )),
        ],
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
