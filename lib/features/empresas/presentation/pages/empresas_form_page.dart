import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
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
  int _editSectionIndex = 0;

  bool get _isEdit => widget.id != null && widget.id!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nombreComercial.addListener(_refreshCompanyPreview);
    _razonSocial.addListener(_refreshCompanyPreview);
    _identificacion.addListener(_refreshCompanyPreview);
    _loadInitialData();
  }

  void _refreshCompanyPreview() {
    if (mounted && _isEdit) setState(() {});
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      if (!await _validateManagerScope()) return;
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

  Future<bool> _validateManagerScope() async {
    final roles = ref.read(authControllerProvider).roles.map(_normalizeRole).toSet();
    const globalAdmins = {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN'};
    final isGlobalAdmin = roles.any(globalAdmins.contains);
    final isManager = !isGlobalAdmin && (roles.contains('GERENTE') || roles.contains('MANAGER'));
    if (!isManager) return true;

    final profile = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
      ApiPaths.profile,
      (json) => Map<String, dynamic>.from(json as Map),
    );
    final companyId = (profile.data?['empresaId'] as num?)?.toInt();
    final routeId = int.tryParse(widget.id ?? '');
    final allowed = _isEdit ? companyId != null && routeId == companyId : companyId == null;
    if (allowed) return true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Solo puedes modificar la empresa asignada a tu usuario.'
                : 'Ya tienes una empresa asignada. Un gerente no puede crear una segunda empresa.',
          ),
        ),
      );
      context.go('/empresas');
    });
    return false;
  }

  String _normalizeRole(String value) {
    var normalized = value.trim().toUpperCase();
    if (normalized.startsWith('ROLE_')) normalized = normalized.substring(5);
    return normalized;
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
        'emprLogo': _isEdit ? _logo.text.trim() : (_logo.text.trim().isEmpty ? null : _logo.text.trim()),
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
    final formValid = _empresaFormKey.currentState?.validate() ?? true;
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

    if (formValid && errors.isEmpty) return true;

    if (showStep && mounted) {
      final identityInvalid = _nombreComercial.text.trim().isEmpty ||
          _razonSocial.text.trim().isEmpty ||
          _tipoIdentificacion.text.trim().isEmpty ||
          _identificacion.text.trim().isEmpty;
      final contactInvalid = _correo.text.trim().isEmpty ||
          _telefono.text.trim().isEmpty ||
          _paisTelefono.text.trim().isEmpty ||
          emailError != null ||
          urlError != null;
      final locationInvalid = _ciudad.text.trim().isEmpty ||
          _direccion.text.trim().isEmpty ||
          _zona.text.trim().isEmpty;

      setState(() {
        _step = 0;
        if (_isEdit) {
          _editSectionIndex = identityInvalid ? 0 : (contactInvalid ? 1 : (locationInvalid ? 2 : _editSectionIndex));
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.isEmpty ? 'Revisa los campos marcados.' : 'Revisa: ${errors.join(', ')}')),
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

      await ref.read(secureStorageProvider).write(StorageKeys.empresaId, '$empresaId');
      await ref.read(branchScopeProvider.notifier).load();

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
        scrollable: true,
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
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) {
      return const Stack(children: [Positioned.fill(child: AppPageBackground()), Positioned.fill(child: AppLoader())]);
    }

    if (_isEdit) return _buildEditPage(palette);

    return Stack(
      children: [
        const Positioned.fill(child: AppPageBackground()),
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: palette.secondary.withOpacity(0.15)),
                      boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
                        IconButton.filledTonal(onPressed: () => context.go('/empresas'), tooltip: 'Volver a empresas', icon: const Icon(Icons.arrow_back_rounded)),
                        const SizedBox(width: 10),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(15)),
                          child: Icon(Icons.business_center_rounded, color: palette.onPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isEdit ? 'Modificar empresa' : 'Crear empresa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                              const SizedBox(height: 2),
                              Text('Configura la identidad de la empresa, su logo y las sucursales iniciales.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: palette.cardBorder)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildEditPage(AppPalette palette) {
    return Stack(
      children: [
        const Positioned.fill(child: AppPageBackground()),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Form(
                key: _empresaFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _editHeader(palette),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final profile = _companyProfilePanel(palette);
                        final form = _companyEditWorkspace(palette);

                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [profile, const SizedBox(height: 14), form],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 280, child: profile),
                            const SizedBox(width: 16),
                            Expanded(child: form),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editHeader(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final title = Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.go('/empresas'),
                tooltip: 'Volver a empresas',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business_rounded, color: palette.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modificar empresa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      'Actualiza la identidad, el logo, el contacto y la operación sin salir de esta vista.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          );
          final save = AppButton(
            label: 'Guardar',
            icon: Icons.save_rounded,
            compact: true,
            loading: _saving,
            onPressed: _saveEditAndFinish,
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 12), save]);
          }
          return Row(children: [Expanded(child: title), const SizedBox(width: 12), SizedBox(width: 142, child: save)]);
        },
      ),
    );
  }

  Widget _companyProfilePanel(AppPalette palette) {
    final companyName = _nombreComercial.text.trim().isEmpty ? 'Tu empresa' : _nombreComercial.text.trim();
    final legalName = _razonSocial.text.trim().isEmpty ? 'Información comercial' : _razonSocial.text.trim();
    final active = (_estado.text.trim().isEmpty ? 1 : int.tryParse(_estado.text.trim()) ?? 1) != 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _logoEditorCard(compact: true),
          const SizedBox(height: 18),
          Text(companyName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 3),
          Text(legalName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (active ? AppColors.success : AppColors.danger).withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (active ? AppColors.success : AppColors.danger).withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Icon(active ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: active ? AppColors.success : AppColors.danger, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(active ? 'Empresa activa' : 'Empresa inactiva', style: TextStyle(color: active ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w900, fontSize: 12.5))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _statusField(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: palette.background.withOpacity(0.55), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, color: palette.secondary, size: 20),
                const SizedBox(width: 9),
                Expanded(child: Text('${_sucursales.length} ${_sucursales.length == 1 ? 'sucursal' : 'sucursales'} vinculadas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyEditWorkspace(AppPalette palette) {
    final sections = <({String label, IconData icon})>[
      (label: 'Identidad', icon: Icons.business_center_rounded),
      (label: 'Contacto', icon: Icons.contact_phone_rounded),
      (label: 'Ubicación', icon: Icons.location_on_rounded),
      (label: 'Sucursales', icon: Icons.storefront_rounded),
    ];

    final content = switch (_editSectionIndex) {
      0 => _editSection(
          palette: palette,
          icon: Icons.business_center_rounded,
          title: 'Identidad de la empresa',
          description: 'Nombre comercial, razón social e identificación tributaria.',
          children: [
            _textField(_nombreComercial, 'Nombre comercial', Icons.storefront_rounded, maxLength: 100),
            _textField(_razonSocial, 'Razón social', Icons.apartment_rounded, maxLength: 300),
            _lookupField(_tipoIdentificacion, _tipoIdentificacionField),
            _textField(_identificacion, 'Número de identificación', Icons.badge_outlined, maxLength: 20),
          ],
        ),
      1 => _editSection(
          palette: palette,
          icon: Icons.contact_phone_rounded,
          title: 'Contacto comercial',
          description: 'Información que se mostrará en documentos y canales de atención.',
          children: [
            _textField(_correo, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: _emailValidator, maxLength: 200),
            _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 15),
            _textField(_sitioWeb, 'Sitio web', Icons.language_rounded, required: false, validator: _optionalUrlValidator, maxLength: 300),
            _lookupField(_paisTelefono, _paisTelefonoField),
          ],
        ),
      2 => _editSection(
          palette: palette,
          icon: Icons.location_on_rounded,
          title: 'Ubicación y operación',
          description: 'Dirección principal, ciudad y zona horaria del negocio.',
          children: [
            _lookupField(_ciudad, _ciudadField),
            _textField(_direccion, 'Dirección principal', Icons.location_on_outlined, maxLength: 100),
            _textField(_codigoPostal, 'Código postal', Icons.local_post_office_outlined, required: false, maxLength: 30),
            _lookupField(_zona, _zonaField),
          ],
        ),
      _ => _branchesEditSection(palette),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.99),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: palette.cardBorder),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(sections.length, (index) {
                final section = sections[index];
                final selected = _editSectionIndex == index;
                return Padding(
                  padding: EdgeInsets.only(right: index == sections.length - 1 ? 0 : 4),
                  child: Material(
                    color: selected ? palette.secondary.withOpacity(0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: _saving ? null : () => setState(() => _editSectionIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(section.icon, size: 16, color: selected ? palette.secondary : palette.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              section.label,
                              style: TextStyle(
                                color: selected ? palette.secondary : palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(_editSectionIndex), child: content),
        ),
      ],
    );
  }

  Widget _editSection({
    required AppPalette palette,
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: palette.secondary, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 620;
              final width = twoColumns ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: children.map((child) => SizedBox(width: width, child: child)).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _branchesEditSection(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final title = Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.storefront_rounded, color: palette.secondary, size: 21)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sucursales', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15.5)), const SizedBox(height: 3), Text('Consulta o ajusta las sedes asociadas a esta empresa.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))])),
                ],
              );
              final add = OutlinedButton.icon(onPressed: _saving ? null : () => _openSucursalDialog(), icon: const Icon(Icons.add_business_rounded), label: const Text('Agregar sucursal'));
              if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 12), add]);
              return Row(children: [Expanded(child: title), const SizedBox(width: 12), add]);
            },
          ),
          const SizedBox(height: 16),
          _BranchesList(
            sucursales: _sucursales,
            labelFor: _labelFor,
            onEdit: (index) => _openSucursalDialog(sucursal: _sucursales[index], index: index),
            onDelete: _deleteSucursal,
          ),
        ],
      ),
    );
  }

  Widget _logoEditorCard({required bool compact}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final logoValue = _logo.text.trim();
    final previewSize = compact ? 88.0 : 96.0;
    final preview = Container(
      width: previewSize,
      height: previewSize,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.62),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.25), width: 2),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(21), child: _logoPreview(logoValue, palette)),
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      children: [
        FilledButton.tonalIcon(onPressed: _saving ? null : _pickCompanyLogo, icon: const Icon(Icons.upload_rounded, size: 17), label: Text(logoValue.isEmpty ? 'Cargar' : 'Cambiar')),
        OutlinedButton.icon(onPressed: _saving ? null : _setLogoFromUrl, icon: const Icon(Icons.link_rounded, size: 17), label: const Text('URL')),
        if (logoValue.isNotEmpty)
          IconButton.filledTonal(onPressed: _saving ? null : _removeCompanyLogo, tooltip: 'Eliminar logo', style: IconButton.styleFrom(foregroundColor: AppColors.danger), icon: const Icon(Icons.delete_outline_rounded)),
      ],
    );
    final info = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('Logo de la empresa', textAlign: compact ? TextAlign.center : TextAlign.start, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        Text('JPG, PNG o WEBP. Máximo 2 MB. También puedes usar una URL pública.', textAlign: compact ? TextAlign.center : TextAlign.start, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
        const SizedBox(height: 12),
        actions,
      ],
    );
    if (compact) return Column(children: [preview, const SizedBox(height: 13), info]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.background.withOpacity(0.52), borderRadius: BorderRadius.circular(22), border: Border.all(color: palette.cardBorder)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 540) return Column(children: [preview, const SizedBox(height: 13), info]);
          return Row(children: [preview, const SizedBox(width: 16), Expanded(child: info)]);
        },
      ),
    );
  }

  Widget _logoPreview(String value, AppPalette palette) {
    final fallback = Center(child: Icon(Icons.business_rounded, color: palette.secondary, size: 50));
    if (value.isEmpty) return fallback;
    final bytes = _decodeLogoBytes(value);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(value, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback, loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return fallback;
  }

  Uint8List? _decodeLogoBytes(String value) {
    try {
      final normalized = value.trim();
      if (normalized.startsWith('http://') || normalized.startsWith('https://')) return null;
      final raw = normalized.contains(',') ? normalized.substring(normalized.indexOf(',') + 1) : normalized;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickCompanyLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > InputConstraints.imageMaxBytes) {
        _showLogoMessage('El logo no puede superar 2 MB.');
        return;
      }
      final extension = (file?.extension ?? 'png').toLowerCase();
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/png',
      };
      setState(() => _logo.text = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      _showLogoMessage('No fue posible cargar el logo: $error');
    }
  }

  Future<void> _setLogoFromUrl() async {
    final controller = TextEditingController(text: _logo.text.trim().startsWith('http') ? _logo.text.trim() : '');
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Usar logo desde una URL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('La dirección debe ser pública y comenzar con http:// o https://.'),
            const SizedBox(height: 16),
            TextField(controller: controller, autofocus: true, keyboardType: TextInputType.url, maxLength: 3000000, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null, inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(3000000)], decoration: const InputDecoration(labelText: 'URL del logo', prefixIcon: Icon(Icons.link_rounded))),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => Navigator.of(sheetContext).pop(controller.text.trim()), icon: const Icon(Icons.check_rounded), label: const Text('Aplicar URL')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (value.isEmpty || uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showLogoMessage('Ingresa una URL válida con http:// o https://.');
      return;
    }
    setState(() => _logo.text = value);
  }

  void _removeCompanyLogo() {
    setState(_logo.clear);
    _showLogoMessage('El logo se eliminará cuando guardes los cambios.');
  }

  void _showLogoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _statusField() {
    final palette = ref.watch(selectedAppPaletteProvider);
    final active = (_estado.text.trim().isEmpty ? 1 : int.tryParse(_estado.text.trim()) ?? 1) != 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(color: palette.background.withOpacity(0.58), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: active,
        onChanged: _saving ? null : (value) => setState(() => _estado.text = value ? '1' : '0'),
        title: Text(active ? 'Empresa activa' : 'Empresa inactiva', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
        subtitle: Text(active ? 'La empresa puede operar normalmente.' : 'La empresa quedará fuera de operación.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
        secondary: Icon(active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded, color: active ? AppColors.success : AppColors.danger),
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
          _logoEditorCard(compact: false),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 760;
              final fieldWidth = twoColumns ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  SizedBox(width: fieldWidth, child: _textField(_nombreComercial, 'Nombre comercial', Icons.storefront_rounded, maxLength: 100)),
                  SizedBox(width: fieldWidth, child: _textField(_razonSocial, 'Razón social', Icons.apartment_rounded, maxLength: 300)),
                  SizedBox(width: fieldWidth, child: _lookupField(_tipoIdentificacion, _tipoIdentificacionField)),
                  SizedBox(width: fieldWidth, child: _textField(_identificacion, 'Identificación', Icons.badge_outlined, maxLength: 20)),
                  SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                  SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                  SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                  SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 15)),
                  SizedBox(width: fieldWidth, child: _textField(_correo, 'Correo electrónico', Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: _emailValidator, maxLength: 200)),
                  SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined, maxLength: 100)),
                  SizedBox(width: fieldWidth, child: _textField(_codigoPostal, 'Código postal', Icons.local_post_office_outlined, required: false, maxLength: 30)),
                  SizedBox(width: fieldWidth, child: _textField(_sitioWeb, 'Sitio web (opcional)', Icons.language_rounded, required: false, validator: _optionalUrlValidator, maxLength: 300)),
                  SizedBox(width: fieldWidth, child: _statusField()),
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
            'Logo': _logo.text.trim().isEmpty ? 'Sin logo configurado' : 'Logo configurado',
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
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final effectiveFormatters = inputFormatters ??
        (keyboardType == TextInputType.phone
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
                if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
              ]
            : keyboardType == TextInputType.number
                ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
                : maxLength == null
                    ? null
                    : <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)]);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: effectiveFormatters,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), counterText: maxLength == null ? null : ''),
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
        scrollable: true,
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
                    SizedBox(width: fieldWidth, child: _textField(_nombre, 'Nombre sucursal', Icons.storefront_outlined, maxLength: 100)),
                    SizedBox(width: fieldWidth, child: _textField(_codigo, 'Código interno', Icons.tag_rounded, maxLength: 50)),
                    SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_moneda, _monedaField)),
                    SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                    SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined, maxLength: 100)),
                    SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 20)),
                    SizedBox(width: fieldWidth, child: _textField(_estado, 'Estado', Icons.toggle_on_outlined, keyboardType: TextInputType.number, maxLength: 1, inputFormatters: InputConstraints.digitsFormatters(1), validator: (value) => value == '0' || value == '1' ? null : 'Usa 1 para activa o 0 para inactiva')),
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

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final effectiveFormatters = inputFormatters ??
        (keyboardType == TextInputType.phone
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
                if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
              ]
            : keyboardType == TextInputType.number
                ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
                : maxLength == null
                    ? null
                    : <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)]);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: effectiveFormatters,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), counterText: maxLength == null ? null : ''),
      validator: validator ?? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
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

