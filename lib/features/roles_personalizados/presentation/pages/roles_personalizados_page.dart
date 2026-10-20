import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../empresas/data/models/empresas_response_model.dart';
import '../../../business_setup/presentation/providers/business_setup_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';
import '../../data/models/rol_personalizado_model.dart';

enum _RoleStatusFilter { todos, activos, inactivos }

class RolesPersonalizadosPage extends ConsumerStatefulWidget {
  const RolesPersonalizadosPage({super.key});

  @override
  ConsumerState<RolesPersonalizadosPage> createState() => _RolesPersonalizadosPageState();
}

class _RolesPersonalizadosPageState extends ConsumerState<RolesPersonalizadosPage> {
  final TextEditingController _search = TextEditingController();
  List<RolPersonalizadoModel> _roles = const [];
  List<MenuAsignableModel> _menus = const [];
  List<RolPlantillaModel> _templates = const [];
  String? _templatesError;
  List<EmpresasResponseModel> _companies = const [];
  List<SucursalesResponseModel> _branches = const [];
  _RoleStatusFilter _status = _RoleStatusFilter.todos;
  int? _companyFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      _templatesError = null;
      final api = ref.read(apiClientProvider);
      final rolesFuture = api.get<List<RolPersonalizadoModel>>(
        ApiPaths.rolesPersonalizados,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => RolPersonalizadoModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      final menusFuture = api.get<List<MenuAsignableModel>>(
        ApiPaths.rolesPersonalizadosOpciones,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => MenuAsignableModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      final companiesFuture = api.get<List<EmpresasResponseModel>>(
        ApiPaths.empresas,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => EmpresasResponseModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      final branchesFuture = api.get<List<SucursalesResponseModel>>(
        ApiPaths.sucursales,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => SucursalesResponseModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
      final rolesResponse = await rolesFuture;
      final menusResponse = await menusFuture;
      final companiesResponse = await companiesFuture;
      final branchesResponse = await branchesFuture;
      List<RolPlantillaModel> templates = const [];
      try {
        final response = await api.get<List<RolPlantillaModel>>(
          ApiPaths.rolesPersonalizadosPlantillas,
          (json) => (json as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((item) => RolPlantillaModel.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false),
        );
        templates = response.data ?? const [];
      } catch (error) {
        // La lista de roles sigue disponible aunque el backend TEST todavía
        // no tenga desplegado el nuevo endpoint de plantillas.
        _templatesError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        _roles = rolesResponse.data ?? const [];
        _menus = menusResponse.data ?? const [];
        _templates = templates;
        _companies = companiesResponse.data ?? const [];
        _branches = branchesResponse.data ?? const [];
        if (_companies.length == 1) _companyFilter = _companies.first.emprId;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RolPersonalizadoModel> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _roles.where((role) {
      if (_status == _RoleStatusFilter.activos && !role.active) return false;
      if (_status == _RoleStatusFilter.inactivos && role.active) return false;
      if (_companyFilter != null && role.emprId != _companyFilter) return false;
      if (query.isEmpty) return true;
      final text = [
        role.roleNombre,
        role.roleDescripcion,
        _companyName(role.emprId),
        _branchName(role.sucuId),
        ...role.menus.map((item) => item.nombre),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList()
      ..sort((a, b) {
        final active = (b.active ? 1 : 0).compareTo(a.active ? 1 : 0);
        return active != 0 ? active : a.roleNombre.toLowerCase().compareTo(b.roleNombre.toLowerCase());
      });
  }

  String _companyName(int id) {
    for (final company in _companies) {
      if (company.emprId == id) {
        final name = company.empreNombreComercial?.trim();
        if (name != null && name.isNotEmpty) return name;
        return company.emprRazonSocial?.trim().isNotEmpty == true
            ? company.emprRazonSocial!.trim()
            : 'Empresa #$id';
      }
    }
    return 'Empresa #$id';
  }

  String _branchName(int? id) {
    if (id == null) return 'Toda la empresa';
    for (final branch in _branches) {
      if (branch.sucuId == id) return branch.label();
    }
    return 'Sucursal #$id';
  }

  Future<void> _openForm([RolPersonalizadoModel? role, RolPlantillaModel? template]) async {
    // Consultar el estado más reciente antes de editar o crear. El usuario
    // puede haber cambiado permisos desde otro dispositivo o sesión.
    RolPersonalizadoModel? currentRole = role;
    List<MenuAsignableModel> currentMenus;
    try {
      final api = ref.read(apiClientProvider);
      final available = await api.get<List<MenuAsignableModel>>(
        ApiPaths.rolesPersonalizadosOpciones,
        (json) => (json as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((item) => MenuAsignableModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
      currentMenus = available.data ?? const <MenuAsignableModel>[];
      if (role != null) {
        final detail = await api.get<RolPersonalizadoModel>(
          '${ApiPaths.rolesPersonalizados}/${role.roleId}',
          (json) => RolPersonalizadoModel.fromJson(Map<String, dynamic>.from(json as Map)),
        );
        if (detail.data == null) throw StateError('El rol no existe o no está disponible.');
        currentRole = detail.data;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible actualizar los permisos desde la base de datos: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una empresa disponible para crear el rol.')),
      );
      return;
    }
    if (currentMenus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu usuario no tiene opciones de menú que pueda delegar.')),
      );
      return;
    }
    final palette = ref.read(selectedAppPaletteProvider);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        final media = MediaQuery.of(context);
        final availableHeight = math.max(
          320.0,
          media.size.height - media.padding.top - media.viewInsets.bottom,
        ).toDouble();
        final height = math.min(
          availableHeight,
          math.max(560.0, availableHeight * 0.94),
        ).toDouble();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: math.min(media.size.width, 1180.0).toDouble(),
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 28,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: _RolPersonalizadoFormSheet(
                role: role,
                template: template,
                templates: _templates,
                menus: _menus,
                companies: _companies,
                    branches: _branches,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(role == null ? 'Rol personalizado creado correctamente' : 'Rol personalizado actualizado correctamente')),
      );
    }
  }

  Future<void> _confirmPredefinedRoles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Usar roles estándar'),
        content: const Text(
          'Puedes empezar con los permisos estándar de Cajero, Mesero, Inventario y Gerente. '
          'No se modifican permisos globales ni los de otras empresas. '
          'Podrás crear perfiles propios más adelante.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).post<Object?>(
        ApiPaths.businessSetupRolesDefaults,
        <String, dynamic>{},
        (json) => json,
      );
      ref.invalidate(businessSetupStatusProvider);
      await ref.read(authControllerProvider.notifier).refreshBusinessSetup();
      if (!mounted) return;
      context.go('/configurar-negocio');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible confirmar los roles estándar: $error')),
        );
      }
    }
  }

  Future<void> _inactivate(RolPersonalizadoModel role) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Inactivar rol personalizado',
      message: 'El rol “${role.roleNombre}” dejará de entregar opciones de menú a los usuarios que lo tengan asignado.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete<Object?>(
            '${ApiPaths.rolesPersonalizados}/${role.roleId}',
            (_) => null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol inactivado correctamente')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible inactivar el rol: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final visible = _filtered;
    final active = _roles.where((item) => item.active).length;
    final branchRoles = _roles.where((item) => !item.companyWide).length;
    final assigned = _roles.fold<int>(0, (sum, item) => sum + item.usuariosAsignados);
    final guidedMode = ref.watch(businessSetupGuidedModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'roles-personalizados-fab',
        onPressed: _loading || _companies.isEmpty || _menus.isEmpty ? null : () => _openForm(),
        backgroundColor: palette.actionColor,
        foregroundColor: palette.onAction,
        icon: const Icon(Icons.add_moderator_rounded),
        label: const Text('Nuevo rol'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Header(palette: palette, total: _roles.length, onRefresh: _load),
                      ),
                    ),
                  ),
                ),
                if (guidedMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _RolesSetupGuide(
                            palette: palette,
                            currentRoles: _roles.where((role) => role.active).length,
                            busy: _loading,
                            onDefaults: _confirmPredefinedRoles,
                            templates: _templates,
                            templatesError: _templatesError,
                            onTemplate: (template) => _openForm(null, template),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Metrics(
                          palette: palette,
                          total: _roles.length,
                          active: active,
                          branchRoles: branchRoles,
                          assigned: assigned,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Filters(
                          palette: palette,
                          search: _search,
                          status: _status,
                          companyId: _companyFilter,
                          companies: _companies,
                          onChanged: () => setState(() {}),
                          onStatus: (value) => setState(() => _status = value),
                          onCompany: (value) => setState(() => _companyFilter = value),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(hasScrollBody: false, child: AppLoader(message: 'Cargando roles personalizados...'))
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MessageState(
                      palette: palette,
                      icon: Icons.warning_amber_rounded,
                      title: 'No fue posible cargar los roles',
                      message: _error!,
                      action: _load,
                    ),
                  )
                else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MessageState(
                      palette: palette,
                      icon: Icons.admin_panel_settings_outlined,
                      title: _roles.isEmpty ? 'Aún no existen roles personalizados' : 'No hay resultados con estos filtros',
                      message: _roles.isEmpty
                          ? 'Crea el primer rol y elige exactamente qué opciones de menú podrá utilizar.'
                          : 'Cambia los filtros o limpia la búsqueda.',
                      action: _roles.isEmpty && _companies.isNotEmpty && _menus.isNotEmpty ? () => _openForm() : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
                              final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final role in visible)
                                    SizedBox(
                                      width: width,
                                      child: _RoleCard(
                                        palette: palette,
                                        role: role,
                                        company: _companyName(role.emprId),
                                        branch: _branchName(role.sucuId),
                                        onEdit: () => _openForm(role),
                                        onDelete: role.active ? () => _inactivate(role) : null,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guía inicial: cada perfil es propio de la empresa y nunca modifica roles globales.
class _RolesSetupGuide extends StatelessWidget {
  const _RolesSetupGuide({
    required this.palette,
    required this.currentRoles,
    required this.busy,
    required this.onDefaults,
    required this.templates,
    required this.templatesError,
    required this.onTemplate,
  });

  final AppPalette palette;
  final int currentRoles;
  final bool busy;
  final VoidCallback onDefaults;
  final List<RolPlantillaModel> templates;
  final String? templatesError;
  final ValueChanged<RolPlantillaModel> onTemplate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: palette.panelDecoration(baseRadius: 20, tint: palette.secondary),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Define las funciones de tu equipo desde el principio',
          style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text('Paso 6 · Los roles estándar ya incluyen funciones asignadas. '
          'Para permisos distintos usa «Nuevo rol» y selecciona los menús necesarios.',
          style: TextStyle(color: palette.textSecondary, height: 1.45)),
        const SizedBox(height: 12),
        Text('Perfiles personalizados activos: $currentRoles.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        if (templates.isNotEmpty) ...[
          Text('Partir de un rol registrado en la base de datos:',
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final template in templates)
                ActionChip(
                  avatar: const Icon(Icons.badge_outlined, size: 17),
                  label: Text(template.nombre),
                  onPressed: busy ? null : () => onTemplate(template),
                ),
            ],
          ),
        ] else
          Text(
            templatesError == null
                ? 'No hay perfiles predefinidos con opciones delegables en la base de datos.'
                : 'No fue posible consultar las plantillas desde el backend.',
            style: TextStyle(color: palette.textSecondary),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: busy ? null : onDefaults,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Prefiero utilizar los roles estándar sin personalizarlos'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.total, required this.onRefresh});
  final AppPalette palette;
  final int total;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 28, tint: palette.secondary),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: palette.onPrimary, size: 29),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Roles personalizados', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  'Crea perfiles propios de la empresa y decide qué módulos puede utilizar cada uno.',
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Chip(label: Text('$total roles')),
          IconButton.filledTonal(onPressed: onRefresh, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.palette, required this.total, required this.active, required this.branchRoles, required this.assigned});
  final AppPalette palette;
  final int total;
  final int active;
  final int branchRoles;
  final int assigned;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Total', total, Icons.shield_outlined),
      ('Activos', active, Icons.verified_user_outlined),
      ('Por sucursal', branchRoles, Icons.store_outlined),
      ('Asignaciones', assigned, Icons.group_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              Container(
                width: width,
                padding: const EdgeInsets.all(14),
                decoration: palette.panelDecoration(baseRadius: 20),
                child: Row(
                  children: [
                    Icon(metric.$3, color: palette.secondary),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${metric.$2}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                        Text(metric.$1, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.palette,
    required this.search,
    required this.status,
    required this.companyId,
    required this.companies,
    required this.onChanged,
    required this.onStatus,
    required this.onCompany,
  });
  final AppPalette palette;
  final TextEditingController search;
  final _RoleStatusFilter status;
  final int? companyId;
  final List<EmpresasResponseModel> companies;
  final VoidCallback onChanged;
  final ValueChanged<_RoleStatusFilter> onStatus;
  final ValueChanged<int?> onCompany;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: palette.panelDecoration(baseRadius: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: search,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar rol, permiso o sucursal',
              border: OutlineInputBorder(),
            ),
          );
          final statusField = DropdownButtonFormField<_RoleStatusFilter>(
            value: status,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: _RoleStatusFilter.todos, child: Text('Todos')),
              DropdownMenuItem(value: _RoleStatusFilter.activos, child: Text('Activos')),
              DropdownMenuItem(value: _RoleStatusFilter.inactivos, child: Text('Inactivos')),
            ],
            onChanged: (value) => value == null ? null : onStatus(value),
          );
          final companyField = DropdownButtonFormField<int?>(
            value: companyId,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Empresa', border: OutlineInputBorder()),
            items: [
              if (companies.length > 1) const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
              for (final company in companies)
                DropdownMenuItem<int?>(
                  value: company.emprId,
                  child: Text(company.empreNombreComercial ?? company.emprRazonSocial ?? 'Empresa #${company.emprId}'),
                ),
            ],
            onChanged: companies.length <= 1 ? null : onCompany,
          );
          if (constraints.maxWidth < 720) {
            return Column(children: [searchField, const SizedBox(height: 10), Row(children: [Expanded(child: statusField), const SizedBox(width: 10), Expanded(child: companyField)])]);
          }
          return Row(children: [Expanded(flex: 3, child: searchField), const SizedBox(width: 10), Expanded(child: statusField), const SizedBox(width: 10), Expanded(flex: 2, child: companyField)]);
        },
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.palette, required this.role, required this.company, required this.branch, required this.onEdit, this.onDelete});
  final AppPalette palette;
  final RolPersonalizadoModel role;
  final String company;
  final String branch;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 24, tint: role.active ? palette.secondary : palette.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                child: Icon(role.companyWide ? Icons.corporate_fare_rounded : Icons.store_rounded, color: palette.secondary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.roleNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(role.active ? 'Activo' : 'Inactivo', style: TextStyle(color: role.active ? palette.success : palette.warning, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete?.call(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Modificar'))),
                  if (onDelete != null) const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Inactivar'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(role.roleDescripcion, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 13),
          _InfoLine(icon: Icons.business_rounded, text: company, palette: palette),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.location_on_outlined, text: branch, palette: palette),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(avatar: const Icon(Icons.apps_rounded, size: 17), label: Text('${role.menuIds.length} opciones')),
              Chip(avatar: const Icon(Icons.group_outlined, size: 17), label: Text('${role.usuariosAsignados} usuarios')),
            ],
          ),
          if (role.menus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              role.menus.take(3).map((menu) => menu.nombre).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, required this.palette});
  final IconData icon;
  final String text;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 17, color: palette.textSecondary), const SizedBox(width: 7), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)))]);
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.palette, required this.icon, required this.title, required this.message, this.action});
  final AppPalette palette;
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: palette.secondary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            if (action != null) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: action, icon: const Icon(Icons.add_rounded), label: const Text('Continuar'))],
          ]),
        ),
      );
}

