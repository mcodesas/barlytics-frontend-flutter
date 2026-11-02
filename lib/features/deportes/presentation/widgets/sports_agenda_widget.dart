import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/core_providers.dart';

/// Agenda deportiva para gerencia. No promete derechos de transmisión.
class SportsAgendaWidget extends ConsumerStatefulWidget {
  const SportsAgendaWidget({super.key});
  @override
  ConsumerState<SportsAgendaWidget> createState() => _SportsAgendaWidgetState();
}

class _SportsAgendaWidgetState extends ConsumerState<SportsAgendaWidget> {
  DateTime _date = DateTime.now();
  String _sport = 'Soccer';
  String _league = '';
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _data = {};
  final _leagueController = TextEditingController();
  static const _sports = <String, String>{
    'Soccer': 'Fútbol',
    'Basketball': 'Baloncesto',
    'Tennis': 'Tenis',
    'Motorsport': 'Automovilismo',
    'Baseball': 'Béisbol',
    'American Football': 'Fútbol americano',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    _leagueController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; });
    try {
      final response = await ref.read(apiClientProvider).get<Object?>(
        '/api/v1/agenda-deportiva', (j) => j,
        queryParameters: {
          'fecha': DateFormat('yyyy-MM-dd').format(_date),
          'deporte': _sport,
          if (_league.isNotEmpty) 'liga': _league,
        },
      );
      if (!mounted) return;
      setState(() {
        _data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : {};
        _busy = false;
      });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = error.toString(); });
    }
  }

  Future<void> _open(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible abrir la noticia.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matches = _rows(_data['partidos']);
    final news = _rows(_data['noticias']);
    return Card(
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.sports_soccer, color: scheme.primary),
            const SizedBox(width: 9),
            const Expanded(child: Text('Agenda deportiva y noticias',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            IconButton(onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar'),
          ]),
          const Text('Información para planear eventos del bar. Horarios en Colombia; '
              'la programación no garantiza disponibilidad de transmisión.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 185, child: DropdownButtonFormField<String>(
                value: _sport, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Deporte', isDense: true),
                items: [for (final e in _sports.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) {
                  if (v != null) { setState(() => _sport = v); _load(); }
                },
              )),
              OutlinedButton.icon(
                icon: const Icon(Icons.today_outlined),
                label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                onPressed: () async {
                  final today = DateUtils.dateOnly(DateTime.now());
                  final selected = await showDatePicker(context: context,
                    initialDate: _date, firstDate: today.subtract(const Duration(days: 1)),
                    lastDate: today.add(const Duration(days: 14)));
                  if (selected != null) { setState(() => _date = selected); _load(); }
                },
              ),
              SizedBox(width: 190, child: TextField(
                controller: _leagueController,
                decoration: InputDecoration(
                  labelText: 'Liga (opcional)', isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Filtrar liga', icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() => _league = _leagueController.text.trim());
                      _load();
                    },
                  ),
                ),
                onSubmitted: (v) { setState(() => _league = v.trim()); _load(); },
              )),
            ],
          ),
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator()),
          if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
          const SizedBox(height: 12),
          const Text('Próximos encuentros en la fecha seleccionada',
            style: TextStyle(fontWeight: FontWeight.bold)),
          if (_data['configurado'] != true)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
              _data['errorProgramacion']?.toString() ??
                  'Proveedor de programación sin configurar.',
              style: TextStyle(color: scheme.secondary))),
          if (_data['configurado'] == true && matches.isEmpty && !_busy)
            const Text('No se encontraron encuentros en la fuente para esos filtros.'),
          for (final game in matches.take(20)) ListTile(
            dense: true,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(game['nombre']?.toString().isNotEmpty == true
                ? game['nombre'].toString()
                : (game['local']?.toString() ?? 'Local') + ' vs ' +
                    (game['visitante']?.toString() ?? 'Visitante')),
            subtitle: Text((game['liga']?.toString() ?? 'Liga') +
                ' · ' + (game['horaBogota']?.toString().isNotEmpty == true
                    ? game['horaBogota'].toString().replaceAll('T', ' ') +
                        ' (hora Colombia)'
                    : 'Hora no confirmada')),
          ),
          const Divider(height: 22),
          const Text('Noticias deportivas',
              style: TextStyle(fontWeight: FontWeight.bold)),
          if (news.isEmpty && !_busy)
            Text(_data['errorNoticias']?.toString().isNotEmpty == true
                ? _data['errorNoticias'].toString()
                : 'No hay noticias disponibles en este momento.'),
          for (final item in news) ListTile(
            dense: true,
            title: Text(item['titulo']?.toString() ?? 'Noticia'),
            subtitle: Text(item['fuente']?.toString() ?? 'Fuente externa'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 17),
            onTap: () => _open(item['url']?.toString() ?? ''),
          ),
          const SizedBox(height: 8),
          Text('Fuente partidos: TheSportsDB · Noticias: Google News (enlaces a los editores). '
              'Verifica canal, licencias y permisos de exhibición comercial en Colombia.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
        ]),
      ),
    );
  }
}
