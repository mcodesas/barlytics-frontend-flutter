import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/admin_support_repository.dart';

class AdminDiagnosticsPage extends ConsumerStatefulWidget {
  const AdminDiagnosticsPage({super.key});

  @override
  ConsumerState<AdminDiagnosticsPage> createState() => _AdminDiagnosticsPageState();
}

class _AdminDiagnosticsPageState extends ConsumerState<AdminDiagnosticsPage> {
  late Future<Map<String, dynamic>> _future;
  bool _repairing = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminSupportRepositoryProvider).diagnostics();
  }

  void _reload() => setState(() => _future = ref.read(adminSupportRepositoryProvider).diagnostics());

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          final checks = _maps(data['checks']);
          final healthy = data['healthy'] == true;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: palette.panelDecoration(baseRadius: 24, tint: healthy ? palette.success : palette.warning),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Wrap(spacing: 8, runSpacing: 8, children: [_Badge(label: data['database']?.toString() ?? 'Base de datos', icon: Icons.storage_rounded, palette: palette), _Badge(label: 'PostgreSQL ${data['version'] ?? ''}', icon: Icons.storage_rounded, palette: palette), _Badge(label: '${data['tables'] ?? 0} tablas', icon: Icons.table_chart_rounded, palette: palette)]), const SizedBox(height: 14), Text(healthy ? 'Integridad general estable' : 'Se encontraron novedades por revisar', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text('Las reparaciones automáticas se limitan a permisos, secuencias y relaciones huérfanas seguras. Los datos comerciales siempre requieren revisión.', style: TextStyle(color: palette.textSecondary, height: 1.4)), const SizedBox(height: 14), Wrap(spacing: 9, runSpacing: 9, children: [FilledButton.icon(onPressed: _repairing ? null : _repairPermissions, icon: const Icon(Icons.admin_panel_settings_rounded, size: 18), label: const Text('Restaurar permisos'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40))), OutlinedButton.icon(onPressed: _repairing ? null : _repairSequences, icon: const Icon(Icons.sync_rounded, size: 18), label: const Text('Sincronizar secuencias'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40))), OutlinedButton.icon(onPressed: _repairing ? null : _repairOrphans, icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Limpiar huérfanos'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40))), OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Volver a validar'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)))] )]);
                    final icon = Container(width: 88, height: 88, decoration: BoxDecoration(color: (healthy ? palette.success : palette.warning).withOpacity(.10), borderRadius: BorderRadius.circular(26)), child: Icon(healthy ? Icons.fact_check_rounded : Icons.warning_amber_rounded, color: healthy ? palette.success : palette.warning, size: 48));
                    if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [icon, const SizedBox(height: 15), info]);
                    return Row(children: [Expanded(child: info), const SizedBox(width: 20), icon]);
                  }),
                ),
                if (snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
                if (snapshot.hasError) Padding(padding: const EdgeInsets.only(top: 14), child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 18),
                Text('Validaciones de integridad', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final check in checks) Padding(padding: const EdgeInsets.only(bottom: 10), child: _CheckCard(check: check, palette: palette, onRepair: !_repairing && check['repairAction'] == 'repair-orphans' ? _repairOrphans : null)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _repairSequences() async => _runRepair(() => ref.read(adminSupportRepositoryProvider).repairSequences(), 'Secuencias sincronizadas.');
  Future<void> _repairPermissions() async => _runRepair(() => ref.read(adminSupportRepositoryProvider).repairAdminPermissions(), 'Permisos globales restaurados.');
  Future<void> _repairOrphans() async => _runRepair(() => ref.read(adminSupportRepositoryProvider).repairOrphans(), 'Relaciones huérfanas limpiadas.');

  Future<void> _runRepair(Future<Map<String, dynamic>> Function() action, String message) async {
    setState(() => _repairing = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.check, required this.palette, this.onRepair});
  final Map<String, dynamic> check;
  final AppPalette palette;
  final VoidCallback? onRepair;
  @override
  Widget build(BuildContext context) {
    final ok = check['ok'] == true;
    final severity = check['severity']?.toString();
    final color = ok ? palette.success : severity == 'critical' ? Colors.red : palette.warning;
    final route = check['route']?.toString();
    final count = int.tryParse(check['count']?.toString() ?? '') ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 18, tint: color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, color: color)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text(check['title']?.toString() ?? '', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999)), child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)))]),
                const SizedBox(height: 4),
                Text(check['description']?.toString() ?? '', style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.35)),
                if (!ok && (route != null || onRepair != null)) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (route != null && route.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => context.go(route),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Revisar'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        ),
                      if (onRepair != null)
                        FilledButton.icon(
                          onPressed: onRepair,
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Reparar'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.palette});
  final String label;
  final IconData icon;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: palette.primary.withOpacity(.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.primary.withOpacity(.14))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: palette.primary, size: 15), const SizedBox(width: 6), Text(label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 10.5))]));
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const <Object?>[]).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