class _RolPersonalizadoFormSheet extends ConsumerStatefulWidget {
  const _RolPersonalizadoFormSheet({required this.menus, required this.companies, required this.branches, required this.templates, this.role, this.template});
  final RolPersonalizadoModel? role;
  final RolPlantillaModel? template;
  final List<RolPlantillaModel> templates;
  final List<MenuAsignableModel> menus;
  final List<EmpresasResponseModel> companies;
  final List<SucursalesResponseModel> branches;

  @override
  ConsumerState<_RolPersonalizadoFormSheet> createState() => _RolPersonalizadoFormSheetState();
}

class _RolPersonalizadoFormSheetState extends ConsumerState<_RolPersonalizadoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _menuSearch;
  late Set<int> _selectedMenus;
  late List<int> _menuOrder;
  int? _templateId;
  String _menuType = 'Todos';
  int? _companyId;
  int? _branchId;
  bool _branchScope = false;
  bool _active = true;
  bool _saving = false;
  bool _previewMobile = false;
  bool _previewMoreOpen = false;
  int? _previewSelectedMenuId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _name = TextEditingController(text: role?.roleNombre ?? '');
    _description = TextEditingController(text: role?.roleDescripcion ?? widget.template?.descripcion ?? '');
    _menuSearch = TextEditingController();
    _templateId = widget.template?.roleId;
    final delegable = widget.menus.where((menu) => menu.asignable).map((menu) => menu.menuId).toSet();
    _menuOrder = role != null
        ? [...role.menuIds]
        : widget.template == null
            ? <int>[]
            : widget.template!.menuIds.where(delegable.contains).toList(growable: true);
    _selectedMenus = _menuOrder.toSet();
    final companyIds = <int>{
      ...widget.companies.map((item) => item.emprId).whereType<int>(),
      ...widget.branches.map((item) => item.emprId).whereType<int>(),
    };
    _companyId = role?.emprId ?? (companyIds.length == 1 ? companyIds.first : null);
    _branchId = role?.sucuId;
    _branchScope = role?.sucuId != null;
    _active = role?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _menuSearch.dispose();
    super.dispose();
  }

  void _applyTemplate(int? roleId) {
    final matches = widget.templates.where((item) => item.roleId == roleId);
    if (matches.isEmpty) return;
    final template = matches.first;
    final delegable = widget.menus.where((menu) => menu.asignable).map((menu) => menu.menuId).toSet();
    setState(() {
      _templateId = roleId;
      _description.text = template.descripcion;
      _menuOrder = template.menuIds.where(delegable.contains).toList(growable: true);
      _selectedMenus = _menuOrder.toSet();
    });
  }

  List<SucursalesResponseModel> get _availableBranches => widget.branches
      .where((branch) => (_companyId == null || branch.emprId == _companyId) && (branch.sucuEstado == null || branch.sucuEstado == 1))
      .toList()
    ..sort((a, b) => a.label().toLowerCase().compareTo(b.label().toLowerCase()));

  SucursalesResponseModel? _branchById(int? id) {
    if (id == null) return null;
    for (final branch in widget.branches) {
      if (branch.sucuId == id) return branch;
    }
    return null;
  }

  List<String> get _menuTypes {
    final values = widget.menus
        .expand((menu) => menu.tipos)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  // El nombre visible corresponde al registro en commerce.menus.
  String _menuDisplayName(MenuAsignableModel menu) => menu.nombre;

  List<MenuAsignableModel> get _filteredMenus {
    final query = _normalizeMenuText(_menuSearch.text);
    return widget.menus.where((menu) {
      final types = menu.tipos;
      if (_menuType != 'Todos' && !types.contains(_menuType)) return false;
      if (query.isEmpty) return true;
      final searchable = _normalizeMenuText([
        _menuDisplayName(menu),
        menu.nombre,
        menu.descripcion,
        menu.parametro,
        ...types,
      ].join(' '));
      return searchable.contains(query);
    }).toList();
  }

  String _normalizeMenuText(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  MenuAsignableModel? _menuById(int id) {
    for (final menu in widget.menus) {
      if (menu.menuId == id) return menu;
    }
    return null;
  }

  void _setMenuSelected(int menuId, bool selected) {
    setState(() {
      if (selected) {
        if (_selectedMenus.add(menuId)) {
          _menuOrder.add(menuId);
        }
      } else {
        _selectedMenus.remove(menuId);
        _menuOrder.remove(menuId);
      }
    });
  }

  void _selectAllAvailableMenus() {
    final ordered = widget.menus
        .where((item) => item.asignable)
        .map((item) => item.menuId)
        .toList();
    setState(() {
      _selectedMenus = ordered.toSet();
      _menuOrder = ordered;
    });
  }

  void _clearMenus() {
    setState(() {
      _selectedMenus.clear();
      _menuOrder.clear();
    });
  }

  void _reorderMenus(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _menuOrder.removeAt(oldIndex);
      _menuOrder.insert(newIndex, item);
    });
  }

  void _moveMenu(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _menuOrder.length) return;
    setState(() {
      final item = _menuOrder.removeAt(index);
      _menuOrder.insert(newIndex, item);
    });
  }

  List<MenuAsignableModel> get _previewMenus => _menuOrder
      .where(_selectedMenus.contains)
      .map(_menuById)
      .whereType<MenuAsignableModel>()
      .toList(growable: false);

  String _previewMenuKey(MenuAsignableModel menu) {
    var key = menu.parametro.trim().toLowerCase();
    key = key.replaceAll('-', '_').replaceAll(' ', '_');
    switch (key) {
      case 'cuentasventa':
        return 'cuentas_venta';
      case 'detallecuentaventa':
        return 'detalle_cuenta_venta';
      case 'mediospago':
        return 'medios_pago';
      case 'tiposproducto':
        return 'tipos_producto';
      case 'tiposmovimiento':
        return 'tipos_movimiento';
      case 'opcionesmenu':
        return 'opciones_menu';
      case 'rolespersonalizados':
        return 'roles_personalizados';
      case 'inventarioadmin':
        return 'inventario_admin';
      default:
        return key;
    }
  }

  IconData _previewIcon(MenuAsignableModel menu) {
    return ModuleVisuals.byKey(_previewMenuKey(menu)).icon;
  }

  Widget _buildRolePreview(AppPalette palette) {
    final menus = _previewMenus;
    final roleName = _name.text.trim().isEmpty
        ? 'Rol personalizado'
        : _name.text.trim();
    final mobile = _previewMobile;
    final activeMenu = menus.isEmpty
        ? null
        : menus.firstWhere((item) => item.menuId == _previewSelectedMenuId,
            orElse: () => menus.first);
    final maxSlots = mobile ? 4 : 7;
    final hasOverflow = menus.length > maxSlots;
    final visibleCount = hasOverflow ? maxSlots - 1 : menus.length;
    final visible = menus.take(visibleCount).toList(growable: false);
    final overflow = hasOverflow
        ? menus.skip(visibleCount).toList(growable: false)
        : const <MenuAsignableModel>[];

    Widget navItem(MenuAsignableModel menu, {bool active = false}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: mobile ? 34 : 38,
                height: mobile ? 30 : 34,
                decoration: BoxDecoration(
                  color: active
                      ? palette.secondary.withOpacity(0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _previewIcon(menu),
                  size: mobile ? 18 : 20,
                  color: active
                      ? palette.secondary
                      : palette.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                menu.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active
                      ? palette.secondary
                      : palette.textSecondary,
                  fontSize: mobile ? 8.5 : 9.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final previewWidth = mobile ? 390.0 : 900.0;
    final currentTitle = activeMenu?.nombre ?? 'Sin funciones';
    final summary = hasOverflow
        ? menus.length.toString() +
            ' funciones autorizadas · ' +
            visibleCount.toString() +
            ' visibles · ' +
            overflow.length.toString() +
            ' en Más'
        : menus.length.toString() +
            (menus.length == 1
                ? ' función autorizada · visible'
                : ' funciones autorizadas · todas visibles');

    return _Section(
      palette: palette,
      icon: Icons.preview_rounded,
      title: 'Vista previa del rol',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final selector = SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.desktop_windows_rounded),
                    label: Text('Escritorio'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.smartphone_rounded),
                    label: Text('Celular'),
                  ),
                ],
                selected: {_previewMobile},
                onSelectionChanged: (values) => setState(() {
                  _previewMobile = values.first;
                  _previewMoreOpen = false;
                }),
              );
              final description = Text(
                'Así verá la navegación un usuario con este rol. La vista cambia al seleccionar, quitar o reordenar funciones.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              );
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    description,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: selector,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: description),
                  const SizedBox(width: 12),
                  selector,
                ],
              );
            },
          ),
          if (activeMenu != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: activeMenu.menuId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Explorar una función del rol',
                prefixIcon: Icon(Icons.touch_app_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final menu in menus)
                  DropdownMenuItem<int>(
                    value: menu.menuId,
                    child: Text(menu.nombre, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _previewSelectedMenuId = id),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: math.min(
                previewWidth,
                math.max(
                  260.0,
                  MediaQuery.sizeOf(context).width - 64,
                ),
              ).toDouble(),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(0.92),
                borderRadius: BorderRadius.circular(mobile ? 24 : 20),
                border: Border.all(color: palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 14 : 18,
                      vertical: mobile ? 11 : 13,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withOpacity(0.96),
                      border: Border(
                        bottom: BorderSide(color: palette.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          mobile
                              ? Icons.menu_rounded
                              : Icons.dashboard_customize_rounded,
                          size: mobile ? 18 : 20,
                          color: palette.secondary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: mobile ? 13 : 15,
                                ),
                              ),
                              Text(
                                roleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: mobile ? 9.5 : 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(minHeight: mobile ? 170 : 140),
                    width: double.infinity,
                    padding: EdgeInsets.all(mobile ? 14 : 18),
                    alignment: Alignment.topLeft,
                    child: menus.isEmpty
                        ? Center(
                            child: Text(
                              'Selecciona funciones para ver la vista previa.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeMenu!.nombre,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: mobile ? 16 : 18,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                activeMenu.descripcion.trim().isEmpty
                                    ? 'Pantalla disponible para el perfil.'
                                    : activeMenu.descripcion,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: mobile ? 10.5 : 11.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Ejemplo ilustrativo · sin datos reales',
                                style: TextStyle(color: palette.secondary,
                                  fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                  ),
                  if (menus.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 4 : 8,
                        7,
                        mobile ? 4 : 8,
                        6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withOpacity(0.98),
                        border: Border(
                          top: BorderSide(color: palette.cardBorder),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var index = 0;
                              index < visible.length;
                              index++)
                            navItem(
                              visible[index],
                              active: activeMenu?.menuId == visible[index].menuId,
                            ),
                          if (hasOverflow)
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(
                                  () => _previewMoreOpen =
                                      !_previewMoreOpen,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: mobile ? 34 : 38,
                                        height: mobile ? 30 : 34,
                                        decoration: BoxDecoration(
                                          color: _previewMoreOpen
                                              ? palette.secondary
                                                  .withOpacity(0.20)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          size: mobile ? 19 : 21,
                                          color: _previewMoreOpen
                                              ? palette.secondary
                                              : palette.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Más',
                                        style: TextStyle(
                                          color: _previewMoreOpen
                                              ? palette.secondary
                                              : palette.textSecondary,
                                          fontSize: mobile ? 8.5 : 9.5,
                                          fontWeight: _previewMoreOpen
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (menus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
          if (_previewMoreOpen && overflow.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(0.62),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Contenido de Más',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  for (final menu in overflow)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                      ),
                      leading: Icon(
                        _previewIcon(menu),
                        color: palette.secondary,
                      ),
                      title: Text(
                        menu.nombre,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: menu.descripcion.trim().isEmpty
                          ? null
                          : Text(
                              menu.descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedBranch = _branchScope ? _branchById(_branchId) : null;
    final effectiveCompanyId = _companyId ?? selectedBranch?.emprId;
    if ((_branchScope && _branchId == null) || _selectedMenus.isEmpty) {
      setState(() => _error = _selectedMenus.isEmpty ? 'Selecciona al menos una opción de menú.' : 'Selecciona la sucursal del rol.');
      return;
    }
    if (effectiveCompanyId == null && widget.companies.isNotEmpty) {
      setState(() => _error = 'Selecciona la empresa propietaria del rol.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'emprId': effectiveCompanyId,
      'sucuId': _branchScope ? _branchId : null,
      'roleNombre': _name.text.trim(),
      'roleDescripcion': _description.text.trim(),
      'roleEstado': _active ? 1 : 0,
      'menuIds': _menuOrder.where(_selectedMenus.contains).toList(),
    };
    try {
      final api = ref.read(apiClientProvider);
      final response = widget.role == null
          ? await api.post<RolPersonalizadoModel>(
              ApiPaths.rolesPersonalizados,
              body,
              (json) => RolPersonalizadoModel.fromJson(Map<String, dynamic>.from(json as Map)),
            )
          : await api.put<RolPersonalizadoModel>(
              '${ApiPaths.rolesPersonalizados}/${widget.role!.roleId}',
              body,
              (json) => RolPersonalizadoModel.fromJson(Map<String, dynamic>.from(json as Map)),
            );
      if (response.data == null || response.data!.roleId <= 0) {
        throw StateError('El backend no confirmó la creación del rol.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar el rol: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branches = _availableBranches;
    if (_branchId != null && !branches.any((item) => item.sucuId == _branchId)) {
      _branchId = null;
    }

    return Material(
      color: palette.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 9),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: palette.textSecondary.withOpacity(0.32),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.primary, palette.secondary],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      widget.role == null
                          ? Icons.add_moderator_rounded
                          : Icons.edit_rounded,
                      color: palette.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role == null
                              ? 'Crear rol personalizado'
                              : 'Modificar rol personalizado',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Define el alcance y selecciona exactamente las opciones autorizadas.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(
              child: Form(
                key: _formKey,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1050),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: palette.warning.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.warning.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: palette.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (widget.role == null && widget.templates.isNotEmpty) ...[
                              _Section(
                                palette: palette,
                                icon: Icons.auto_awesome_outlined,
                                title: 'Plantilla de la base de datos (opcional)',
                                child: DropdownButtonFormField<int>(
                                  value: _templateId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Partir de los permisos de un rol predefinido',
                                    border: OutlineInputBorder(),
                                  ),
                                  hint: const Text('Configurar desde cero'),
                                  items: [
                                    for (final template in widget.templates)
                                      DropdownMenuItem<int>(
                                        value: template.roleId,
                                        child: Text(template.nombre, overflow: TextOverflow.ellipsis),
                                      ),
                                  ],
                                  onChanged: _saving ? null : _applyTemplate,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _Section(
                              palette: palette,
                              icon: Icons.badge_outlined,
                              title: 'Identidad del rol',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final name = TextFormField(
                                    controller: _name,
                                    maxLength: 50,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Escribe el nombre del rol'
                                            : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre del rol',
                                      hintText: 'Ej. Supervisor de caja',
                                      helperText:
                                          'Debe ser diferente a los roles predefinidos del sistema.',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                  final description = TextFormField(
                                    controller: _description,
                                    maxLength: 100,
                                    minLines: 2,
                                    maxLines: 3,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Escribe una descripción'
                                            : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Descripción',
                                      hintText:
                                          'Explica qué puede hacer este perfil',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                  if (constraints.maxWidth < 720) {
                                    return Column(
                                      children: [
                                        name,
                                        const SizedBox(height: 10),
                                        description,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: name),
                                      const SizedBox(width: 12),
                                      Expanded(child: description),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              palette: palette,
                              icon: Icons.account_tree_outlined,
                              title: 'Alcance operativo',
                              child: Column(
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final company =
                                          DropdownButtonFormField<int>(
                                        value: _companyId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Empresa',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          for (final item
                                              in widget.companies.where(
                                            (item) => item.emprId != null,
                                          ))
                                            DropdownMenuItem<int>(
                                              value: item.emprId!,
                                              child: Text(
                                                item.empreNombreComercial ??
                                                    item.emprRazonSocial ??
                                                    'Empresa #${item.emprId}',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: widget.companies.length <= 1 ||
                                                (widget.role
                                                            ?.usuariosAsignados ??
                                                        0) >
                                                    0
                                            ? null
                                            : (value) => setState(() {
                                                  _companyId = value;
                                                  _branchId = null;
                                                }),
                                        validator: (value) => value == null
                                            ? 'Selecciona la empresa'
                                            : null,
                                      );
                                      final branch =
                                          DropdownButtonFormField<int>(
                                        value: _branchId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Sucursal específica',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          for (final item in branches.where(
                                            (item) => item.sucuId != null,
                                          ))
                                            DropdownMenuItem<int>(
                                              value: item.sucuId!,
                                              child: Text(
                                                item.label(),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: !_branchScope ||
                                                (widget.role
                                                            ?.usuariosAsignados ??
                                                        0) >
                                                    0
                                            ? null
                                            : (value) => setState(
                                                  () => _branchId = value,
                                                ),
                                        validator: (_) =>
                                            _branchScope && _branchId == null
                                                ? 'Selecciona la sucursal'
                                                : null,
                                      );
                                      if (constraints.maxWidth < 720) {
                                        return Column(
                                          children: [
                                            company,
                                            if (_branchScope) ...[
                                              const SizedBox(height: 10),
                                              branch,
                                            ],
                                          ],
                                        );
                                      }
                                      return Row(
                                        children: [
                                          Expanded(child: company),
                                          if (_branchScope) ...[
                                            const SizedBox(width: 12),
                                            Expanded(child: branch),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                          value: false,
                                          icon: Icon(
                                            Icons.corporate_fare_rounded,
                                          ),
                                          label: Text('Toda la empresa'),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          icon: Icon(Icons.store_rounded),
                                          label: Text('Una sucursal'),
                                        ),
                                      ],
                                      selected: {_branchScope},
                                      onSelectionChanged:
                                          (widget.role?.usuariosAsignados ?? 0) >
                                                  0
                                              ? null
                                              : (values) => setState(() {
                                                    _branchScope = values.first;
                                                    if (!_branchScope) {
                                                      _branchId = null;
                                                    }
                                                  }),
                                    ),
                                  ),
                                  if ((widget.role?.usuariosAsignados ?? 0) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'El alcance no puede cambiar mientras el rol esté asignado a usuarios.',
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRolePreview(palette),
                            if (_menuOrder.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _Section(
                                palette: palette,
                                icon: Icons.low_priority_rounded,
                                title: 'Orden del menú',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Arrastra las opciones para definir cuál verá primero el usuario. Este orden se guarda con el rol personalizado.',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      itemCount: _menuOrder.length,
                                      onReorder: _reorderMenus,
                                      itemBuilder: (context, index) {
                                        final menuId = _menuOrder[index];
                                        final menu = _menuById(menuId);
                                        final title = menu?.nombre ?? 'Menú $menuId';
                                        final description = menu?.descripcion ?? '';
                                        return Container(
                                          key: ValueKey('menu-order-$menuId'),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: palette.background.withOpacity(0.70),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: palette.cardBorder),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: palette.secondary.withOpacity(0.14),
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              title,
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: description.isEmpty
                                                ? null
                                                : Text(
                                                    description,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: palette.textSecondary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Subir',
                                                  onPressed: index == 0 ? null : () => _moveMenu(index, -1),
                                                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                                                ),
                                                IconButton(
                                                  tooltip: 'Bajar',
                                                  onPressed: index == _menuOrder.length - 1
                                                      ? null
                                                      : () => _moveMenu(index, 1),
                                                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                                ),
                                                ReorderableDragStartListener(
                                                  index: index,
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: Icon(
                                                      Icons.drag_indicator_rounded,
                                                      color: palette.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            _Section(
                              palette: palette,
                              icon: Icons.apps_rounded,
                              title:
                                  'Opciones de menú (${_selectedMenus.length})',
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: _selectAllAvailableMenus,
                                    child: const Text('Seleccionar disponibles'),
                                  ),
                                  TextButton(
                                    onPressed: _clearMenus,
                                    child: const Text('Limpiar'),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final search = TextField(
                                        maxLength: 120,
                                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                        controller: _menuSearch,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'Buscar opción de menú',
                                          hintText: 'Nombre, descripción o tipo',
                                          prefixIcon: const Icon(Icons.search_rounded),
                                          suffixIcon: _menuSearch.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Limpiar búsqueda',
                                                  onPressed: () => setState(_menuSearch.clear),
                                                  icon: const Icon(Icons.close_rounded),
                                                ),
                                          border: const OutlineInputBorder(),
                                        ),
                                      );
                                      final type = DropdownButtonFormField<String>(
                                        value: _menuType,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Tipo de menú',
                                          prefixIcon: Icon(Icons.category_outlined),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          const DropdownMenuItem(value: 'Todos', child: Text('Todos los tipos')),
                                          for (final item in _menuTypes)
                                            DropdownMenuItem(value: item, child: Text(item)),
                                        ],
                                        onChanged: (value) => setState(() => _menuType = value ?? 'Todos'),
                                      );
                                      if (constraints.maxWidth < 680) {
                                        return Column(children: [search, const SizedBox(height: 10), type]);
                                      }
                                      return Row(children: [Expanded(flex: 2, child: search), const SizedBox(width: 10), Expanded(child: type)]);
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Mostrando ${_filteredMenus.length} de ${widget.menus.length} opciones. Las etiquetas indican qué perfiles estándar usan cada menú.',
                                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_filteredMenus.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: palette.background.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: palette.cardBorder),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.search_off_rounded, size: 38, color: palette.textSecondary),
                                          const SizedBox(height: 8),
                                          Text('No se encontraron opciones de menú', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 4),
                                          Text('Cambia el texto o el tipo seleccionado.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    )
                                  else
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns = constraints.maxWidth >= 900
                                            ? 3
                                            : constraints.maxWidth >= 600
                                                ? 2
                                                : 1;
                                        final width = math.max(
                                          240.0,
                                          (constraints.maxWidth - ((columns - 1) * 10)) / columns,
                                        ).toDouble();
                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            for (final menu in _filteredMenus)
                                              SizedBox(
                                                width: width,
                                                child: Material(
                                                  color: _selectedMenus.contains(menu.menuId)
                                                      ? palette.secondary.withOpacity(0.12)
                                                      : palette.background.withOpacity(0.65),
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: CheckboxListTile(
                                                    value: _selectedMenus.contains(menu.menuId),
                                                    enabled: menu.asignable,
                                                    onChanged: !menu.asignable
                                                        ? null
                                                        : (value) => _setMenuSelected(
                                                              menu.menuId,
                                                              value == true,
                                                            ),
                                                    controlAffinity: ListTileControlAffinity.leading,
                                                    secondary: menu.asignable
                                                        ? null
                                                        : Tooltip(
                                                            message: 'Tu perfil puede consultar esta opción, pero no delegarla.',
                                                            child: Icon(Icons.lock_outline_rounded, color: palette.textSecondary),
                                                          ),
                                                    title: Text(
                                                      _menuDisplayName(menu),
                                                      style: TextStyle(
                                                        color: menu.asignable ? palette.textPrimary : palette.textSecondary,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    subtitle: Padding(
                                                      padding: const EdgeInsets.only(top: 5),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            menu.descripcion,
                                                            maxLines: 4,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                                                          ),
                                                          const SizedBox(height: 7),
                                                          Wrap(
                                                            spacing: 5,
                                                            runSpacing: 5,
                                                            children: [
                                                              for (final type in (menu.tipos))
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: palette.secondary.withOpacity(0.10),
                                                                    borderRadius: BorderRadius.circular(999),
                                                                    border: Border.all(color: palette.secondary.withOpacity(0.30)),
                                                                  ),
                                                                  child: Text(
                                                                    type,
                                                                    style: TextStyle(color: palette.textPrimary, fontSize: 11, fontWeight: FontWeight.w800),
                                                                  ),
                                                                ),
                                                              if (!menu.asignable)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: palette.warning.withOpacity(0.10),
                                                                    borderRadius: BorderRadius.circular(999),
                                                                    border: Border.all(color: palette.warning.withOpacity(0.30)),
                                                                  ),
                                                                  child: Text(
                                                                    'No delegable',
                                                                    style: TextStyle(color: palette.warning, fontSize: 11, fontWeight: FontWeight.w900),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      side: BorderSide(
                                                        color: _selectedMenus.contains(menu.menuId)
                                                            ? palette.secondary
                                                            : palette.cardBorder,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              palette: palette,
                              icon: Icons.toggle_on_outlined,
                              title: 'Estado',
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _active,
                                onChanged: (value) =>
                                    setState(() => _active = value),
                                title: Text(
                                  _active
                                      ? 'Rol habilitado'
                                      : 'Rol inactivo',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  _active
                                      ? 'Los usuarios asignados recibirán las opciones seleccionadas.'
                                      : 'El rol se conserva, pero no entrega permisos.',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(
                  top: BorderSide(color: palette.cardBorder),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cancel = OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                      );
                      final save = AppButton(
                        label: widget.role == null
                            ? 'Crear rol'
                            : 'Guardar cambios',
                        icon: Icons.save_rounded,
                        loading: _saving,
                        onPressed: _save,
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: double.infinity, child: save),
                            const SizedBox(height: 8),
                            SizedBox(width: double.infinity, child: cancel),
                          ],
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
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.palette, required this.icon, required this.title, required this.child, this.trailing});
  final AppPalette palette;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: palette.panelDecoration(baseRadius: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(icon, color: palette.secondary), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16))), if (trailing != null) trailing!]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}
