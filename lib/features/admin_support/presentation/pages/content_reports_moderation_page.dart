import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/tech_background.dart';

/// Solo visible al equipo de administración global. La API verifica el rol
/// para impedir que un negocio gestione denuncias sobre otros negocios.
class ContentReportsModerationPage extends ConsumerStatefulWidget {
  const ContentReportsModerationPage({super.key});

  @override
  ConsumerState<ContentReportsModerationPage> createState() =>
      _ContentReportsModerationPageState();
}

class _ContentReportsModerationPageState
    extends ConsumerState<ContentReportsModerationPage> {
  List<Map<String, dynamic>> _reports = const [];
  String _status = 'PENDIENTE';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _statuses = <String, String>{
    'PENDIENTE': 'Pendientes',
    'EN_REVISION': 'En revisión',
    'RESUELTO': 'Resueltos',
    'DESCARTADO': 'Descartados',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(dioProvider).get<dynamic>(
        '/api/v1/admin/content-reports',
        queryParameters: {'estado': _status},
      );
      final items = response.data is List ? response.data as List : const [];
      if (!mounted) return;
      setState(() => _reports = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList());
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudieron consultar las denuncias: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> report, String next) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar denuncia'),
        content: Text('¿Cambiar el estado a ${_statuses[next] ?? next}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).put<dynamic>(
        '/api/v1/admin/content-reports/' + report['id'].toString(),
        data: {'estado': next},
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = 'No fue posible actualizar la denuncia: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openMenu(String slug) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(slug)) return;
    await launchUrl(
      Uri.parse('https://www.barlytics.com.co/#/carta/' + Uri.encodeComponent(slug)),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Moderación de contenido',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                  'Denuncias recibidas desde las cartas públicas. '
                  'Consulta el contenido y marca cada caso al resolverlo.',
                  style: TextStyle(color: palette.textSecondary),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Estado del reporte',
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses.entries.map((entry) =>
                          DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          )).toList(),
                      onChanged: _saving ? null : (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                        _load();
                      },
                    ),
                  ),
                ),
                if (_saving || _loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!, style: TextStyle(color: palette.danger)),
                  ),
                if (!_loading && _reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No existen denuncias en este estado.'),
                  ),
                for (final report in _reports)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((report['titulo'] ?? 'Carta digital').toString(),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Motivo: ' + (report['motivo'] ?? 'Otro').toString()),
                          Text('Sucursal: ' + (report['sucursalId'] ?? '').toString()),
                          Text('Recibido: ' + (report['creado'] ?? '').toString()),
                          if ((report['detalles']?.toString() ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(report['detalles'].toString()),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openMenu(
                                  (report['slug'] ?? '').toString()),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Ver carta'),
                              ),
                              if (_status != 'EN_REVISION')
                                OutlinedButton.icon(
                                  onPressed: _saving ? null : () =>
                                      _changeStatus(report, 'EN_REVISION'),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Revisar'),
                                ),
                              if (_status != 'RESUELTO')
                                FilledButton.icon(
                                  onPressed: _saving ? null : () =>
                                      _changeStatus(report, 'RESUELTO'),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Resuelto'),
                                ),
                              if (_status != 'DESCARTADO')
                                TextButton(
                                  onPressed: _saving ? null : () =>
                                      _changeStatus(report, 'DESCARTADO'),
                                  child: const Text('Descartar'),
                                ),
                            ],
                          ),
                        ],
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
