import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/crud/crud_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';

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
                            'Visualizar empresa',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/empresas'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Atrás'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _safeGo('/empresas/${widget.id}/editar'),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Modificar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Header(
                      title: _value('empreNombreComercial').isEmpty ? 'Empresa' : _value('empreNombreComercial'),
                      subtitle: _value('emprRazonSocial').isEmpty ? 'Detalle de empresa y sucursales' : _value('emprRazonSocial'),
                    ),
                    const SizedBox(height: 20),
                    _ViewTabs(
                      currentTab: _tab,
                      onTabTap: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _tab == 0 ? _empresaTab() : _sucursalesTab(),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('Esta empresa no tiene sucursales registradas.'),
          )
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

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.14), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.business_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.currentTab, required this.onTabTap});

  final int currentTab;
  final ValueChanged<int> onTabTap;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (icon: Icons.business_rounded, title: 'Datos de empresa', subtitle: 'Información principal'),
      (icon: Icons.storefront_rounded, title: 'Datos sucursales', subtitle: 'Sedes asociadas'),
    ];

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
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.4 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(tab.icon, color: selected ? Colors.white : AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tab.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(tab.subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: selected ? AppColors.primary : AppColors.textSecondary),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SucursalViewCard extends StatelessWidget {
  const _SucursalViewCard({required this.sucursal, required this.labelFor});

  final Map<String, dynamic> sucursal;
  final String Function(String fieldName, Object? id) labelFor;

  @override
  Widget build(BuildContext context) {
    final nombre = sucursal['sucuNombre']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre.isEmpty ? 'Sucursal' : nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(sucursal['sucuCodigoInterno']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniInfo(label: 'Ciudad', value: labelFor('ciudId', sucursal['ciudId'])),
              _MiniInfo(label: 'Zona horaria', value: labelFor('zohoId', sucursal['zohoId'])),
              _MiniInfo(label: 'Moneda', value: labelFor('moneId', sucursal['moneId'])),
              _MiniInfo(label: 'País teléfono', value: labelFor('paisIdtelefono', sucursal['paisIdtelefono'])),
              _MiniInfo(label: 'Dirección', value: sucursal['sucuDireccion']?.toString() ?? '-'),
              _MiniInfo(label: 'Teléfono', value: sucursal['sucuTelefono']?.toString() ?? '-'),
              _MiniInfo(label: 'Estado', value: sucursal['sucuEstado']?.toString() == '1' ? 'Activo' : (sucursal['sucuEstado']?.toString() ?? '-')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
