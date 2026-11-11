import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../data/default_roles_repository.dart';

/// Panel de roles nativos: mismas tarjetas y edición visual que el personalizador.
class RolesListPage extends ConsumerStatefulWidget {
  const RolesListPage({super.key});

  @override
  ConsumerState<RolesListPage> createState() => _RolesListPageState();
}

class _RolesListPageState extends ConsumerState<RolesListPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(defaultRolesRepositoryProvider).roles();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final authorized = ref.watch(activeRolesProvider).any((role) =>
      const {'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN',
        'ADMIN_Y_SOPORTE'}.contains(normalizeRoleName(role)));
    if (!authorized) {
      return Scaffold(
        body: Center(child: Text('Solo administración del sistema puede editar estos roles.',
          style: TextStyle(color: palette.textPrimary))),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
          },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              final roles = snapshot.data ?? const <Map<String, dynamic>>[];
              final filtered = roles.where((role) {
                final text = '${role['roleNombre']} ${role['roleDescripcion']}'.toLowerCase();
                return text.contains(_query);
              }).toList();
              final active = roles.where((r) => DefaultRolesRepository.asInt(
                    r['roleEstado']) == 1).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                children: [
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: palette.panelDecoration(
                            baseRadius: 26, tint: palette.primary),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                Chip(avatar: const Icon(Icons.verified_user_rounded,
                                  size: 17), label: const Text('ADMIN Y SOPORTE')),
                                const Chip(avatar: Icon(Icons.lock_rounded, size: 17),
                                  label: Text('Permisos protegidos')),
                              ]),
                              const SizedBox(height: 12),
                              Text('Administración de roles',
                                style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: palette.textPrimary,
                                    fontWeight: FontWeight.w900)),
                              const SizedBox(height: 7),
                              Text('Configura las opciones de menú de cada rol '
                                'predefinido, revisa su alcance y visualiza '
                                'los permisos antes de guardarlos.',
                                style: TextStyle(color: palette.textSecondary,
                                  height: 1.4)),
                              const SizedBox(height: 16),
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                _Metric(label: 'Roles predefinidos',
                                  value: '${roles.length}', icon: Icons.shield_rounded,
                                  palette: palette),
                                _Metric(label: 'Roles activos',
                                  value: '$active', icon: Icons.verified_rounded,
                                  palette: palette),
                                OutlinedButton.icon(
                                  onPressed: () => context.go('/roles_personalizados'),
                                  icon: const Icon(Icons.add_moderator_rounded),
                                  label: const Text('Roles personalizados')),
                                OutlinedButton.icon(
                                  onPressed: () => setState(_reload),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Actualizar')),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _search,
                          onChanged: (text) => setState(() => _query =
                            text.trim().toLowerCase()),
                          decoration: InputDecoration(
                            labelText: 'Buscar rol por nombre o descripción',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty ? null : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(35),
                            child: CircularProgressIndicator())),
                        if (snapshot.hasError)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: palette.panelDecoration(),
                            child: Column(children: [
                              Text('No se pudieron cargar los roles: ${snapshot.error}',
                                style: TextStyle(color: palette.textPrimary)),
                              TextButton.icon(onPressed: () => setState(_reload),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar')),
                            ])),
                        if (snapshot.connectionState == ConnectionState.done &&
                            !snapshot.hasError && filtered.isEmpty)
                          Padding(padding: const EdgeInsets.all(28),
                            child: Center(child: Text(
                              'No hay roles que coincidan con tu búsqueda.',
                              style: TextStyle(color: palette.textSecondary)))),
                        LayoutBuilder(builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 1020 ? 3
                              : constraints.maxWidth >= 650 ? 2 : 1;
                          final width = (constraints.maxWidth - (cols - 1) * 12) / cols;
                          return Wrap(
                            spacing: 12, runSpacing: 12,
                            children: [
                              for (final role in filtered)
                                SizedBox(width: width, child: _RoleCard(
                                  role: role, palette: palette,
                                  onEdit: () => context.go(
                                    '/roles/${DefaultRolesRepository.asInt(role['roleId'])}/editar'))),
                            ]);
                        }),
                      ],
                    ),
                  )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value,
    required this.icon, required this.palette});
  final String label, value;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: palette.panelDecoration(baseRadius: 17, elevated: false),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: palette.primary, size: 21),
      const SizedBox(width: 9),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: palette.textPrimary,
          fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: palette.textSecondary,
          fontSize: 11)),
      ]),
    ]),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.palette,
    required this.onEdit});
  final Map<String, dynamic> role;
  final AppPalette palette;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final enabled = DefaultRolesRepository.asInt(role['roleEstado']) == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: palette.panelDecoration(baseRadius: 21,
            tint: palette.primary),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(.13),
                  borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.admin_panel_settings_rounded,
                  color: palette.primary, size: 27)),
              const Spacer(),
              Chip(label: Text(enabled ? 'Activo' : 'Inactivo'),
                avatar: Icon(enabled ? Icons.check_circle_outline
                  : Icons.pause_circle_outline, size: 16)),
            ]),
            const SizedBox(height: 12),
            Text(role['roleNombre']?.toString() ?? 'Sin nombre',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: palette.textPrimary,
                  fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(role['roleDescripcion']?.toString() ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, height: 1.3)),
            const SizedBox(height: 14),
            Wrap(spacing: 7, runSpacing: 7, children: [
              Chip(avatar: const Icon(Icons.apps_rounded, size: 17),
                label: Text('${DefaultRolesRepository.asInt(role['menuCount'])} opciones')),
              if (role['manuallyConfigured'] == true)
                const Chip(label: Text('Personalizado por soporte')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('Administrar opciones de menú',
                style: TextStyle(color: palette.primary,
                  fontWeight: FontWeight.w800, fontSize: 12)),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, color: palette.primary),
            ]),
          ]),
        ),
      ),
    );
  }
}
