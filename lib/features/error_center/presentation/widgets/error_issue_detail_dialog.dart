import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/error_center_repository.dart';

/// Desglose técnico completo para el administrador de MCode SAS.
/// Los stacktraces recibidos ya están limitados y anonimizados por el backend.
class ErrorIssueDetailDialog extends ConsumerStatefulWidget {
  const ErrorIssueDetailDialog({
    super.key,
    required this.id,
    required this.onChanged,
  });

  final int id;
  final VoidCallback onChanged;

  @override
  ConsumerState<ErrorIssueDetailDialog> createState() =>
      _ErrorIssueDetailDialogState();
}

class _ErrorIssueDetailDialogState
    extends ConsumerState<ErrorIssueDetailDialog> {
  final _noteController = TextEditingController();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ref.read(errorCenterRepositoryProvider)
          .detail(widget.id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(errorCenterRepositoryProvider)
          .updateStatus(widget.id, status);
      if (!mounted) return;
      widget.onChanged();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de incidencia actualizado.')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(errorCenterRepositoryProvider).addNote(widget.id, note);
      if (!mounted) return;
      _noteController.clear();
      widget.onChanged();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota técnica registrada.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final size = MediaQuery.sizeOf(context);
    final issue = _data['issue'] is Map
        ? Map<String, dynamic>.from(_data['issue'] as Map)
        : <String, dynamic>{};
    final events = ErrorCenterRepository.rows(_data['events']);
    final versions = ErrorCenterRepository.rows(
        _data['samplesByVersion']);
    final timeline = ErrorCenterRepository.rows(_data['timeline']);
    final notes = ErrorCenterRepository.rows(_data['notes']);
    final branches = ErrorCenterRepository.rows(_data['branches']);
    final status = issue['status']?.toString() ?? 'OPEN';

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: palette.surface,
      child: SizedBox(
        width: math.min(size.width - 24, 980),
        height: math.min(size.height * .88, 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 8, 11),
              child: Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: palette.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Investigación técnica',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 17)),
                        Text('Incidencia #' + widget.id.toString(),
                          style: TextStyle(color: palette.textSecondary,
                            fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar detalles',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading && issue.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(17, 4, 17, 22),
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_error!,
                              style: const TextStyle(color: Colors.red))),
                        Text(issue['title']?.toString() ?? 'Sin detalle',
                          style: TextStyle(color: palette.textPrimary,
                            fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 7, runSpacing: 7, children: [
                          _Tag('Estado ' + status, palette.secondary),
                          _Tag(issue['severity']?.toString() ?? 'ERROR',
                              Colors.redAccent),
                          if (ErrorCenterRepository.number(issue['reopenCount']) > 0)
                            _Tag('Reincidencias ' +
                              issue['reopenCount'].toString(), Colors.deepOrange),
                          _Tag('Ocurrencias ' +
                              (issue['occurrences']?.toString() ?? '0'),
                              palette.primary),
                          _Tag('Empresa ' +
                              (issue['empresaId']?.toString() ?? 'global'),
                              palette.secondary),
                          _Tag('Sucursal ' +
                              (issue['sucursalId']?.toString() ?? '—'),
                              palette.secondary),
                        ]),
                        const SizedBox(height: 13),
                        _Section(
                          title: 'Posible causa',
                          icon: Icons.psychology_alt_rounded,
                          palette: palette,
                          body: issue['suggestedCause']?.toString() ??
                              'No se ha identificado una hipótesis.',
                        ),
                        const SizedBox(height: 9),
                        _Section(
                          title: 'Qué revisar primero',
                          icon: Icons.task_alt_rounded,
                          palette: palette,
                          body: issue['suggestedAction']?.toString() ??
                              'Inspeccionar la traza técnica.',
                        ),
                        const SizedBox(height: 10),
                        _Section(
                          title: 'Origen y alcance',
                          icon: Icons.device_hub_rounded,
                          palette: palette,
                          body: 'Origen: ' + (issue['origin']?.toString() ?? '—') +
                              '\nCategoría: ' +
                              (issue['category']?.toString() ?? '—') +
                              '\nClase: ' +
                              (issue['errorType']?.toString() ?? '—') +
                              '\nMódulo: ' +
                              (issue['module']?.toString() ?? '—') +
                              '\nRuta: ' +
                              (issue['route']?.toString() ?? '—') +
                              '\nPlataforma: ' +
                              (issue['platform']?.toString() ?? '—') +
                              '\nPrimera vez: ' +
                              (issue['firstSeen']?.toString() ?? '—') +
                              '\nÚltima vez: ' +
                              (issue['lastSeen']?.toString() ?? '—'),
                        ),
                        const SizedBox(height: 14),
                        Text('Gestión de la incidencia',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('incident-status-' + status),
                          value: const {
                            'OPEN','INVESTIGATING','RESOLVED','IGNORED',
                          }.contains(status) ? status : 'OPEN',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Estado de investigación',
                            prefixIcon: Icon(Icons.assignment_turned_in_rounded)),
                          items: const [
                            DropdownMenuItem(value: 'OPEN',
                              child: Text('Pendiente')),
                            DropdownMenuItem(value: 'INVESTIGATING',
                              child: Text('Investigando')),
                            DropdownMenuItem(value: 'RESOLVED',
                              child: Text('Resuelto')),
                            DropdownMenuItem(value: 'IGNORED',
                              child: Text('Ignorado')),
                          ],
                          onChanged: _saving ? null : (value) {
                            if (value != null && value != status) {
                              _changeStatus(value);
                            }
                          },
                        ),
                        if (_saving)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2)),
                        const SizedBox(height: 19),
                        Text('Bitácora de investigación',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Hallazgo, pasos de reproducción o corrección aplicada',
                            prefixIcon: Icon(Icons.edit_note_rounded)),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _addNote,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Guardar nota'),
                          ),
                        ),
                        if (notes.isEmpty)
                          Text('Aún no hay notas de seguimiento.',
                            style: TextStyle(color: palette.textSecondary,
                              fontSize: 11))
                        else
                          for (final note in notes.take(25))
                            ListTile(
                              dense: true,
                              leading: Icon(
                                note['action'] == 'STATUS'
                                  ? Icons.swap_horiz_rounded
                                  : Icons.description_outlined,
                                color: palette.secondary,
                              ),
                              title: Text(note['action'] == 'STATUS'
                                  ? (note['previousStatus']?.toString() ?? '') +
                                    ' → ' + (note['newStatus']?.toString() ?? '')
                                  : note['note']?.toString() ?? ''),
                              subtitle: Text(
                                'Administrador ID ' +
                                (note['actorUserId']?.toString() ?? '') +
                                ' · ' + (note['createdAt']?.toString() ?? ''),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 10)),
                            ),
                        const SizedBox(height: 19),
                        Text('Versiones y dispositivos afectados (conteo exacto)',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 7),
                        if (versions.isEmpty)
                          Text('Sin versiones registradas.',
                            style: TextStyle(color: palette.textSecondary))
                        else
                          for (final version in versions)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.devices_rounded),
                              title: Text(
                                (version['platform']?.toString() ?? '') +
                                ' · ' +
                                (version['appVersion']?.toString() ?? '') +
                                ' build ' +
                                (version['appBuild']?.toString() ?? '')),
                              subtitle: Text('Última muestra: ' +
                                  (version['lastSeen']?.toString() ?? '—')),
                              trailing: Text(
                                version['occurrences']?.toString() ?? '0'),
                            ),
                        const SizedBox(height: 13),
                        Text('Sucursales afectadas (conteo exacto)',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 15)),
                        if (branches.isEmpty)
                          Text('Sin sucursales identificadas.',
                            style: TextStyle(color: palette.textSecondary))
                        else
                          for (final branch in branches)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.storefront_rounded),
                              title: Text('Sucursal ' +
                                (branch['branchId'] == 0
                                  ? 'sin identificar'
                                  : branch['branchId'].toString())),
                              trailing: Text((branch['occurrences']?.toString()
                                ?? '0') + ' fallos'),
                            ),
                        const SizedBox(height: 13),
                        Text('Frecuencia horaria (últimos 7 días)',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 15)),
                        if (timeline.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Text('Sin datos horarios.',
                              style: TextStyle(color: palette.textSecondary)))
                        else
                          for (final hour in timeline.take(40))
                            Row(children: [
                              SizedBox(
                                width: 135,
                                child: Text(hour['hour']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 10))),
                              Expanded(
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: math.min(1.0,
                                      ErrorCenterRepository.number(
                                              hour['occurrences']) / 30.0),
                                  borderRadius: BorderRadius.circular(5))),
                              const SizedBox(width: 9),
                              Text(hour['occurrences']?.toString() ?? '0'),
                            ]),
                        const SizedBox(height: 18),
                        Text('Evidencia técnica reciente',
                          style: TextStyle(color: palette.textPrimary,
                            fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Una muestra incluye stacktrace, resolución de '
                            'pantalla, petición y pasos previos, si existen. '
                            'Los errores repetidos pueden tener menos muestras '
                            'que ocurrencias.',
                          style: TextStyle(color: palette.textSecondary,
                            fontSize: 11)),
                        if (events.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text('Todavía no hay trazas guardadas.',
                              style: TextStyle(color: palette.textSecondary)))
                        else
                          for (final event in events)
                            Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: _Evidence(event: event, palette: palette),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      color: color.withOpacity(.10),
      border: Border.all(color: color.withOpacity(.3))),
    child: Text(label, style: TextStyle(color: color,
      fontSize: 10, fontWeight: FontWeight.w800)),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon,
    required this.palette, required this.body});
  final String title;
  final IconData icon;
  final AppPalette palette;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: palette.panelDecoration(
      baseRadius: 16, tint: palette.secondary, elevated: false),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: palette.secondary, size: 18),
          const SizedBox(width: 7),
          Text(title, style: TextStyle(
            color: palette.textPrimary, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        SelectableText(body,
          style: TextStyle(color: palette.textSecondary,
            fontSize: 12, height: 1.43)),
      ],
    ),
  );
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.event, required this.palette});
  final Map<String, dynamic> event;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final trace = event['stacktrace']?.toString() ?? '';
    final title = 'Muestra #' + (event['id']?.toString() ?? '') +
        ' · ' + (event['occurredAt']?.toString() ?? '—');
    return Container(
      decoration: palette.panelDecoration(
        baseRadius: 17, tint: palette.primary, elevated: false),
      child: ExpansionTile(
        title: Text(title, style: TextStyle(
          color: palette.textPrimary, fontWeight: FontWeight.w800,
          fontSize: 12)),
        subtitle: Text(
          (event['platform']?.toString() ?? '') + ' · ' +
          (event['appVersion']?.toString() ?? '') + ' · build ' +
          (event['appBuild']?.toString() ?? ''),
          style: TextStyle(color: palette.textSecondary, fontSize: 11)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 15),
        children: [
          _EvidenceRow('Dispositivo y SO', event['deviceContext']),
          _EvidenceRow('Usuario ID', event['reporterUserId']),
          _EvidenceRow('Sucursal ID', event['sucursalId']),
          _EvidenceRow('Pantalla lógica',
            (event['screenWidth']?.toString() ?? '—') + ' × ' +
            (event['screenHeight']?.toString() ?? '—')),
          _EvidenceRow('HTTP', (event['httpMethod']?.toString() ?? '') +
              ' ' + (event['httpStatus']?.toString() ?? '')),
          _EvidenceRow('Tiempo de respuesta',
              (event['durationMs']?.toString() ?? '—') + ' ms'),
          _EvidenceRow('ID de correlación', event['correlationId']),
          _EvidenceRow('Última acción', event['lastAction']),
          const SizedBox(height: 10),
          _Section(title: 'Mensaje', icon: Icons.message_outlined,
            palette: palette,
            body: event['message']?.toString() ?? '—'),
          const SizedBox(height: 8),
          _Section(title: 'Acciones anteriores', icon: Icons.route_rounded,
            palette: palette,
            body: event['breadcrumbs']?.toString() ?? '—'),
          const SizedBox(height: 8),
          _Section(title: 'Stack trace', icon: Icons.terminal_rounded,
            palette: palette, body: trace.isEmpty
                ? 'No hay stacktrace para este evento.' : trace),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar traza'),
              onPressed: () => Clipboard.setData(
                ClipboardData(text: trace)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow(this.label, this.value);
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 135, child: Text(label,
          style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700))),
        Expanded(child: SelectableText(value?.toString() ?? '—',
          style: const TextStyle(fontSize: 11))),
      ],
    ),
  );
}
