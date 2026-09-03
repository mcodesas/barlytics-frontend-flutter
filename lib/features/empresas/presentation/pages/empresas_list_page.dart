import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/empresas_response_model.dart';

/// Administración de empresas adaptada al alcance del usuario autenticado.
///
/// - ADMIN: administra el catálogo completo.
/// - GERENTE con empresa: consulta y modifica únicamente su empresa.
/// - GERENTE sin empresa: recibe un onboarding para crear una sola empresa.
class EmpresasListPage extends ConsumerStatefulWidget {
  const EmpresasListPage({super.key});

  @override
  ConsumerState<EmpresasListPage> createState() => _EmpresasListPageState();
}

class _EmpresasListPageState extends ConsumerState<EmpresasListPage> {
  final TextEditingController _searchController = TextEditingController();

  List<EmpresasResponseModel> _empresas = const <EmpresasResponseModel>[];
  Map<int, String> _tiposIdentificacion = const <int, String>{};
  Map<int, Map<String, dynamic>> _ciudades = const <int, Map<String, dynamic>>{};
  Map<int, Map<String, dynamic>> _regiones = const <int, Map<String, dynamic>>{};
  Map<int, String> _paises = const <int, String>{};

  bool _loading = true;
  bool _isManager = false;
  int? _managerEmpresaId;
  int _branchCount = 0;
  int _activeBranchCount = 0;
  int _userCount = 0;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final roles = ref.read(authControllerProvider).roles;
      final manager = _isManagerRole(roles);
      int? managerEmpresaId;

      if (manager) {
        final profile = await apiClient.get<Map<String, dynamic>>(
          ApiPaths.profile,
          (json) => Map<String, dynamic>.from(json as Map),
        );
        managerEmpresaId = (profile.data?['empresaId'] as num?)?.toInt();
      }

