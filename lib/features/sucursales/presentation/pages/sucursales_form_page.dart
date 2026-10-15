import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/lookup_dropdown.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sucursales_response_model.dart';
import '../sucursales_view_data.dart';

class SucursalesFormPage extends ConsumerStatefulWidget {
  const SucursalesFormPage({super.key, this.id, this.embedded = false});

  final String? id;
  final bool embedded;

  @override
  ConsumerState<SucursalesFormPage> createState() => _SucursalesFormPageState();
}

class _SucursalesFormPageState extends ConsumerState<SucursalesFormPage> {
  static const _empresaField = CrudField(
    name: 'emprId',
    label: 'Empresa propietaria',
    type: CrudFieldType.number,
    required: true,
  );
  static const _ciudadField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    required: true,
  );
  static const _monedaField = CrudField(
    name: 'moneId',
    label: 'Moneda de operación',
    type: CrudFieldType.number,
    required: true,
  );
  static const _paisField = CrudField(
    name: 'paisIdtelefono',
    label: 'País del teléfono',
    type: CrudFieldType.number,
    required: true,
  );
  static const _zonaField = CrudField(
    name: 'zohoId',
    label: 'Zona horaria',
    type: CrudFieldType.number,
    required: true,
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  final TextEditingController _telefono = TextEditingController();
  final TextEditingController _empresa = TextEditingController();
  final TextEditingController _ciudad = TextEditingController();
  final TextEditingController _moneda = TextEditingController();
  final TextEditingController _pais = TextEditingController();
  final TextEditingController _zona = TextEditingController();

  SucursalCatalogs _catalogs = const SucursalCatalogs();
  bool _active = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _managerEmpresaId;

  bool get _editing => widget.id != null;
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

  @override
  void initState() {
    super.initState();
    for (final controller in [_nombre, _codigo, _direccion, _telefono]) {
      controller.addListener(_refreshPreview);
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _nombre,
      _codigo,
      _direccion,
      _telefono,
      _empresa,
      _ciudad,
      _moneda,
      _pais,
      _zona,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isManager) {
        final raw = await ref.read(secureStorageProvider).read(StorageKeys.empresaId);
        _managerEmpresaId = int.tryParse(raw ?? '')?.toString();
        if (_managerEmpresaId == null) {
          throw StateError('No fue posible identificar la empresa asignada al gerente.');
        }
      }
      final apiClient = ref.read(apiClientProvider);
      final catalogsFuture = SucursalCatalogs.load(apiClient);
      final branchFuture = _editing
          ? apiClient.get<SucursalesResponseModel>(
              '${ApiPaths.sucursales}/${widget.id}',
              (json) => SucursalesResponseModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
          : null;

      final catalogs = await catalogsFuture;
      final branchResponse = branchFuture == null ? null : await branchFuture;
      final item = branchResponse?.data;

      if (!mounted) return;
      setState(() {
        _catalogs = catalogs;
        if (item != null) {
          _nombre.text = item.sucuNombre ?? '';
          _codigo.text = item.sucuCodigoInterno ?? '';
          _direccion.text = item.sucuDireccion ?? '';
          _telefono.text = item.sucuTelefono ?? '';
          _empresa.text = _isManager ? (_managerEmpresaId ?? '') : (item.emprId?.toString() ?? '');
          _ciudad.text = item.ciudId?.toString() ?? '';
          _moneda.text = item.moneId?.toString() ?? '';
          _pais.text = item.paisIdtelefono?.toString() ?? '';
          _zona.text = item.zohoId?.toString() ?? '';
          _active = item.sucuEstado == 1;
        } else if (!_editing) {
          _codigo.text = _suggestedCode();
          if (_isManager) {
            _empresa.text = _managerEmpresaId ?? '';
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _close([bool saved = false]) {
    if (widget.embedded) {
      Navigator.of(context).pop(saved);
    } else {
      context.go('/sucursales');
    }
  }

  String _suggestedCode() {
    final number = DateTime.now().millisecondsSinceEpoch.toString();
    return 'SUC-${number.substring(number.length - 4)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'emprId': int.tryParse(_isManager ? (_managerEmpresaId ?? '') : _empresa.text),
      'ciudId': int.tryParse(_ciudad.text),
      'zohoId': int.tryParse(_zona.text),
      'moneId': int.tryParse(_moneda.text),
      'paisIdtelefono': int.tryParse(_pais.text),
      'sucuNombre': _nombre.text.trim(),
      'sucuCodigoInterno': _codigo.text.trim().toUpperCase(),
      'sucuDireccion': _direccion.text.trim(),
      'sucuTelefono': _telefono.text.trim(),
      'sucuEstado': _active ? 1 : 0,
    };

    try {
      final apiClient = ref.read(apiClientProvider);
      if (_editing) {
        await apiClient.put<SucursalesResponseModel>(
          '${ApiPaths.sucursales}/${widget.id}',
          body,
          (json) => SucursalesResponseModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        );
      } else {
        await apiClient.post<SucursalesResponseModel>(
          ApiPaths.sucursales,
          body,
          (json) => SucursalesResponseModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Sucursal actualizada correctamente'
                : 'Sucursal creada correctamente',
          ),
        ),
      );
      _close(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar la sucursal: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            AppLoader(message: 'Preparando la sucursal...'),
          ],
        ),
      );
    }

    if (_error != null && _editing && _nombre.text.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: AppPageBackground()),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_mall_directory_outlined, size: 62, color: palette.warning),
                    const SizedBox(height: 14),
                    Text(
                      'No fue posible abrir la sucursal',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // El modal padre ya ajusta el tamaño por el teclado de iOS/Safari.
      // Evita que el Scaffold reduzca el formulario por segunda vez.
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: _FormHeader(
                        palette: palette,
                        editing: _editing,
                        active: _active,
                        onBack: () => _close(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Form(
                        key: _formKey,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final desktop = constraints.maxWidth >= 900;
                            final preview = _BranchPreview(
                              palette: palette,
                              name: _nombre.text.trim(),
                              code: _codigo.text.trim(),
                              company: _catalogs.empresa(int.tryParse(_empresa.text)),
                              city: _catalogs.ciudad(int.tryParse(_ciudad.text)),
                              address: _direccion.text.trim(),
                              phone: _telefono.text.trim(),
                              currency: _catalogs.moneda(int.tryParse(_moneda.text)),
                              active: _active,
                              onActiveChanged: (value) => setState(() => _active = value),
                            );
                            final form = _FormSections(
                              palette: palette,
                              nombre: _nombre,
                              codigo: _codigo,
                              direccion: _direccion,
                              telefono: _telefono,
                              empresa: _empresa,
                              ciudad: _ciudad,
                              moneda: _moneda,
                              pais: _pais,
                              zona: _zona,
                              catalogs: _catalogs,
                              managerCompanyLocked: _isManager,
                            );

                            if (desktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 310, child: preview),
                                  const SizedBox(width: 16),
                                  Expanded(child: form),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                preview,
                                const SizedBox(height: 14),
                                form,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // No mantener dos botones fijos encima del teclado: dejan sin espacio
      // a los campos. Reaparecen al cerrar el teclado.
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.97 : 0.995),
            border: Border(top: BorderSide(color: palette.cardBorder)),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow,
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          // Keep the footer at its intrinsic height inside a modal sheet.
          // An unconstrained Center expands to the entire available height,
          // leaving the Scaffold body (the actual form) with no space.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = OutlinedButton.icon(
                    onPressed: _saving ? null : () => _close(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  );
                  final save = AppButton(
                    label: _editing ? 'Guardar cambios' : 'Crear sucursal',
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onPressed: _save,
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [cancel, const SizedBox(height: 8), save],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: save),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.palette,
    required this.editing,
    required this.active,
    required this.onBack,
  });

  final AppPalette palette;
  final bool editing;
  final bool active;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 27, tint: palette.secondary),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            tooltip: 'Volver a sucursales',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 11),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              editing ? Icons.edit_location_alt_rounded : Icons.add_business_rounded,
              color: palette.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Modificar sucursal' : 'Crear nueva sucursal',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  editing
                      ? 'Actualiza la información operativa sin perder la configuración de la sede.'
                      : 'Define la identidad, ubicación y configuración principal de la sede.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (active ? palette.success : palette.warning).withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              active ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: active ? palette.success : palette.warning,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPreview extends StatelessWidget {
  const _BranchPreview({
    required this.palette,
    required this.name,
    required this.code,
    required this.company,
    required this.city,
    required this.address,
    required this.phone,
    required this.currency,
    required this.active,
    required this.onActiveChanged,
  });

  final AppPalette palette;
  final String name;
  final String code;
  final String company;
  final String city;
  final String address;
  final String phone;
  final String currency;
  final bool active;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = active ? palette.success : palette.warning;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(
        baseRadius: 28,
        tint: active ? palette.secondary : palette.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.primary, active ? palette.secondary : palette.warning],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 45),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name.isEmpty ? 'Nombre de la sucursal' : name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            code.isEmpty ? 'CÓDIGO INTERNO' : code.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.secondary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active ? 'Disponible para operar' : 'Fuera de operación',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
                  ),
                ),
                Switch.adaptive(value: active, onChanged: onActiveChanged),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PreviewLine(icon: Icons.business_rounded, value: company, palette: palette),
          const SizedBox(height: 10),
          _PreviewLine(icon: Icons.location_city_rounded, value: city, palette: palette),
          const SizedBox(height: 10),
          _PreviewLine(
            icon: Icons.location_on_rounded,
            value: address.isEmpty ? 'Dirección pendiente' : address,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _PreviewLine(
            icon: Icons.phone_rounded,
            value: phone.isEmpty ? 'Teléfono pendiente' : phone,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _PreviewLine(icon: Icons.payments_rounded, value: currency, palette: palette),
          const SizedBox(height: 16),
          Text(
            'La moneda y zona horaria afectan precios, cierres y reportes de esta sede.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.8,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.icon, required this.value, required this.palette});

  final IconData icon;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: palette.secondary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormSections extends StatelessWidget {
  const _FormSections({
    required this.palette,
    required this.nombre,
    required this.codigo,
    required this.direccion,
    required this.telefono,
    required this.empresa,
    required this.ciudad,
    required this.moneda,
    required this.pais,
    required this.zona,
    required this.catalogs,
    required this.managerCompanyLocked,
  });

  final AppPalette palette;
  final TextEditingController nombre;
  final TextEditingController codigo;
  final TextEditingController direccion;
  final TextEditingController telefono;
  final TextEditingController empresa;
  final TextEditingController ciudad;
  final TextEditingController moneda;
  final TextEditingController pais;
  final TextEditingController zona;
  final SucursalCatalogs catalogs;
  final bool managerCompanyLocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          palette: palette,
          icon: Icons.badge_rounded,
          title: 'Identidad de la sede',
          subtitle: 'Información con la que reconocerás esta sucursal en menús y reportes.',
          children: [
            AppTextField(
              controller: nombre,
              label: 'Nombre de la sucursal',
              hintText: 'Ej. Sede Centro',
              prefixIcon: Icons.storefront_rounded,
              validator: Validators.required,
              maxLength: 100,
            ),
            AppTextField(
              controller: codigo,
              label: 'Código interno',
              hintText: 'Ej. CENTRO-01',
              prefixIcon: Icons.qr_code_rounded,
              validator: Validators.required,
              maxLength: 50,
            ),
            LookupDropdown(
              controller: empresa,
              field: _SucursalesFormPageState._empresaField,
              options: catalogs.empresaOptions,
              enabled: !managerCompanyLocked,
              helperText: managerCompanyLocked
                  ? 'Empresa asignada al perfil de gerente'
                  : 'Empresa a la que pertenece la sede',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          palette: palette,
          icon: Icons.map_rounded,
          title: 'Ubicación y horario',
          subtitle: 'Define dónde opera y cómo deben interpretarse sus fechas y horas.',
          children: [
            LookupDropdown(
              controller: ciudad,
              field: _SucursalesFormPageState._ciudadField,
              options: catalogs.ciudadOptions,
            ),
            AppTextField(
              controller: direccion,
              label: 'Dirección',
              hintText: 'Calle, carrera, número y referencia',
              prefixIcon: Icons.location_on_rounded,
              validator: Validators.required,
              maxLength: 100,
            ),
            LookupDropdown(
              controller: zona,
              field: _SucursalesFormPageState._zonaField,
              options: catalogs.zonaOptions,
              helperText: 'Se usa en ventas, cierres y auditoría',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          palette: palette,
          icon: Icons.point_of_sale_rounded,
          title: 'Operación y contacto',
          subtitle: 'Configuración utilizada en precios, cobros y comunicación de la sede.',
          children: [
            LookupDropdown(
              controller: moneda,
              field: _SucursalesFormPageState._monedaField,
              options: catalogs.monedaOptions,
              helperText: 'Moneda usada en precios y ventas',
            ),
            LookupDropdown(
              controller: pais,
              field: _SucursalesFormPageState._paisField,
              options: catalogs.paisOptions,
              helperText: 'Indicativo telefónico de la sucursal',
            ),
            AppTextField(
              controller: telefono,
              label: 'Teléfono principal',
              hintText: 'Número de contacto de la sede',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: Validators.required,
              maxLength: 20,
              inputFormatters: InputConstraints.phoneFormatters(20),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 27, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: palette.secondary, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 690 ? 2 : 1;
              final spacing = 12.0;
              final width = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final child in children) SizedBox(width: width, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
