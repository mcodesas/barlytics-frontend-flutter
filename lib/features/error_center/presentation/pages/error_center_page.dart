import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../../core/telemetry/error_telemetry.dart';
import '../../data/error_center_repository.dart';
import '../widgets/error_issue_detail_dialog.dart';

/// Dashboard interno protegido por el router y por Spring Security.
class ErrorCenterPage extends ConsumerStatefulWidget {
  const ErrorCenterPage({super.key});

  @override
  ConsumerState<ErrorCenterPage> createState() => _ErrorCenterPageState();
}

class _ErrorCenterPageState extends ConsumerState<ErrorCenterPage> {
  final _search = TextEditingController();
  final _company = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefresh;
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _result = {};
  bool _loading = true;
  String? _error;
  String _status = '';
  String _severity = '';
  String _platform = '';
  String _origin = '';
  String _category = '';
  int _page = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(minutes: 3), (_) {
      if (mounted && !_loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoRefresh?.cancel();
    _search.dispose();
    _company.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _load(resetPage: true);
    });
  }

  Future<void> _load({bool resetPage = false, bool silent = false}) async {
    if (resetPage) _page = 0;
    final sequence = ++_request;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = ref.read(errorCenterRepositoryProvider);
      final result = await Future.wait<Map<String, dynamic>>([
        api.metrics(),
        api.issues(
          status: _status,
          severity: _severity,
          platform: _platform,
          origin: _origin,
          category: _category,
          search: _search.text,
          companyId: int.tryParse(_company.text.trim()),
          page: _page,
        ),
      ]);
      if (!mounted || sequence != _request) return;
      setState(() {
        _metrics = result[0];
        _result = result[1];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || sequence != _request) return;
      setState(() {
        _loading = false;
        _error = 'No fue posible consultar el monitoreo: ' + error.toString();
      });
    }
  }

  void _clear() {
    _search.clear();
    _company.clear();
    _status = '';
    _severity = '';
    _platform = '';
    _origin = '';
    _category = '';
    _load(resetPage: true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final issues = ErrorCenterRepository.rows(_result['items']);
    final total = ErrorCenterRepository.number(_result['total']);
    final metrics = <(String, String, IconData)>[
      ('Incidencias', 'total', Icons.bug_report_rounded),
      ('Por resolver', 'open', Icons.pending_actions_rounded),
      ('Críticas', 'critical', Icons.priority_high_rounded),
      ('Ocurrencias ~24 h', 'recentOccurrences', Icons.query_stats_rounded),
      ('Empresas afectadas', 'affectedCompanies', Icons.business_rounded),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _PageWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: TechGlassPanel(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TechBrandMark(
                                icon: Icons.monitor_heart_rounded, size: 50),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('MONITOREO CENTRALIZADO',
                                    style: TextStyle(color: palette.secondary,
                                      fontSize: 10, fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2)),
                                  Text('Centro de errores',
                                    style: Theme.of(context).textTheme.headlineSmall
                                        ?.copyWith(color: palette.textPrimary,
                                          fontWeight: FontWeight.w900)),
                                  Text('Trazas, dispositivos, versiones y posibles causas.',
                                    style: TextStyle(color: palette.textSecondary,
                                      fontSize: 12)),
                                ],
                              )),
                              IconButton(
                                tooltip: 'Enviar evento de prueba desde este dispositivo',
                                onPressed: () async {
                                  final ok = await ErrorTelemetry.instance
                                      .sendDiagnostic();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok
                                      ? 'Evento de prueba recibido por el backend.'
                                      : 'No se pudo enviar la prueba. Comprueba sesión y conectividad.')));
                                  if (ok) _load(silent: true);
                                },
                                icon: const Icon(Icons.science_rounded),
                              ),
                              IconButton(
                                tooltip: 'Enviar evento de prueba',
                                onPressed: () async {
                                  final ok = await ErrorTelemetry.instance.sendDiagnostic();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(ok
                                      ? 'Evento de diagnóstico aceptado. Actualiza las incidencias.'
                                      : 'El servidor rechazó la prueba o no hay sesión activa.'),
                                  ));
                                  if (ok) _load(silent: true);
                                },
                                icon: const Icon(Icons.science_outlined),
                              ),
                              IconButton(
                                tooltip: 'Actualizar incidencias',
                                onPressed: () => _load(),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              for (final m in metrics)
                                Container(
                                  width: 165,
                                  padding: const EdgeInsets.all(13),
                                  decoration: palette.panelDecoration(
                                    baseRadius: 16, tint: palette.secondary,
                                    elevated: false),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(m.$3, color: palette.secondary),
                                      const SizedBox(height: 7),
                                      Text(ErrorCenterRepository.number(
                                            _metrics[m.$2]).toString(),
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900)),
                                      Text(m.$1, style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(minHeight: 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PageWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: palette.panelDecoration(
                          baseRadius: 21, tint: palette.primary,
                          elevated: false),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Origen del error',
                            style: TextStyle(color: palette.textPrimary,
                              fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 9, runSpacing: 9, children: [
                            for (final source in const <(String, String, IconData)>[
                              ('', 'Todos', Icons.layers_rounded),
                              ('flutter', 'Aplicaciones · Frontend', Icons.devices_rounded),
                              ('backend', 'Servidor · Backend', Icons.dns_rounded),
                            ])
                              ChoiceChip(
                                avatar: Icon(source.$3, size: 17),
                                label: Text(source.$2),
                                selected: _origin == source.$1,
                                onSelected: (_) {
                                  setState(() {
                                    _origin = source.$1;
                                    _platform = '';
                                    _category = '';
                                  });
                                  _load(resetPage: true);
                                },
                              ),
                          ]),
                          const SizedBox(height: 15),
                          Text('Filtros y búsqueda',
                            style: TextStyle(color: palette.textPrimary,
                              fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _search,
                            maxLength: 80,
                            onChanged: (_) => _scheduleSearch(),
                            decoration: const InputDecoration(
                              labelText: 'Clase, módulo, ruta o descripción',
                              prefixIcon: Icon(Icons.search_rounded),
                              counterText: ''),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(builder: (context, constraints) {
                            final width = constraints.maxWidth < 680
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 3;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _Filter(
                                  width: width,
                                  label: 'Estado',
                                  value: _status,
                                  choices: const {
                                    '': 'Todos',
                                    'OPEN': 'Pendientes',
                                    'INVESTIGATING': 'Investigando',
                                    'RESOLVED': 'Resueltos',
                                    'IGNORED': 'Ignorados',
                                  },
                                  onChanged: (value) {
                                    setState(() => _status = value);
                                    _load(resetPage: true);
                                  }),
                                _Filter(
                                  width: width,
                                  label: 'Gravedad',
                                  value: _severity,
                                  choices: const {
                                    '': 'Todas',
                                    'CRITICAL': 'Críticas',
                                    'ERROR': 'Errores',
                                    'WARNING': 'Advertencias',
                                  },
                                  onChanged: (value) {
                                    setState(() => _severity = value);
                                    _load(resetPage: true);
                                  }),
                                _Filter(
                                  width: width,
                                  label: 'Tipo de problema',
                                  value: _category,
                                  choices: const {
                                    '': 'Todos los tipos',
                                    'layout': 'Interfaz y desbordamientos',
                                    'flutter_framework': 'Flutter framework',
                                    'uncaught': 'Excepciones no controladas',
                                    'network': 'Conectividad',
                                    'http_5xx': 'HTTP 5xx del cliente',
                                    'handled_http_5xx': 'HTTP 5xx controlados',
                                    'handled_unexpected': 'Fallos inesperados',
                                    'http_500': 'Excepciones del servidor',
                                    'error_log': 'Tareas internas del servidor',
                                    'diagnostic': 'Pruebas de diagnóstico',
                                  },
                                  onChanged: (value) {
                                    setState(() => _category = value);
                                    _load(resetPage: true);
                                  }),
                                _Filter(
                                  width: width,
                                  label: 'Plataforma',
                                  value: _platform,
                                  choices: const {
                                    '': 'Todas',
                                    'web': 'Web',
                                    'windows': 'Windows',
                                    'android': 'Android',
                                    'ios': 'iOS',
                                    'macos': 'macOS',
                                    'linux': 'Linux',
                                    'server': 'Servidor',
                                  },
                                  onChanged: (value) {
                                    setState(() => _platform = value);
                                    _load(resetPage: true);
                                  }),
                                SizedBox(
                                  width: width,
                                  child: TextField(
                                    controller: _company,
                                    keyboardType: TextInputType.number,
                                    maxLength: 12,
                                    onChanged: (_) => _scheduleSearch(),
                                    decoration: const InputDecoration(
                                      labelText: 'ID de empresa (opcional)',
                                      counterText: '',
                                      prefixIcon: Icon(Icons.business))),
                                ),
                                TextButton.icon(
                                  onPressed: _clear,
                                  icon: const Icon(Icons.filter_alt_off_rounded),
                                  label: const Text('Limpiar filtros')),
                              ],
                            );
                          }),
                          const SizedBox(height: 10),
                          Text(
                            'Los diagnósticos son hipótesis, no causas confirmadas. '
                            'Los eventos idénticos se agrupan y se conservan '
                            'muestras técnicas limitadas.',
                            style: TextStyle(color: palette.textSecondary,
                              height: 1.35, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PageWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in ErrorCenterRepository.rows(_metrics['platforms']))
                          Chip(
                            avatar: Icon(Icons.devices_other_rounded,
                              size: 16, color: palette.secondary),
                            label: Text((item['platform']?.toString() ?? 'Otro') +
                              ': ' + (item['occurrences']?.toString() ?? '0')),
                          ),
                        for (final item in ErrorCenterRepository.rows(_metrics['categories']).take(6))
                          Chip(
                            avatar: Icon(Icons.sell_outlined,
                              size: 16, color: palette.secondary),
                            label: Text((item['category']?.toString() ?? 'Otra') +
                              ': ' + (item['occurrences']?.toString() ?? '0')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PageWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: Text('Incidencias encontradas: ' + total.toString(),
                      style: TextStyle(color: palette.textPrimary,
                        fontSize: 15, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(
                      color: Colors.red)),
                  ),
                ),
              if (issues.isEmpty && !_loading)
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(
                    'No hay incidencias para estos filtros.',
                    style: TextStyle(color: palette.textSecondary))),
                ))
              else
                SliverList(delegate: SliverChildBuilderDelegate(
                  (context, index) => _PageWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 6),
                      child: _IssueCard(
                        issue: issues[index],
                        palette: palette,
                        onTap: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => ErrorIssueDetailDialog(
                              id: ErrorCenterRepository.number(
                                  issues[index]['id']),
                              onChanged: () => _load(silent: true),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  childCount: issues.length,
                )),
              SliverToBoxAdapter(
                child: _PageWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                    child: Row(
                      children: [
                        Text('Página ' + (_page + 1).toString(),
                          style: TextStyle(color: palette.textSecondary)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: _page == 0 ? null : () {
                            _page--;
                            _load();
                          },
                          icon: const Icon(Icons.chevron_left_rounded)),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: (_page + 1) * 25 >= total ? null : () {
                            _page++;
                            _load();
                          },
                          icon: const Icon(Icons.chevron_right_rounded)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: child),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({required this.width, required this.label,
    required this.value, required this.choices, required this.onChanged});
  final double width;
  final String label;
  final String value;
  final Map<String, String> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in choices.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue, required this.palette,
      required this.onTap});
  final Map<String, dynamic> issue;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severity = issue['severity']?.toString() ?? 'ERROR';
    final color = severity == 'CRITICAL'
        ? Colors.redAccent
        : severity == 'WARNING' ? Colors.orange : palette.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: palette.panelDecoration(
              baseRadius: 21, tint: color, elevated: false),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.13),
                child: Icon(Icons.bug_report_rounded, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 9, runSpacing: 6, children: [
                    Text(severity + ' · ' +
                        (issue['status']?.toString() ?? 'OPEN'),
                      style: TextStyle(color: color,
                        fontWeight: FontWeight.w900, fontSize: 11)),
                    Text(ErrorCenterRepository.number(
                            issue['occurrences']).toString() +
                            ' ocurrencias',
                        style: TextStyle(color: palette.textSecondary,
                            fontSize: 11)),
                    Text('ID ' + issue['id'].toString(),
                        style: TextStyle(color: palette.textSecondary,
                            fontSize: 11)),
                  ]),
                  const SizedBox(height: 7),
                  Text(issue['title']?.toString() ?? 'Error sin título',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary,
                      fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(
                    (issue['module']?.toString() ?? '') + ' · ' +
                    (issue['route']?.toString() ?? '') + ' · ' +
                    (issue['platform']?.toString() ?? '') + ' · Empresa ' +
                    (issue['empresaId']?.toString() ?? 'global'),
                    style: TextStyle(color: palette.textSecondary,
                      fontSize: 11)),
                  const SizedBox(height: 8),
                  Text('Posible causa: ' +
                      (issue['suggestedCause']?.toString() ?? 'Revisar traza'),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary,
                      fontSize: 11)),
                  Text('Última detección: ' +
                      (issue['lastSeen']?.toString() ?? '—'),
                    style: TextStyle(color: palette.textSecondary,
                      fontSize: 10.5)),
                ],
              )),
              Icon(Icons.chevron_right_rounded,
                color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