class _WizardStepsTabs extends ConsumerWidget {
  const _WizardStepsTabs({required this.currentStep, required this.editMode, required this.onStepTap});

  final int currentStep;
  final bool editMode;
  final ValueChanged<int> onStepTap;
  static const steps = ['Datos de empresa', 'Sucursales', 'Resumen'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(gradient: palette.glassGradient, borderRadius: BorderRadius.circular(24), border: Border.all(color: palette.cardBorder)),
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
                  gradient: selected ? LinearGradient(colors: [palette.primary, palette.secondary]) : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(completed ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded, color: selected ? palette.onPrimary : completed ? AppColors.success : palette.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Paso ${index + 1}: ${steps[index]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? palette.onPrimary : palette.textPrimary, fontWeight: FontWeight.w900))),
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

class _StepHeader extends ConsumerWidget {
  const _StepHeader({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: palette.secondary, size: 30)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: palette.textPrimary)),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchesList extends ConsumerWidget {
  const _BranchesList({required this.sucursales, required this.labelFor, required this.onEdit, required this.onDelete});

  final List<_SucursalDraft> sucursales;
  final String Function(String fieldName, Object? id) labelFor;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(24), border: Border.all(color: palette.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Icon(Icons.list_alt_rounded, color: palette.secondary), const SizedBox(width: 8), Expanded(child: Text(sucursales.isEmpty ? 'Sucursales' : 'Sucursales (${sucursales.length})', style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)))]),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            Text('Aún no hay sucursales agregadas.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))
          else
            ...List.generate(sucursales.length, (index) {
              final s = sucursales[index];
              return Card(
                color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.99),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: palette.cardBorder)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: palette.secondary.withOpacity(0.12), child: Icon(Icons.storefront_rounded, color: palette.secondary)),
                  title: Text(s.sucuNombre, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                  subtitle: Text('${s.sucuDireccion}\nCiudad: ${labelFor(_EmpresasFormPageState._ciudadField.name, s.ciudId)} · Moneda: ${labelFor(_EmpresasFormPageState._monedaField.name, s.moneId)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                  isThreeLine: true,
                  trailing: Wrap(spacing: 4, children: [IconButton(onPressed: () => onEdit(index), icon: Icon(Icons.edit_rounded, color: palette.primary), tooltip: 'Modificar'), IconButton(onPressed: () => onDelete(index), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), tooltip: 'Eliminar')]),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.title, required this.items});

  final String title;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(24), border: Border.all(color: palette.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: palette.textPrimary)),
          const SizedBox(height: 10),
          ...items.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 170, child: Text(entry.key, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textSecondary))), Expanded(child: Text(entry.value.isEmpty ? '-' : entry.value, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)))]),
              )),
        ],
      ),
    );
  }
}

class _SummaryBranches extends ConsumerWidget {
  const _SummaryBranches({required this.sucursales, required this.labelFor});

  final List<_SucursalDraft> sucursales;
  final String Function(String fieldName, Object? id) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(24), border: Border.all(color: palette.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sucursales (${sucursales.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: palette.textPrimary)),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            Text('No se registrarán sucursales en este momento.', style: TextStyle(color: palette.warning, fontWeight: FontWeight.w800))
          else
            ...sucursales.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: palette.secondary.withOpacity(0.12), child: Icon(Icons.storefront_rounded, color: palette.secondary)),
                  title: Text(s.sucuNombre, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                  subtitle: Text('${s.sucuDireccion}\nCiudad: ${labelFor(_EmpresasFormPageState._ciudadField.name, s.ciudId)} · Zona: ${labelFor(_EmpresasFormPageState._zonaField.name, s.zohoId)} · Moneda: ${labelFor(_EmpresasFormPageState._monedaField.name, s.moneId)} · País teléfono: ${labelFor(_EmpresasFormPageState._paisTelefonoField.name, s.paisIdtelefono)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
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
