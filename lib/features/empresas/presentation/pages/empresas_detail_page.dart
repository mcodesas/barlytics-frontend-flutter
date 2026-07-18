import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

/// Vista de solo lectura para empresas.
///
/// Mantiene la misma experiencia visual del flujo de creación/modificación,
/// pero en modo consulta: dos pestañas internas siempre disponibles:
/// - Datos de empresa
/// - Datos de sucursales
class EmpresasDetailPage extends ConsumerStatefulWidget {
  const EmpresasDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EmpresasDetailPage> createState() => _EmpresasDetailPageState();
}

class _EmpresasDetailPageState extends ConsumerState<EmpresasDetailPage> {
  static const _ciudadField = CrudField(
    name: 'ciudId',
    label: 'Ciudad',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.ciudades,
      idField: 'ciudId',
      displayFields: ['ciudNombre', 'ciudCodigoDane'],
    ),
  );

  static const _zonaField = CrudField(
    name: 'zohoId',
    label: 'Zona horaria',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.zonashorarias,
      idField: 'zohoId',
      displayFields: ['zohoNombre', 'zohoAbreviatura', 'zohoOffsetOut'],
    ),
  );

  static const _paisTelefonoField = CrudField(
    name: 'paisIdtelefono',
    label: 'País teléfono',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.paises,
      idField: 'paisId',
      displayFields: ['paisNombre', 'paisCodigo'],
    ),
  );

  static const _tipoIdentificacionField = CrudField(
    name: 'tiidId',
    label: 'Tipo de identificación',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.tiposidentificacion,
      idField: 'tiidId',
      displayFields: ['tiidNombre', 'tiidDescripcion'],
    ),
  );

  static const _monedaField = CrudField(
    name: 'moneId',
    label: 'Moneda',
    type: CrudFieldType.number,
    required: true,
    lookup: CrudLookupConfig(
      endpoint: ApiPaths.monedas,
      idField: 'moneId',
      displayFields: ['moneCodigoiso', 'moneNombre', 'moneSimbolo'],
    ),
  );

  final Map<String, dynamic> _empresa = <String, dynamic>{};
  final List<Map<String, dynamic>> _sucursales = <Map<String, dynamic>>[];
  final Map<String, List<CrudLookupOption>> _lookupOptions = <String, List<CrudLookupOption>>{};

  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await _loadLookupOptions();
      await Future.wait([
        _loadEmpresa(),
        _loadSucursales(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmpresa() async {
    final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
          '${ApiPaths.empresas}/${widget.id}',
          (json) => Map<String, dynamic>.from(json as Map),
        );

    _empresa
      ..clear()
      ..addAll(response.data ?? <String, dynamic>{});
  }

  Future<void> _loadSucursales() async {
    final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
          '${ApiPaths.sucursales}/empresa/${widget.id}',
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );

    _sucursales
      ..clear()
      ..addAll(response.data ?? const <Map<String, dynamic>>[]);
  }

  Future<void> _loadLookupOptions() async {
    final fields = [_ciudadField, _zonaField, _paisTelefonoField, _tipoIdentificacionField, _monedaField];
    final apiClient = ref.read(apiClientProvider);

    for (final field in fields) {
      final lookup = field.lookup!;
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
      } catch (_) {
        _lookupOptions[field.name] = const <CrudLookupOption>[];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (_loading) {
      return const Stack(children: [Positioned.fill(child: AppPageBackground()), Positioned.fill(child: AppLoader())]);
    }

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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 620;
                        final title = Row(
                          children: [
                            IconButton.filledTonal(onPressed: () => context.go('/empresas'), tooltip: 'Volver a empresas', icon: const Icon(Icons.arrow_back_rounded)),
                            const SizedBox(width: 10),
                            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.business_center_rounded, color: palette.onPrimary)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Detalle de empresa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                                  const SizedBox(height: 2),
                                  Text('Consulta la empresa y las sucursales asociadas.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ],
                        );
                        final edit = OutlinedButton.icon(onPressed: () => _safeGo('/empresas/${widget.id}/editar'), icon: const Icon(Icons.edit_rounded), label: const Text('Modificar'));
                        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 12), edit]);
                        return Row(children: [Expanded(child: title), const SizedBox(width: 12), edit]);
                      },
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
                          _Header(
                            title: _value('empreNombreComercial').isEmpty ? 'Empresa' : _value('empreNombreComercial'),
                            subtitle: _value('emprRazonSocial').isEmpty ? 'Detalle de empresa y sucursales' : _value('emprRazonSocial'),
                          ),
                          const SizedBox(height: 20),
                          _ViewTabs(currentTab: _tab, onTabTap: (tab) => setState(() => _tab = tab)),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _tab == 0 ? _empresaTab() : _sucursalesTab()),
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

  void _safeGo(String location) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 1), () {
        if (mounted) context.go(location);
      });
    });
  }

  Widget _empresaTab() {
    return Column(
      key: const ValueKey('empresa-view-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.business_rounded,
          title: 'Datos de empresa',
          description: 'Información principal registrada para la empresa.',
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
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.storefront_rounded, label: 'Nombre comercial', value: _value('empreNombreComercial'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.apartment_rounded, label: 'Razón social', value: _value('emprRazonSocial'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.badge_outlined, label: 'Tipo de identificación', value: _labelFor(_tipoIdentificacionField.name, _empresa['tiidId']))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.confirmation_number_outlined, label: 'Identificación', value: _value('emprIdentificacion'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.location_city_rounded, label: 'Ciudad', value: _labelFor(_ciudadField.name, _empresa['ciudId']))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.schedule_rounded, label: 'Zona horaria', value: _labelFor(_zonaField.name, _empresa['zohoId']))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.flag_rounded, label: 'País teléfono', value: _labelFor(_paisTelefonoField.name, _empresa['paisIdtelefono']))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.phone_outlined, label: 'Teléfono', value: _value('emprTelefono'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.email_outlined, label: 'Correo electrónico', value: _value('emprCorreoElectronico'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.location_on_outlined, label: 'Dirección', value: _value('emprDireccion'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.local_post_office_outlined, label: 'Código postal', value: _value('emprCodigoPostal'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.language_rounded, label: 'Sitio web', value: _value('emprSitioWeb'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.image_outlined, label: 'Logo', value: _value('emprLogo'))),
                SizedBox(width: fieldWidth, child: _InfoTile(icon: Icons.toggle_on_outlined, label: 'Estado', value: _estadoLabel(_empresa['emprEstado']))),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sucursalesTab() {
    return Column(
      key: const ValueKey('sucursales-view-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.storefront_rounded,
          title: 'Datos de sucursales',
          description: 'Sucursales asociadas a la empresa.',
        ),
        const SizedBox(height: 18),
        if (_sucursales.isEmpty)
          const _EmptyBranches()
        else
          ..._sucursales.map((sucursal) => _SucursalViewCard(sucursal: sucursal, labelFor: _labelFor)),
      ],
    );
  }

  String _value(String field) {
    final value = _empresa[field]?.toString().trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  String _estadoLabel(Object? value) {
    final text = value?.toString() ?? '';
    if (text == '1') return 'Activo';
    if (text == '0') return 'Inactivo';
    return text.isEmpty ? '-' : text;
  }

  String _labelFor(String fieldName, Object? id) {
    final text = id?.toString() ?? '';
    if (text.isEmpty) return '-';

    for (final option in _lookupOptions[fieldName] ?? const <CrudLookupOption>[]) {
      if (option.id?.toString() == text) return option.label;
    }

    return '-';
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.secondary.withOpacity(0.16), palette.surface.withOpacity(0.96)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.business_rounded, color: palette.onPrimary, size: 30)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: palette.textPrimary)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary))]),
          ),
        ],
      ),
    );
  }
}

