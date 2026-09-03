import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/lookup_dropdown.dart';
import '../../../../core/widgets/tech_background.dart';

class EmpresaSucursalesWizardPage extends ConsumerStatefulWidget {
  const EmpresaSucursalesWizardPage({super.key, required this.empresaId});
  final String empresaId;

  @override
  ConsumerState<EmpresaSucursalesWizardPage> createState() => _EmpresaSucursalesWizardPageState();
}

class _EmpresaSucursalesWizardPageState extends ConsumerState<EmpresaSucursalesWizardPage> {
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
  static const _monedaField = CrudField(
    name: 'moneId',
    label: 'Moneda',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.monedas, idField: 'moneId', displayFields: ['moneCodigoiso', 'moneNombre', 'moneSimbolo']),
  );
  static const _paisTelefonoField = CrudField(
    name: 'paisIdtelefono',
    label: 'País teléfono',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(endpoint: ApiPaths.paises, idField: 'paisId', displayFields: ['paisNombre', 'paisCodigo']),
  );

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _codigo = TextEditingController(text: 'PRINCIPAL');
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _zona = TextEditingController();
  final _moneda = TextEditingController();
  final _paisTelefono = TextEditingController();
  final _estado = TextEditingController(text: '1');

  final Map<String, List<CrudLookupOption>> _lookupOptions = <String, List<CrudLookupOption>>{};
  final Map<String, String> _lookupErrors = <String, String>{};
  final Set<String> _loadingLookupFields = <String>{};

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _sucursales = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadSucursales(),
        _loadLookupOptions(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSucursales() async {
    final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
      '${ApiPaths.sucursales}/empresa/${widget.empresaId}',
      (json) => (json as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
    _sucursales = response.data ?? const [];
  }

  Future<void> _loadLookupOptions() async {
    final fields = [_ciudadField, _zonaField, _monedaField, _paisTelefonoField];
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

  Future<void> _createSucursal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post(
        '${ApiPaths.empresas}/${widget.empresaId}/sucursales',
        {
          // Se envía también como respaldo para compatibilidad con versiones del backend
          // que validan emprId en SucursalRequest. El endpoint guiado debe tomarlo del path.
          'emprId': int.tryParse(widget.empresaId),
          'ciudId': int.tryParse(_ciudad.text),
          'zohoId': int.tryParse(_zona.text),
          'moneId': int.tryParse(_moneda.text),
          'paisIdtelefono': int.tryParse(_paisTelefono.text),
          'sucuNombre': _nombre.text.trim(),
          'sucuCodigoInterno': _codigo.text.trim(),
          'sucuDireccion': _direccion.text.trim(),
          'sucuTelefono': _telefono.text.trim(),
          'sucuEstado': int.tryParse(_estado.text) ?? 1,
        },
        (json) => json,
      );
      _nombre.clear();
      _codigo.text = 'PRINCIPAL';
      _direccion.clear();
      _telefono.clear();
      await _loadSucursales();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal creada correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible crear sucursal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final palette = ref.watch(selectedAppPaletteProvider);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppPageBackground()),
            AppLoader(message: 'Cargando configuración de sucursales...'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WizardContextHeader(
                      palette: palette,
                      branchCount: _sucursales.length,
                      onBack: () => context.go('/empresas'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
                            palette.secondary.withOpacity(palette.darkBackground ? 0.10 : 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: palette.translucentBorder),
                        boxShadow: [
                          BoxShadow(
                            color: palette.cardShadow,
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _WizardStepsTabs(currentStep: 1),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 620;
                              final icon = Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                                  borderRadius: BorderRadius.circular(19),
                                ),
                                child: Icon(Icons.storefront_rounded, color: palette.onPrimary, size: 29),
                              );
                              final copy = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Paso 2: crea las sucursales',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'La empresa ya fue creada. Agrega una o varias sedes y define ciudad, zona horaria, moneda y país del teléfono.',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [icon, const SizedBox(height: 12), copy],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [icon, const SizedBox(width: 14), Expanded(child: copy)],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          _ExistingBranches(sucursales: _sucursales),
                          const SizedBox(height: 20),
                          Form(
                            key: _formKey,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final twoColumns = constraints.maxWidth > 720;
                                final fieldWidth = twoColumns ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
                                final finishButton = OutlinedButton.icon(
                                  onPressed: _saving ? null : () => context.go('/empresas'),
                                  icon: const Icon(Icons.check_rounded),
                                  label: Text(_sucursales.isEmpty ? 'Omitir y finalizar' : 'Finalizar'),
                                );
                                final addButton = AppButton(
                                  label: 'Agregar sucursal',
                                  icon: Icons.add_business_rounded,
                                  loading: _saving,
                                  onPressed: _createSucursal,
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: palette.secondary,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Nueva sucursal',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: palette.textPrimary,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 20,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(width: fieldWidth, child: _textField(_nombre, 'Nombre sucursal', Icons.storefront_outlined, maxLength: 100)),
                                        SizedBox(width: fieldWidth, child: _textField(_codigo, 'Código interno', Icons.tag_rounded, maxLength: 50)),
                                        SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined, maxLength: 100)),
                                        SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined, keyboardType: TextInputType.phone, maxLength: 20)),
                                        SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                                        SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                                        SizedBox(width: fieldWidth, child: _lookupField(_moneda, _monedaField)),
                                        SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                                        SizedBox(width: fieldWidth, child: _textField(_estado, 'Estado', Icons.toggle_on_outlined, keyboardType: TextInputType.number, maxLength: 1, inputFormatters: InputConstraints.digitsFormatters(1), validator: (value) => value == '0' || value == '1' ? null : 'Usa 1 para activa o 0 para inactiva')),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    if (constraints.maxWidth < 560) ...[
                                      addButton,
                                      const SizedBox(height: 10),
                                      finishButton,
                                    ] else
                                      Row(
                                        children: [
                                          Expanded(child: finishButton),
                                          const SizedBox(width: 12),
                                          Expanded(child: addButton),
                                        ],
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterText: maxLength == null ? null : '',
      ),
      validator: validator ?? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }
}

class _WizardContextHeader extends StatelessWidget {
  const _WizardContextHeader({
    required this.palette,
    required this.branchCount,
    required this.onBack,
  });

  final AppPalette palette;
  final int branchCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a empresas',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: palette.textPrimary,
          ),
          const SizedBox(width: 4),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_business_rounded, color: palette.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurar sucursales',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  branchCount == 0 ? 'Aún no se han agregado sedes' : '$branchCount ${branchCount == 1 ? 'sucursal creada' : 'sucursales creadas'}',
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingBranches extends ConsumerWidget {
  const _ExistingBranches({required this.sucursales});

  final List<Map<String, dynamic>> sucursales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.68),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: palette.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sucursales.isEmpty ? 'Sucursales agregadas' : 'Sucursales agregadas (${sucursales.length})',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            Text(
              'Aún no hay sucursales creadas para esta empresa.',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            )
          else
            ...sucursales.map(
              (sucursal) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface.withOpacity(palette.darkBackground ? 0.70 : 0.90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.storefront_rounded, color: palette.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sucursal['sucuNombre']?.toString() ?? 'Sucursal',
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sucursal['sucuDireccion']?.toString().trim().isNotEmpty == true
                                ? sucursal['sucuDireccion'].toString()
                                : 'Sin dirección registrada',
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStepsTabs extends ConsumerWidget {
  const _WizardStepsTabs({required this.currentStep});

  final int currentStep;
  static const steps = ['Datos de empresa', 'Sucursales', 'Finalizar'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.70),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final children = List.generate(steps.length, (index) {
            final selected = index == currentStep;
            final completed = index < currentStep;
            final content = AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: selected ? LinearGradient(colors: [palette.primary, palette.secondary]) : null,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(
                    completed ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                    color: selected
                        ? palette.onPrimary
                        : completed
                            ? palette.success
                            : palette.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Paso ${index + 1}: ${steps[index]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? palette.onPrimary : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
            return compact ? content : Expanded(child: content);
          });
          return compact
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
              : Row(children: children);
        },
      ),
    );
  }
}
