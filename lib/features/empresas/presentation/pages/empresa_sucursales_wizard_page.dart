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
    if (_loading) return const Scaffold(body: AppLoader());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Crear empresa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _WizardStepsTabs(currentStep: 1),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.storefront_rounded, color: AppColors.info, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paso 2: crea las sucursales', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(
                                'La empresa ya fue creada. Ahora agrega una o varias sedes. Las relaciones como ciudad, zona horaria, moneda y país teléfono se seleccionan con ayudas de búsqueda.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Nueva sucursal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 20,
                                runSpacing: 16,
                                children: [
                                  SizedBox(width: fieldWidth, child: _textField(_nombre, 'Nombre sucursal', Icons.storefront_outlined)),
                                  SizedBox(width: fieldWidth, child: _textField(_codigo, 'Código interno', Icons.tag_rounded)),
                                  SizedBox(width: fieldWidth, child: _textField(_direccion, 'Dirección', Icons.location_on_outlined)),
                                  SizedBox(width: fieldWidth, child: _textField(_telefono, 'Teléfono', Icons.phone_outlined)),
                                  SizedBox(width: fieldWidth, child: _lookupField(_ciudad, _ciudadField)),
                                  SizedBox(width: fieldWidth, child: _lookupField(_zona, _zonaField)),
                                  SizedBox(width: fieldWidth, child: _lookupField(_moneda, _monedaField)),
                                  SizedBox(width: fieldWidth, child: _lookupField(_paisTelefono, _paisTelefonoField)),
                                  SizedBox(width: fieldWidth, child: _textField(_estado, 'Estado', Icons.toggle_on_outlined, keyboardType: TextInputType.number)),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.go('/empresas'),
                                      icon: const Icon(Icons.check_rounded),
                                      label: Text(_sucursales.isEmpty ? 'Omitir y finalizar' : 'Finalizar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppButton(
                                      label: 'Agregar sucursal',
                                      icon: Icons.add_business_rounded,
                                      loading: _saving,
                                      onPressed: _createSucursal,
                                    ),
                                  ),
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
            ),
          ),
        ),
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

  Widget _textField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }
}

class _ExistingBranches extends StatelessWidget {
  const _ExistingBranches({required this.sucursales});

  final List<Map<String, dynamic>> sucursales;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sucursales.isEmpty ? 'Sucursales agregadas' : 'Sucursales agregadas (${sucursales.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sucursales.isEmpty)
            const Text('Aún no hay sucursales creadas para esta empresa.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            ...sucursales.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: AppColors.successSoft, child: Icon(Icons.storefront_rounded, color: AppColors.success)),
                title: Text(s['sucuNombre']?.toString() ?? 'Sucursal', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(s['sucuDireccion']?.toString() ?? ''),
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStepsTabs extends StatelessWidget {
  const _WizardStepsTabs({required this.currentStep});

  final int currentStep;
  static const steps = ['Datos de empresa', 'Sucursales', 'Finalizar'];

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
          final compact = constraints.maxWidth < 620;
          final children = List.generate(steps.length, (index) {
            final selected = index == currentStep;
            final completed = index < currentStep;
            final content = AnimatedContainer(
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
                    color: selected
                        ? Colors.white
                        : completed
                            ? AppColors.success
                            : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Paso ${index + 1}: ${steps[index]}',
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
            );
            return compact ? content : Expanded(child: content);
          });
          return compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children) : Row(children: children);
        },
      ),
    );
  }
}