      final results = await Future.wait<Object>([
        apiClient.get<List<EmpresasResponseModel>>(
          ApiPaths.empresas,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => EmpresasResponseModel.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false),
        ),
        apiClient.get<Map<int, String>>(
          ApiPaths.tiposidentificacion,
          (json) => _toLabelMap(json, 'tiidId', const ['tiidNombre', 'tiidDescripcion']),
        ),
        apiClient.get<Map<int, Map<String, dynamic>>>(
          ApiPaths.ciudades,
          (json) => _toRawMap(json, 'ciudId'),
        ),
        apiClient.get<Map<int, Map<String, dynamic>>>(
          ApiPaths.regiones,
          (json) => _toRawMap(json, 'regiId'),
        ),
        apiClient.get<Map<int, String>>(
          ApiPaths.paises,
          (json) => _toLabelMap(json, 'paisId', const ['paisNombre', 'paisCodigo']),
        ),
      ]);

      final companies = (results[0] as dynamic).data as List<EmpresasResponseModel>? ?? const <EmpresasResponseModel>[];
      var branchCount = 0;
      var activeBranchCount = 0;
      var userCount = 0;

      if (manager && managerEmpresaId != null) {
        try {
          final operational = await Future.wait<Object>([
            apiClient.get<List<Map<String, dynamic>>>(
              '${ApiPaths.sucursales}/empresa/$managerEmpresaId',
              (json) => (json as List? ?? const <Object?>[])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false),
            ),
            apiClient.get<List<Map<String, dynamic>>>(
              ApiPaths.usuarios,
              (json) => (json as List? ?? const <Object?>[])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false),
            ),
          ]);
          final branches = (operational[0] as dynamic).data as List<Map<String, dynamic>>? ?? const <Map<String, dynamic>>[];
          final users = (operational[1] as dynamic).data as List<Map<String, dynamic>>? ?? const <Map<String, dynamic>>[];
          branchCount = branches.length;
          activeBranchCount = branches.where((branch) => (branch['sucuEstado'] as num?)?.toInt() != 0).length;
          userCount = users.length;
        } catch (_) {
          // Los contadores son información complementaria. La ficha principal
          // debe continuar disponible aunque uno de estos módulos no tenga permiso.
        }
      }

      if (!mounted) return;
      setState(() {
        _isManager = manager;
        _managerEmpresaId = managerEmpresaId;
        _empresas = companies;
        _tiposIdentificacion = (results[1] as dynamic).data as Map<int, String>? ?? const <int, String>{};
        _ciudades = (results[2] as dynamic).data as Map<int, Map<String, dynamic>>? ?? const <int, Map<String, dynamic>>{};
        _regiones = (results[3] as dynamic).data as Map<int, Map<String, dynamic>>? ?? const <int, Map<String, dynamic>>{};
        _paises = (results[4] as dynamic).data as Map<int, String>? ?? const <int, String>{};
        _branchCount = branchCount;
        _activeBranchCount = activeBranchCount;
        _userCount = userCount;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isManagerRole(List<String> roles) {
    final normalized = roles.map(_normalizeRole).toSet();
    const admins = {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN'};
    if (normalized.any(admins.contains)) return false;
    return normalized.contains('GERENTE') || normalized.contains('MANAGER');
  }

  String _normalizeRole(String value) {
    var normalized = value.trim().toUpperCase();
    if (normalized.startsWith('ROLE_')) normalized = normalized.substring(5);
    return normalized;
  }

  static Map<int, String> _toLabelMap(Object? json, String idField, List<String> displayFields) {
    final result = <int, String>{};
    final items = json is List ? json : const <Object?>[];
    for (final item in items.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(item);
      final id = (raw[idField] as num?)?.toInt();
      if (id == null) continue;
      final parts = displayFields
          .map((field) => raw[field]?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      result[id] = parts.isEmpty ? '-' : parts.join(' · ');
    }
    return result;
  }

  static Map<int, Map<String, dynamic>> _toRawMap(Object? json, String idField) {
    final result = <int, Map<String, dynamic>>{};
    final items = json is List ? json : const <Object?>[];
    for (final item in items.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(item);
      final id = (raw[idField] as num?)?.toInt();
      if (id != null) result[id] = raw;
    }
    return result;
  }

  List<EmpresasResponseModel> get _filteredEmpresas {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _empresas;
    return _empresas.where((empresa) {
      return [
        empresa.empreNombreComercial,
        empresa.emprRazonSocial,
        empresa.emprIdentificacion,
        empresa.emprCorreoElectronico,
        empresa.emprTelefono,
        _paisCiudad(empresa),
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  EmpresasResponseModel? get _managerCompany {
    if (_managerEmpresaId == null) return null;
    for (final company in _empresas) {
      if (company.emprId == _managerEmpresaId) return company;
    }
    return null;
  }

  bool get _canCreateCompany => !_isManager || (_managerEmpresaId == null && _empresas.isEmpty);

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !_loading && _error == null && _canCreateCompany
          ? FloatingActionButton.extended(
              heroTag: 'empresas-create-fab',
              backgroundColor: palette.actionColor,
              foregroundColor: palette.onAction,
              onPressed: () => _safeGo('/empresas/nuevo'),
              icon: const Icon(Icons.add_business_rounded),
              label: Text(_isManager ? 'Crear mi empresa' : 'Nueva empresa'),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          if (_loading)
            const Positioned.fill(child: AppLoader())
          else
            RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: _error != null
                          ? _errorState(palette)
                          : _isManager
                              ? _managerContent(palette)
                              : _adminContent(palette),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _managerContent(AppPalette palette) {
    if (_managerEmpresaId == null) {
      return _managerOnboarding(palette);
    }
    final company = _managerCompany;
    if (company == null) {
      return _assignedCompanyUnavailable(palette);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _managerHero(company, palette),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final metrics = [
              _MetricData(Icons.storefront_rounded, 'Sucursales', '$_activeBranchCount', _branchCount == _activeBranchCount ? 'activas' : 'de $_branchCount registradas'),
              _MetricData(Icons.groups_rounded, 'Usuarios', '$_userCount', 'en tu empresa'),
              _MetricData(Icons.verified_rounded, 'Estado', company.emprEstado == 0 ? 'Inactiva' : 'Activa', 'operación empresarial'),
            ];
            if (compact) {
              return Column(children: metrics.map((metric) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _metricCard(metric, palette))).toList());
            }
            return Row(
              children: metrics
                  .map((metric) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: _metricCard(metric, palette))))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 820;
            final left = _infoSection(
              title: 'Identidad legal',
              icon: Icons.badge_rounded,
              palette: palette,
              items: [
                _InfoData('Razón social', _text(company.emprRazonSocial)),
                _InfoData('Tipo de identificación', _tipoIdentificacion(company.tiidId)),
                _InfoData('Identificación', _text(company.emprIdentificacion)),
                _InfoData('Estado', company.emprEstado == 0 ? 'Inactiva' : 'Activa'),
              ],
            );
            final right = _infoSection(
              title: 'Contacto y ubicación',
              icon: Icons.contact_mail_rounded,
              palette: palette,
              items: [
                _InfoData('Ubicación', _paisCiudad(company)),
                _InfoData('Dirección', _text(company.emprDireccion)),
                _InfoData('Teléfono', _text(company.emprTelefono)),
                _InfoData('Correo', _text(company.emprCorreoElectronico)),
                _InfoData('Sitio web', _text(company.emprSitioWeb)),
              ],
            );
            if (!twoColumns) return Column(children: [left, const SizedBox(height: 12), right]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
          },
        ),
        const SizedBox(height: 14),
        _managerNotice(palette),
      ],
    );
  }


  Widget _assignedCompanyUnavailable(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _panelDecoration(palette, radius: 28),
      child: Column(
        children: [
          const Icon(Icons.business_rounded, size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          Text('La empresa asignada no está disponible', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Tu usuario ya tiene una empresa asignada, pero no fue posible consultarla. No se habilita la creación de otra empresa. Revisa su estado con un administrador global.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded), label: const Text('Actualizar')),
        ],
      ),
    );
  }

  Widget _managerOnboarding(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(palette, radius: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.add_business_rounded, color: palette.onPrimary, size: 32),
              ),
              const SizedBox(height: 18),
              Text('Configura tu empresa', style: TextStyle(color: palette.textPrimary, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Tu usuario GERENTE todavía no tiene una empresa. Puedes crear una sola y quedará vinculada automáticamente a tu cuenta.',
                style: TextStyle(color: palette.textSecondary, height: 1.45, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _safeGo('/empresas/nuevo'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Configurar empresa'),
              ),
            ],
          );
          final steps = Column(
            children: const [
              _OnboardingStep(number: '1', title: 'Identidad', description: 'Nombre comercial, razón social e identificación.'),
              _OnboardingStep(number: '2', title: 'Ubicación', description: 'Ciudad, dirección, zona horaria y contacto.'),
              _OnboardingStep(number: '3', title: 'Operación', description: 'Registra las sucursales con las que iniciarás.'),
            ],
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [intro, const SizedBox(height: 28), steps]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 5, child: intro), const SizedBox(width: 38), Expanded(flex: 4, child: steps)]);
        },
      ),
    );
  }

  Widget _managerHero(EmpresasResponseModel company, AppPalette palette) {
    final id = company.emprId;
    final active = company.emprEstado != 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(palette, radius: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final identity = Row(
            children: [
              _companyAvatar(company, palette, size: 62),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _text(company.empreNombreComercial),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(company.emprEstado, palette),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_text(company.emprRazonSocial), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text(
                      active ? 'Empresa configurada y disponible para operar.' : 'La empresa se encuentra inactiva.',
                      style: TextStyle(color: active ? AppColors.success : AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              FilledButton.icon(onPressed: id == null ? null : () => _safeGo('/empresas/$id/editar'), icon: const Icon(Icons.edit_rounded, size: 17), label: const Text('Modificar')),
              OutlinedButton.icon(onPressed: () => _safeGo('/sucursales'), icon: const Icon(Icons.storefront_rounded, size: 17), label: const Text('Sucursales')),
              OutlinedButton.icon(onPressed: () => _safeGo('/usuarios'), icon: const Icon(Icons.people_alt_rounded, size: 17), label: const Text('Usuarios')),
              IconButton.filledTonal(onPressed: id == null ? null : () => _safeGo('/empresas/$id'), tooltip: 'Ver ficha completa', icon: const Icon(Icons.visibility_rounded, size: 19)),
            ],
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), actions]);
          return Row(children: [Expanded(child: identity), const SizedBox(width: 16), actions]);
        },
      ),
    );
  }

  Widget _heroButton(IconData icon, String label, VoidCallback onPressed, AppPalette palette) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.onPrimary,
        backgroundColor: palette.onPrimary.withOpacity(0.10),
        side: BorderSide(color: palette.onPrimary.withOpacity(0.30)),
      ),
    );
  }

  Widget _metricCard(_MetricData metric, AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: _panelDecoration(palette, radius: 17),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(metric.icon, color: palette.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                Text(metric.value, style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                Text(metric.caption, style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection({required String title, required IconData icon, required AppPalette palette, required List<_InfoData> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(palette, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Icon(icon, color: palette.secondary), const SizedBox(width: 9), Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5))]),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 126, child: Text(item.label, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _managerNotice(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.secondary.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_rounded, color: palette.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Como GERENTE administras únicamente esta empresa. Puedes modificarla y gestionar sus sucursales, usuarios y parámetros, pero no crear una segunda empresa ni eliminar la actual.',
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminContent(AppPalette palette) {
    final companies = _filteredEmpresas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _adminToolbar(companies.length, palette),
        const SizedBox(height: 14),
        if (companies.isEmpty)
          _emptyAdminState(palette)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
              final spacing = 12.0;
              final cardWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: companies.map((company) => SizedBox(width: cardWidth, child: _adminCompanyCard(company, palette))).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _adminToolbar(int visible, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(palette, radius: 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.corporate_fare_rounded, color: palette.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Administración de empresas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('$visible de ${_empresas.length} empresas visibles', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: _loadData, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded)),
            ],
          );
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Buscar empresa, NIT, ciudad o contacto',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 14), search]);
          return Row(children: [Expanded(flex: 5, child: title), const SizedBox(width: 16), Expanded(flex: 4, child: search)]);
        },
      ),
    );
  }

  Widget _adminCompanyCard(EmpresasResponseModel company, AppPalette palette) {
    final id = company.emprId;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panelDecoration(palette, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _companyAvatar(company, palette, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_text(company.empreNombreComercial), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(_text(company.emprRazonSocial), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              _statusBadge(company.emprEstado, palette),
            ],
          ),
          const SizedBox(height: 16),
          _compactInfo(Icons.badge_outlined, '${_tipoIdentificacion(company.tiidId)} · ${_text(company.emprIdentificacion)}', palette),
          _compactInfo(Icons.location_on_outlined, _paisCiudad(company), palette),
          _compactInfo(Icons.phone_outlined, _text(company.emprTelefono), palette),
          _compactInfo(Icons.email_outlined, _text(company.emprCorreoElectronico), palette),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(onPressed: id == null ? null : () => _safeGo('/empresas/$id'), icon: const Icon(Icons.visibility_rounded, size: 17), label: const Text('Ver')),
              FilledButton.tonalIcon(onPressed: id == null ? null : () => _safeGo('/empresas/$id/editar'), icon: const Icon(Icons.edit_rounded, size: 17), label: const Text('Modificar')),
              IconButton.filledTonal(
                onPressed: id == null ? null : () => _confirmDelete(company),
                tooltip: 'Inactivar empresa',
                style: IconButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _companyAvatar(EmpresasResponseModel company, AppPalette palette, {required double size}) {
    final logo = company.emprLogo?.trim();
    final initial = (company.empreNombreComercial?.trim().isNotEmpty ?? false) ? company.empreNombreComercial!.trim()[0].toUpperCase() : 'E';
    final image = _decodeLogo(logo);
    final fallback = Center(child: Text(initial, style: TextStyle(color: palette.primary, fontSize: size * 0.38, fontWeight: FontWeight.w900)));
    Widget content = fallback;
    if (image != null) {
      content = Image.memory(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
    } else {
      final uri = Uri.tryParse(logo ?? '');
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        content = Image.network(logo!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
      }
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: palette.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(size * 0.30), border: Border.all(color: palette.secondary.withOpacity(0.16))),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.24), child: content),
    );
  }

  Uint8List? _decodeLogo(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final raw = value.contains(',') ? value.substring(value.indexOf(',') + 1) : value;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Widget _statusBadge(int? status, AppPalette palette) {
    final active = status != 0;
    final color = active ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.24))),
      child: Text(active ? 'Activa' : 'Inactiva', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }

  Widget _compactInfo(IconData icon, String value, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Icon(icon, size: 18, color: palette.textSecondary), const SizedBox(width: 8), Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)))]),
    );
  }

  Widget _emptyAdminState(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _panelDecoration(palette, radius: 26),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text('No hay empresas para mostrar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 5),
          Text('Ajusta la búsqueda o registra una nueva empresa.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _errorState(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _panelDecoration(palette, radius: 26),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          Text('No fue posible cargar las empresas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(AppPalette palette, {required double radius}) {
    return BoxDecoration(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: palette.cardBorder),
      boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
    );
  }

  Future<void> _confirmDelete(EmpresasResponseModel company) async {
    if (_isManager || company.emprId == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar empresa'),
        content: Text('¿Deseas inactivar ${_text(company.empreNombreComercial)}? Esta acción puede afectar el acceso de sus usuarios.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Inactivar')),
        ],
      ),
    );
    if (accepted != true) return;
    await ref.read(apiClientProvider).delete<void>('${ApiPaths.empresas}/${company.emprId}', (_) {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa inactivada correctamente')));
    await _loadData();
  }

  void _safeGo(String location) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  String _tipoIdentificacion(int? id) => id == null ? '-' : (_tiposIdentificacion[id] ?? '-');

  String _paisCiudad(EmpresasResponseModel company) {
    final city = _ciudades[company.ciudId];
    final cityName = city?['ciudNombre']?.toString().trim() ?? '';
    final regionId = (city?['regiId'] as num?)?.toInt();
    final countryId = (_regiones[regionId]?['paisId'] as num?)?.toInt();
    final countryName = _paises[countryId] ?? '';
    if (countryName.isNotEmpty && cityName.isNotEmpty) return '$countryName · $cityName';
    if (cityName.isNotEmpty) return cityName;
    return _paises[company.paisIdtelefono] ?? '-';
  }

  String _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value, this.caption);
  final IconData icon;
  final String label;
  final String value;
  final String caption;
}

class _InfoData {
  const _InfoData(this.label, this.value);
  final String label;
  final String value;
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({required this.number, required this.title, required this.description});
  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(13)),
            child: Text(number, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(description, style: theme.textTheme.bodySmall?.copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
