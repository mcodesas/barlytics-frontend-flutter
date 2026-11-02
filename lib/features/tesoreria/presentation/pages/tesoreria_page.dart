import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';

import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';

class TesoreriaPage extends ConsumerStatefulWidget {
  const TesoreriaPage({super.key});
  @override
  ConsumerState<TesoreriaPage> createState() => _TesoreriaPageState();
}

class _TesoreriaPageState extends ConsumerState<TesoreriaPage> {
  int? _branch;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _moves = [], _reconciliations = [];
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 2);

  Map<String, dynamic> _asMap(Object? obj) => obj is Map
      ? Map<String, dynamic>.from(obj) : {};
  List<Map<String, dynamic>> _asList(Object? obj) => obj is List
      ? obj.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
  int? _id(Object? obj) => obj is num ? obj.toInt() : int.tryParse(obj?.toString() ?? '');
  double _num(Object? obj) => obj is num ? obj.toDouble() : double.tryParse(obj?.toString() ?? '') ?? 0;
  String _cop(Object? value) => _currency.format(_num(value));
  List<Map<String, dynamic>> get _accounts => _asList(_summary['medios']);
  List<Map<String, dynamic>> get _ready =>
      _accounts.where((row) => row['configurado'] == true).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branch = ref.read(branchScopeProvider).activeBranchId;
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _branch = branch; });
    if (branch == null) {
      setState(() { _loading = false; _error = 'Selecciona una sucursal.'; });
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final result = await Future.wait([
        api.get<Object?>('/api/v1/tesoreria/resumen', (j) => j,
            queryParameters: {'sucursalId': branch}),
        api.get<Object?>('/api/v1/tesoreria/movimientos', (j) => j,
            queryParameters: {'sucursalId': branch}),
        api.get<Object?>('/api/v1/tesoreria/conciliaciones', (j) => j,
            queryParameters: {'sucursalId': branch}),
      ]);
      if (!mounted || branch != ref.read(branchScopeProvider).activeBranchId) return;
      setState(() {
        _summary = _asMap(result[0].data);
        _moves = _asList(result[1].data);
        _reconciliations = _asList(result[2].data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)));
  }

  Future<bool> _post(String path, Map<String, dynamic> body,
      {Map<String, dynamic>? params}) async {
    try {
      await ref.read(apiClientProvider).post<Object?>(path, body, (j) => j,
          queryParameters: params);
      _notice('Operación registrada.');
      await _load();
      return true;
    } catch (e) {
      _notice('Error al guardar: ' + e.toString());
      return false;
    }
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return s.substring(0, 8) + '-' + s.substring(8, 12) + '-'
        + s.substring(12, 16) + '-' + s.substring(16, 20) + '-'
        + s.substring(20);
  }

  Future<void> _opening(Map<String, dynamic> medium) async {
    final amount = TextEditingController(text: '0');
    final note = TextEditingController();
    var date = DateTime.now();
    try {
      await showDialog<void>(context: context, builder: (ctx) =>
          StatefulBuilder(builder: (ctx, update) => AlertDialog(
        scrollable: true,
        title: Text('Saldo inicial: ' + (medium['nombre']?.toString() ?? 'Medio')),
        content: SizedBox(width: 430, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Text('El saldo es el dinero al comienzo del día seleccionado. '
                'Solo puede establecerse una vez por cuenta; luego usa ajustes auditados.'),
            TextField(controller: amount, keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor inicial en COP')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) update(() => date = d);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Fecha: ' + DateFormat('dd/MM/yyyy').format(date)),
            ),
            TextField(controller: note, maxLength: 300,
              decoration: const InputDecoration(labelText: 'Observación / arqueo')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final value = double.tryParse(amount.text.replaceAll(',', '.'));
            if (value == null || value < 0) { _notice('Valor inválido.'); return; }
            final ok = await _post('/api/v1/tesoreria/aperturas', {
              'sucursalId': _branch, 'medioPagoId': medium['medioPagoId'],
              'fechaInicio': DateFormat('yyyy-MM-dd').format(date),
              'saldoInicial': value, 'observacion': note.text.trim(),
            });
            if (ok && ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('Establecer saldo')),
        ],
      )));
    } finally { amount.dispose(); note.dispose(); }
  }

  Future<void> _movement() async {
    if (_ready.isEmpty) return;
    final amount = TextEditingController(), category = TextEditingController(),
        description = TextEditingController(), reference = TextEditingController();
    const types = {
      'INGRESO_EXTERNO': 'Ingreso externo',
      'EGRESO_EXTERNO': 'Pago / gasto externo',
      'RETIRO': 'Retiro',
      'TRANSFERENCIA': 'Transferencia entre medios',
      'AJUSTE_POSITIVO': 'Ajuste positivo',
      'AJUSTE_NEGATIVO': 'Ajuste negativo',
    };
    var type = 'INGRESO_EXTERNO';
    int? origin, dest = _id(_ready.first['medioPagoId']);
    var requestId = _uuid();
    try {
      await showDialog<void>(context: context, builder: (ctx) =>
          StatefulBuilder(builder: (ctx, local) {
        final sourceNeeded = !{'INGRESO_EXTERNO', 'AJUSTE_POSITIVO'}.contains(type);
        final destNeeded = !{'EGRESO_EXTERNO', 'RETIRO', 'AJUSTE_NEGATIVO'}.contains(type);
        Widget picker(String label, int? value, ValueChanged<int?> change) =>
            DropdownButtonFormField<int>(
              key: ValueKey(label + type),
              value: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [for (final item in _ready) DropdownMenuItem(
                  value: _id(item['medioPagoId']),
                  child: Text(item['nombre']?.toString() ?? 'Medio'))],
              onChanged: change,
            );
        return AlertDialog(
          scrollable: true,
          title: const Text('Movimiento de dinero'),
          content: SizedBox(width: 500, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Registra solo movimientos no incluidos en caja o ventas. '
                  'Un gasto registrado en cierre NO se vuelve a registrar aquí.'),
              DropdownButtonFormField<String>(
                value: type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final e in types.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => local(() {
                  type = v ?? type;
                  origin = type == 'TRANSFERENCIA'
                      ? _id(_ready.first['medioPagoId']) : null;
                  dest = _id(_ready.first['medioPagoId']);
                  requestId = _uuid();
                }),
              ),
              if (sourceNeeded) picker('Origen', origin,
                  (v) => local(() => origin = v)),
              if (destNeeded) picker('Destino', dest,
                  (v) => local(() => dest = v)),
              TextField(controller: amount, keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor COP')),
              TextField(controller: description, maxLength: 300,
                decoration: const InputDecoration(labelText: 'Concepto *')),
              TextField(controller: category, maxLength: 80,
                decoration: const InputDecoration(labelText: 'Categoría')),
              TextField(controller: reference, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Referencia / soporte')),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final value = double.tryParse(amount.text.replaceAll(',', '.'));
              final source = sourceNeeded ? origin : null;
              final target = destNeeded ? dest : null;
              if (value == null || value <= 0 || description.text.trim().isEmpty ||
                  (sourceNeeded && source == null) ||
                  (destNeeded && target == null) ||
                  (type == 'TRANSFERENCIA' && source == target)) {
                _notice('Verifica concepto, valor y origen/destino.'); return;
              }
              final ok = await _post('/api/v1/tesoreria/movimientos', {
                'sucursalId': _branch, 'tipo': type,
                'medioOrigenId': source, 'medioDestinoId': target,
                'importe': value, 'concepto': description.text.trim(),
                'categoria': category.text.trim(),
                'referencia': reference.text.trim(), 'idempotencia': requestId,
              });
              if (ok && ctx.mounted) Navigator.pop(ctx);
            }, child: const Text('Guardar')),
          ],
        );
      }));
    } finally {
      amount.dispose(); category.dispose(); description.dispose(); reference.dispose();
    }
  }

  Future<void> _reconcile(Map<String, dynamic> medium) async {
    final amount = TextEditingController(), note = TextEditingController();
    try {
      final accepted = await showDialog<bool>(context: context, builder: (ctx) =>
          AlertDialog(
        scrollable: true,
        title: Text('Conciliar: ' + (medium['nombre']?.toString() ?? 'Medio')),
        content: SizedBox(width: 420, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Text('Esperado: ' + _cop(medium['saldoEsperado'])),
            TextField(controller: amount, keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Dinero contado / saldo real')),
            TextField(controller: note, maxLength: 300,
              decoration: const InputDecoration(labelText: 'Observación')),
            const Text('La conciliación registra diferencias, sin alterar el saldo automáticamente.'),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Conciliar')),
        ],
      ));
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (accepted == true && value != null && value >= 0) {
        await _post('/api/v1/tesoreria/conciliaciones', {
          'sucursalId': _branch, 'medioPagoId': medium['medioPagoId'],
          'contado': value, 'observacion': note.text.trim(),
        });
      }
    } finally { amount.dispose(); note.dispose(); }
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    try {
      final accepted = await showDialog<bool>(context: context, builder: (ctx) =>
          AlertDialog(scrollable: true,
        title: const Text('Anular movimiento'),
        content: TextField(controller: reason, maxLength: 300,
            decoration: const InputDecoration(labelText: 'Motivo obligatorio')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anular')),
        ],
      ));
      if (accepted != true || reason.text.trim().isEmpty) return;
      await _post('/api/v1/tesoreria/movimientos/' + row['id'].toString() + '/anular',
          {'motivo': reason.text.trim()}, params: {'sucursalId': _branch});
    } finally { reason.dispose(); }
  }

  String _mediumName(Object? raw) {
    final id = _id(raw);
    for (final account in _accounts) {
      if (_id(account['medioPagoId']) == id) {
        return account['nombre']?.toString() ?? 'Medio de pago';
      }
    }
    return id == null ? 'Sin asignar' : 'Medio #' + id.toString();
  }

  String _dateText(Object? raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return 'Sin fecha';
    final normalized = value.replaceAll('T', ' ');
    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  String _typeLabel(String type) => switch (type) {
    'INGRESO_EXTERNO' => 'Ingreso externo',
    'EGRESO_EXTERNO' => 'Pago externo',
    'RETIRO' => 'Retiro',
    'TRANSFERENCIA' => 'Transferencia',
    'AJUSTE_POSITIVO' => 'Ajuste positivo',
    'AJUSTE_NEGATIVO' => 'Ajuste negativo',
    _ => type.replaceAll('_', ' '),
  };

  IconData _typeIcon(String type) => switch (type) {
    'INGRESO_EXTERNO' || 'AJUSTE_POSITIVO' => Icons.south_west_rounded,
    'TRANSFERENCIA' => Icons.swap_horiz_rounded,
    'RETIRO' => Icons.account_balance_wallet_outlined,
    _ => Icons.north_east_rounded,
  };

  Widget _panel(AppPalette palette, Widget child, {
    EdgeInsetsGeometry? padding,
    Color? tint,
  }) {
    return Container(
      padding: padding ?? palette.panelPadding(17),
      decoration: BoxDecoration(
        color: tint ?? palette.surface,
        borderRadius: BorderRadius.circular(palette.radius(20)),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(color: palette.cardShadow, blurRadius: 19,
              offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(AppPalette palette, String label, IconData icon, int count) {
    return Row(children: [
      Container(
        width: 37, height: 37,
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(palette.radius(12)),
        ),
        child: Icon(icon, color: palette.secondary, size: 20),
      ),
      const SizedBox(width: 11),
      Expanded(child: Text(label,
        style: TextStyle(color: palette.textPrimary, fontSize: 18 * palette.fontScale,
            fontWeight: FontWeight.w900))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(count.toString(),
          style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  Widget _detail(AppPalette palette, String title, Object? amount, {
    bool plus = false,
    bool minus = false,
  }) {
    final color = plus ? palette.success : minus ? palette.warning : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(
          color: palette.textSecondary, fontSize: 12 * palette.fontScale,
        ))),
        const SizedBox(width: 8),
        Flexible(child: Text((plus ? '+ ' : minus ? '− ' : '') + _cop(amount),
          textAlign: TextAlign.end,
          style: TextStyle(color: color, fontSize: 12 * palette.fontScale,
              fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _accountCard(AppPalette palette, Map<String, dynamic> account) {
    final configured = account['configurado'] == true;
    final name = account['nombre']?.toString() ?? 'Medio de pago';
    final isCash = name.toLowerCase().contains('efectivo');
    return _panel(palette, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 45, height: 45,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(palette.radius(14)),
          ),
          child: Icon(isCash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
              color: palette.secondary),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.textPrimary,
              fontSize: 16 * palette.fontScale, fontWeight: FontWeight.w800))),
        Icon(configured ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: configured ? palette.success : palette.warning, size: 21),
      ]),
      const SizedBox(height: 16),
      if (configured) ...[
        Text('SALDO CONTABLE ESPERADO',
          style: TextStyle(color: palette.textSecondary, fontSize: 10,
            fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 5),
        Text(_cop(account['saldoEsperado']),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.textPrimary,
            fontSize: 24 * palette.fontScale, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Desde ' + _dateText(account['fechaInicio']),
          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        Divider(color: palette.cardBorder),
        _detail(palette, 'Saldo inicial', account['saldoInicial']),
        _detail(palette, 'Ventas recaudadas', account['ingresosVentas'], plus: true),
        _detail(palette, 'Gastos de caja', account['egresosCaja'], minus: true),
        _detail(palette, 'Ingresos / transferencias', account['ingresosAdicionales'], plus: true),
        _detail(palette, 'Egresos / retiros', account['egresosAdicionales'], minus: true),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _reconcile(account),
          icon: const Icon(Icons.fact_check_rounded, size: 19),
          label: const Text('Conciliar saldo'),
        ),
      ] else ...[
        Text('Aún no tiene saldo inicial',
          style: TextStyle(color: palette.warning, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Establece la fecha y el valor inicial para calcular movimientos.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const Spacer(),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => _opening(account),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Configurar saldo inicial'),
        ),
      ],
    ]));
  }

  Widget _moveCard(AppPalette palette, Map<String, dynamic> row) {
    final type = row['tipo']?.toString() ?? 'Movimiento';
    final active = row['estado'] == 'ACTIVO';
    final inbound = type == 'INGRESO_EXTERNO' || type == 'AJUSTE_POSITIVO';
    final from = _mediumName(row['medio_origen_id']);
    final to = _mediumName(row['medio_destino_id']);
    final payment = type == 'TRANSFERENCIA'
        ? from + ' → ' + to
        : inbound ? to : from;
    return _panel(palette, Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 43, height: 43,
        decoration: BoxDecoration(
          color: (active ? palette.secondary : palette.textSecondary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(palette.radius(12)),
        ),
        child: Icon(_typeIcon(type),
          color: active ? palette.secondary : palette.textSecondary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(_typeLabel(type),
            style: TextStyle(color: palette.textPrimary,
                fontWeight: FontWeight.w900))),
          const SizedBox(width: 6),
          Flexible(child: Text(_cop(row['importe']),
            textAlign: TextAlign.end,
            style: TextStyle(color: active ? palette.textPrimary : palette.textSecondary,
                fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 5),
        Text(row['concepto']?.toString() ?? '',
          style: TextStyle(color: palette.textPrimary, fontSize: 13)),
        const SizedBox(height: 6),
        Text(payment, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        Text(_dateText(row['creado_en']),
          style: TextStyle(color: palette.textSecondary, fontSize: 11)),
        if (!active)
          Text('ANULADO', style: TextStyle(color: palette.warning,
              fontWeight: FontWeight.w900, fontSize: 11)),
      ])),
      if (active)
        IconButton(
          tooltip: 'Anular con motivo y auditoría',
          onPressed: () => _cancel(row),
          icon: Icon(Icons.block_outlined, color: palette.danger, size: 20),
        ),
    ]));
  }

  Widget _reconciliationCard(AppPalette palette, Map<String, dynamic> entry) {
    final diff = _num(entry['diferencia']);
    final color = diff == 0 ? palette.success : palette.warning;
    return _panel(palette, Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 43, height: 43,
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(palette.radius(13)),
        ),
        child: Icon(diff == 0 ? Icons.verified_rounded : Icons.rule_rounded,
          color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_mediumName(entry['medio_pago_id']),
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Diferencia: ' + _cop(diff),
          style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text('Esperado ' + _cop(entry['esperado']) +
            ' · Contado ' + _cop(entry['contado']),
          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        Text(_dateText(entry['creado_en']),
          style: TextStyle(color: palette.textSecondary, fontSize: 11)),
      ])),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final activeBranch = ref.watch(branchScopeProvider).activeBranchId;
    if (activeBranch != _branch && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final configuredCount = _ready.length;
    final allCount = _accounts.length;
    final total = _cop(_summary['totalEsperadoConfigurados']);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: RefreshIndicator(
          color: palette.secondary,
          onRefresh: _load,
          child: LayoutBuilder(builder: (context, layout) {
            final mobile = layout.maxWidth < 650;
            final columns = layout.maxWidth >= 1040 ? 3 : layout.maxWidth >= 690 ? 2 : 1;
            final spacing = 13.0 * palette.spacingScale;
            final cardWidth = (layout.maxWidth - 32 - (columns - 1) * spacing) / columns;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16 * palette.spacingScale),
              children: [
                Container(
                  padding: EdgeInsets.all((mobile ? 18 : 24) * palette.spacingScale),
                  decoration: BoxDecoration(
                    gradient: palette.mainGradient,
                    borderRadius: BorderRadius.circular(palette.radius(24)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(palette.radius(15)),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: palette.onPrimary, size: 29),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CONTROL FINANCIERO',
                        style: TextStyle(color: palette.onPrimary.withOpacity(0.8),
                            fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('Tesorería por medio de pago',
                        style: TextStyle(color: palette.onPrimary,
                          fontSize: (mobile ? 20 : 26) * palette.fontScale,
                          fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Text('Controla saldos esperados, transferencias, retiros y conciliaciones.',
                        style: TextStyle(color: palette.onPrimary.withOpacity(0.92),
                          fontSize: 12 * palette.fontScale)),
                    ])),
                    IconButton(
                      tooltip: 'Actualizar saldos',
                      onPressed: _loading ? null : _load,
                      icon: Icon(Icons.refresh_rounded, color: palette.onPrimary),
                    ),
                  ]),
                ),
                if (_loading) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(color: palette.secondary),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _panel(palette, Row(children: [
                    Icon(Icons.error_outline_rounded, color: palette.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: palette.textPrimary))),
                    TextButton(onPressed: _load, child: const Text('Reintentar')),
                  ])),
                ],
                const SizedBox(height: 14),
                _panel(palette, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 18, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('TOTAL CONTABLE ESPERADO',
                          style: TextStyle(color: palette.textSecondary, fontSize: 11,
                            fontWeight: FontWeight.w900, letterSpacing: 0.9)),
                        const SizedBox(height: 4),
                        Text(total, style: TextStyle(
                          color: palette.textPrimary, fontWeight: FontWeight.w900,
                          fontSize: (mobile ? 26 : 34) * palette.fontScale)),
                        const SizedBox(height: 4),
                        Text(allCount == 0
                          ? 'No hay medios de pago disponibles en esta sucursal'
                          : _summary['todosConfigurados'] == true
                            ? 'Saldos de todos los medios configurados'
                            : 'Total parcial: hay medios sin saldo inicial',
                          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(palette.radius(15)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.account_balance_outlined,
                            color: palette.secondary, size: 19),
                          const SizedBox(width: 8),
                          Text(configuredCount.toString() + ' / ' + allCount.toString() + ' configurados',
                            style: TextStyle(color: palette.textPrimary,
                              fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text('Estos valores son cálculos contables. No representan una certificación bancaria.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                ])),
                if (_num(_summary['egresosSinMedioHistoricos']) > 0) ...[
                  const SizedBox(height: 12),
                  _panel(palette, Row(children: [
                    Icon(Icons.warning_amber_rounded, color: palette.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Hay egresos antiguos sin medio asignado por ' +
                      _cop(_summary['egresosSinMedioHistoricos']) +
                      '. No se distribuyen automáticamente entre cuentas.',
                      style: TextStyle(color: palette.textPrimary, fontSize: 12))),
                  ])),
                ],
                const SizedBox(height: 24),
                _sectionTitle(palette, 'Saldos por medio', Icons.account_balance_wallet_outlined, allCount),
                const SizedBox(height: 12),
                if (_accounts.isEmpty && !_loading)
                  _panel(palette, Text(
                    'Configura medios de pago en la sucursal para comenzar a registrar los saldos.',
                    style: TextStyle(color: palette.textSecondary))),
                if (_accounts.isNotEmpty)
                  Wrap(spacing: spacing, runSpacing: spacing, children: [
                    for (final account in _accounts)
                      SizedBox(width: cardWidth, child: _accountCard(palette, account)),
                  ]),
                const SizedBox(height: 21),
                Wrap(spacing: 12, runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: mobile ? layout.maxWidth - 32 : 320,
                      child: _sectionTitle(palette, 'Movimientos de dinero',
                        Icons.swap_horiz_rounded, _moves.length),
                    ),
                    FilledButton.icon(
                      onPressed: _ready.isEmpty ? null : _movement,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Registrar movimiento'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_moves.isEmpty)
                  _panel(palette, Text(
                    'Todavía no hay ingresos externos, retiros, ajustes ni transferencias manuales.',
                    style: TextStyle(color: palette.textSecondary))),
                for (final row in _moves) ...[
                  _moveCard(palette, row),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 19),
                _sectionTitle(palette, 'Conciliaciones', Icons.fact_check_outlined,
                    _reconciliations.length),
                const SizedBox(height: 12),
                if (_reconciliations.isEmpty)
                  _panel(palette, Text(
                    'Aún no se han realizado conciliaciones de los medios de pago.',
                    style: TextStyle(color: palette.textSecondary))),
                for (final entry in _reconciliations.take(12)) ...[
                  _reconciliationCard(palette, entry),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 56),
              ],
            );
          }),
        ),
      )),
    );
  }
}