class _ViewTabs extends ConsumerWidget {
  const _ViewTabs({required this.currentTab, required this.onTabTap});

  final int currentTab;
  final ValueChanged<int> onTabTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tabs = [(icon: Icons.business_rounded, title: 'Datos de empresa', subtitle: 'Información principal'), (icon: Icons.storefront_rounded, title: 'Datos sucursales', subtitle: 'Sedes asociadas')];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final selected = currentTab == index;
            final width = compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
            return SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onTabTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: selected ? palette.secondary.withOpacity(0.12) : palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.65), borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? palette.secondary : palette.cardBorder, width: selected ? 1.4 : 1)),
                  child: Row(
                    children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(gradient: selected ? LinearGradient(colors: [palette.primary, palette.secondary]) : null, color: selected ? null : palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: Icon(tab.icon, color: selected ? palette.onPrimary : palette.secondary)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tab.title, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)), const SizedBox(height: 2), Text(tab.subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textSecondary))])),
                      Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: selected ? palette.secondary : palette.textSecondary),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: palette.secondary)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: palette.textPrimary)), const SizedBox(height: 2), Text(description, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary))]))]);
  }
}

class _InfoTile extends ConsumerWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
      child: Row(children: [Icon(icon, color: palette.secondary, size: 22), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textSecondary)), const SizedBox(height: 4), Text(value.isEmpty ? '-' : value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: palette.textPrimary))]))]),
    );
  }
}

class _SucursalViewCard extends ConsumerWidget {
  const _SucursalViewCard({required this.sucursal, required this.labelFor});

  final Map<String, dynamic> sucursal;
  final String Function(String fieldName, Object? id) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final nombre = sucursal['sucuNombre']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.storefront_rounded, color: palette.secondary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nombre.isEmpty ? 'Sucursal' : nombre, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary)), const SizedBox(height: 2), Text(sucursal['sucuCodigoInterno']?.toString() ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary))]))]),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [_MiniInfo(label: 'Ciudad', value: labelFor('ciudId', sucursal['ciudId'])), _MiniInfo(label: 'Zona horaria', value: labelFor('zohoId', sucursal['zohoId'])), _MiniInfo(label: 'Moneda', value: labelFor('moneId', sucursal['moneId'])), _MiniInfo(label: 'País teléfono', value: labelFor('paisIdtelefono', sucursal['paisIdtelefono'])), _MiniInfo(label: 'Dirección', value: sucursal['sucuDireccion']?.toString() ?? '-'), _MiniInfo(label: 'Teléfono', value: sucursal['sucuTelefono']?.toString() ?? '-'), _MiniInfo(label: 'Estado', value: sucursal['sucuEstado']?.toString() == '1' ? 'Activo' : (sucursal['sucuEstado']?.toString() ?? '-'))]),
        ],
      ),
    );
  }
}

class _MiniInfo extends ConsumerWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.92), borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary)), const SizedBox(height: 4), Text(value.isEmpty ? '-' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: palette.textPrimary))]),
    );
  }
}

class _EmptyBranches extends ConsumerWidget {
  const _EmptyBranches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68), borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.cardBorder)),
      child: Text('Esta empresa no tiene sucursales registradas.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
    );
  }
}
