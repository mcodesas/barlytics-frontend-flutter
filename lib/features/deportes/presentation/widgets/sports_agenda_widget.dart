import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';

/// Fecha civil del día en Colombia; la agenda remota publica horas de Bogotá.
///
/// Usar la fecha del dispositivo falla cuando el usuario viaja a otro país.
/// El argumento opcional permite probar el cambio de fecha en medianoche.
DateTime sportsTodayBogota({DateTime? now}) {
  final utc = (now ?? DateTime.now()).toUtc();
  final colombia = utc.subtract(const Duration(hours: 5));
  return DateTime(colombia.year, colombia.month, colombia.day);
}

/// Mismo lenguaje visual del resto de BarLytics: paleta, densidad y superficies.
/// En Inicio se presenta un resumen; la pantalla propia permite consultar todo.
class SportsAgendaWidget extends ConsumerStatefulWidget {
  const SportsAgendaWidget({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<SportsAgendaWidget> createState() => _SportsAgendaWidgetState();
}

class _SportsAgendaWidgetState extends ConsumerState<SportsAgendaWidget> {
  DateTime _date = sportsTodayBogota();
  Timer? _todayTimer;
  final _leagueController = TextEditingController();
  final _cityController = TextEditingController();
  String _league = '';
  String _city = '';
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _data = {};
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    if (widget.compact) {
      // La tarjeta de Inicio siempre representa HOY en Colombia,
      // incluso si el panel gerencial permanece abierto toda la noche.
      _todayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        final today = sportsTodayBogota();
        if (!DateUtils.isSameDay(_date, today)) {
          setState(() {
            _date = today;
            _data = {};
          });
          _load();
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    _leagueController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return [];
    return value.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_requestNumber;
    if (widget.compact) {
      final today = sportsTodayBogota();
      if (!DateUtils.isSameDay(_date, today)) {
        _date = today;
        _data = {};
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<Object?>(
        '/api/v1/agenda-deportiva',
        (json) => json,
        queryParameters: {
          'fecha': DateFormat('yyyy-MM-dd').format(_date),
          'deporte': 'Soccer',
          if (_league.isNotEmpty) 'liga': _league,
          if (_city.isNotEmpty) 'ciudad': _city,
        },
      );
      if (!mounted || request != _requestNumber) return;
      setState(() {
        _data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : {};
        _busy = false;
      });
    } catch (e) {
      if (!mounted || request != _requestNumber) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo consultar la programación. Reintenta.';
      });
    }
  }

  Future<void> _open(String raw) async {
    final url = Uri.tryParse(raw);
    if (url == null || url.scheme != 'https') return;
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  void _filter() {
    FocusScope.of(context).unfocus();
    setState(() {
      _league = _leagueController.text.trim();
      _city = _cityController.text.trim();
    });
    _load();
  }

  Future<void> _pickDate() async {
    final today = sportsTodayBogota();
    final first = today.subtract(const Duration(days: 1));
    final last = today.add(const Duration(days: 14));
    final current = _date.isBefore(first) || _date.isAfter(last) ? today : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: last,
      helpText: 'Fecha de los encuentros',
    );
    if (selected == null || !mounted) return;
    setState(() => _date = selected);
    _load();
  }

  String _hour(Object? raw) {
    final value = raw?.toString() ?? '';
    final date = DateTime.tryParse(value);
    return date == null ? 'Hora por confirmar' : DateFormat('h:mm a', 'es_CO').format(date);
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: padding ?? palette.panelPadding(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.cardBorder),
        borderRadius: BorderRadius.circular(palette.radius(20)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title, IconData icon, int count) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 21, color: palette.secondary),
        const SizedBox(width: 9),
        Expanded(child: Text(title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18 * palette.fontScale,
            fontWeight: FontWeight.w800,
          ),
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(count.toString(),
            style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _matchCard(Map<String, dynamic> match) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final local = match['local']?.toString().trim() ?? '';
    final visitor = match['visitante']?.toString().trim() ?? '';
    final title = local.isNotEmpty && visitor.isNotEmpty
        ? local + '  vs  ' + visitor
        : (match['nombre']?.toString() ?? 'Encuentro deportivo');
    final location = [
      match['ciudad']?.toString().trim() ?? '',
      match['sede']?.toString().trim() ?? '',
    ].where((item) => item.isNotEmpty).join(' · ');
    final status = match['estado']?.toString() ?? '';
    return _surface(
      padding: EdgeInsets.all(14 * palette.spacingScale),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(palette.radius(14)),
            color: palette.secondary.withOpacity(0.12),
          ),
          child: Column(children: [
            Icon(Icons.sports_soccer_rounded, color: palette.secondary, size: 21),
            const SizedBox(height: 7),
            Text(_hour(match['horaBogota']),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textPrimary, fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(match['liga']?.toString() ?? 'Liga',
            style: TextStyle(color: palette.secondary, fontSize: 12,
                fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(color: palette.textPrimary,
              fontSize: 15 * palette.fontScale, fontWeight: FontWeight.w800)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined, size: 15, color: palette.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(location,
                style: TextStyle(color: palette.textSecondary, fontSize: 12))),
            ]),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(status, style: TextStyle(color: palette.textSecondary, fontSize: 11)),
          ],
        ])),
      ]),
    );
  }

  Widget _newsCard(Map<String, dynamic> item) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return _surface(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(palette.radius(14)),
        onTap: () => _open(item['url']?.toString() ?? ''),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(palette.radius(13)),
            ),
            child: Icon(Icons.article_outlined, color: palette.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['titulo']?.toString() ?? 'Noticia deportiva',
              maxLines: widget.compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item['fuente']?.toString() ?? 'Fuente externa',
              style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          ])),
          Icon(Icons.open_in_new_rounded, size: 17, color: palette.secondary),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final matches = _rows(_data['partidos']);
    final news = _rows(_data['noticias']);
    final matchLimit = widget.compact ? 4 : 30;
    const newsLimit = 12;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 640;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: EdgeInsets.all((isMobile ? 18 : 24) * palette.spacingScale),
          decoration: BoxDecoration(
            gradient: palette.mainGradient,
            borderRadius: BorderRadius.circular(palette.radius(24)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.17),
                borderRadius: BorderRadius.circular(palette.radius(16)),
              ),
              child: Icon(Icons.sports_soccer_rounded,
                  color: palette.onPrimary, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.compact ? 'HOY EN COLOMBIA' : 'AGENDA PARA TU NEGOCIO',
                style: TextStyle(color: palette.onPrimary.withOpacity(0.80),
                    fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(widget.compact ? 'Partidos de hoy' : 'Deportes y noticias',
                style: TextStyle(color: palette.onPrimary,
                    fontSize: (isMobile ? 21 : 26) * palette.fontScale,
                    fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.compact
                  ? DateFormat('EEEE d MMMM', 'es_CO').format(_date)
                  : 'Encuentros de fútbol y titulares para planear la agenda del bar.',
                style: TextStyle(color: palette.onPrimary.withOpacity(0.9),
                    fontSize: 12 * palette.fontScale)),
            ])),
            if (widget.compact) ...[
              IconButton(
                tooltip: 'Actualizar partidos del día',
                onPressed: _busy ? null : _load,
                icon: Icon(Icons.refresh_rounded, color: palette.onPrimary),
              ),
              IconButton(
                tooltip: 'Ver agenda completa',
                onPressed: () => context.go('/agenda_deportiva'),
                icon: Icon(Icons.arrow_forward_rounded, color: palette.onPrimary),
              ),
            ],
          ]),
        ),
        SizedBox(height: 14 * palette.spacingScale),
        if (!widget.compact)
          _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.tune_rounded, color: palette.secondary, size: 20),
              const SizedBox(width: 7),
              Expanded(child: Text('Consultar programación',
                style: TextStyle(color: palette.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _busy ? null : _load,
                icon: Icon(Icons.refresh_rounded, color: palette.secondary),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(DateFormat('EEE d MMM', 'es_CO').format(_date)),
                ),
                SizedBox(
                  width: isMobile ? constraints.maxWidth - 34 * palette.spacingScale : 215,
                  child: TextField(
                    controller: _leagueController,
                    decoration: const InputDecoration(
                      labelText: 'Liga (opcional)',
                      prefixIcon: Icon(Icons.emoji_events_outlined),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _filter(),
                  ),
                ),
                SizedBox(
                  width: isMobile ? constraints.maxWidth - 34 * palette.spacingScale : 215,
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad o estadio',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _filter(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _filter,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Consultar'),
                ),
                if (_league.isNotEmpty || _city.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      _leagueController.clear();
                      _cityController.clear();
                      _filter();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Limpiar filtros'),
                  ),
              ],
            ),
          ])),
        if (_busy) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(color: palette.secondary),
        ),
        SizedBox(height: 18 * palette.spacingScale),
        _sectionHeading(widget.compact ? 'Encuentros programados' : 'Partidos del día',
            Icons.sports_soccer_outlined, matches.length),
        if (_error != null)
          _surface(child: Row(children: [
            Icon(Icons.wifi_off_outlined, color: palette.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!,
              style: TextStyle(color: palette.textPrimary))),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ])),
        if (_data['errorProgramacion']?.toString().isNotEmpty == true)
          _surface(child: Text(_data['errorProgramacion'].toString(),
            style: TextStyle(color: palette.warning))),
        if (matches.isEmpty && !_busy && _error == null &&
            _data['errorProgramacion']?.toString().isNotEmpty != true)
          _surface(child: Row(children: [
            Icon(Icons.event_busy_outlined, color: palette.textSecondary),
            const SizedBox(width: 11),
            Expanded(child: Text(
              widget.compact
                  ? 'Hoy no hay partidos disponibles en las ligas consultadas.'
                  : 'No hay partidos disponibles para esta fecha en las ligas consultadas.',
              style: TextStyle(color: palette.textSecondary),
            )),
          ])),
        for (final match in matches.take(matchLimit)) ...[
          _matchCard(match),
          const SizedBox(height: 10),
        ],
        if (widget.compact)
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => context.go('/agenda_deportiva'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Ver agenda deportiva completa'),
          )),
        if (widget.compact)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Wrap(spacing: 10, runSpacing: 0, children: [
              TextButton(
                onPressed: () => _open('https://www.openligadb.de/'),
                child: const Text('Fuente: OpenLigaDB'),
              ),
              TextButton(
                onPressed: () => _open('https://opendatacommons.org/licenses/odbl/1-0/'),
                child: const Text('Licencia ODbL 1.0'),
              ),
            ]),
          ),
        if (!widget.compact) ...[
          SizedBox(height: 12 * palette.spacingScale),
          _sectionHeading('Noticias deportivas', Icons.newspaper_rounded, news.length),
          if (news.isEmpty && !_busy)
            _surface(child: Text(
              _data['errorNoticias']?.toString().isNotEmpty == true
                  ? _data['errorNoticias'].toString()
                  : 'Por ahora no hay titulares disponibles.',
              style: TextStyle(color: palette.textSecondary),
            )),
          for (final item in news.take(newsLimit)) ...[
            _newsCard(item),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FUENTES Y COBERTURA',
              style: TextStyle(color: palette.secondary, fontSize: 11,
                  fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Text(
              'Programación comunitaria de fútbol europeo; cobertura parcial y horarios sujetos a cambios. '
              'Las noticias enlazan a sus editores. Confirma los derechos de exhibición en Colombia.',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            Wrap(spacing: 10, children: [
              TextButton(
                onPressed: () => _open('https://www.openligadb.de/'),
                child: const Text('Datos: OpenLigaDB'),
              ),
              TextButton(
                onPressed: () => _open('https://opendatacommons.org/licenses/odbl/1-0/'),
                child: const Text('Licencia ODbL 1.0'),
              ),
            ]),
          ])),
        ],
      ]);
    });
  }
}
