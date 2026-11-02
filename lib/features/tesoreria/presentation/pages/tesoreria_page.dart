import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);

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

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(branchScopeProvider).activeBranchId;
    if (selected != _branch && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(onRefresh: _load, child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tesorería · Dinero por medio',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Saldo inicial + recaudos de ventas + ingresos externos '
              '− egresos de caja − retiros y transferencias. '
              'No representa una certificación bancaria.'),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
          if (_summary.isNotEmpty) ...[
            Card(child: ListTile(
              title: const Text('Total esperado de medios configurados'),
              subtitle: Text(_summary['todosConfigurados'] == true
                  ? 'Saldos de todos los medios activos'
                  : 'Total parcial: falta configurar saldos iniciales'),
              trailing: Text(_cop(_summary['totalEsperadoConfigurados']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            )),
            if (_num(_summary['egresosSinMedioHistoricos']) > 0)
              Text('Egresos antiguos sin medio asignado: ' +
                  _cop(_summary['egresosSinMedioHistoricos']) +
                  '. No se descuentan de ninguna cuenta automáticamente.'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _ready.isEmpty ? null : _movement,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Registrar movimiento')),
            ),
            const SizedBox(height: 10),
            for (final account in _accounts) Card(
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(account['nombre']?.toString() ?? 'Medio de pago',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  if (account['configurado'] != true) ...[
                    const Text('No se ha fijado el saldo inicial.'),
                    OutlinedButton(onPressed: () => _opening(account),
                        child: const Text('Configurar saldo inicial')),
                  ] else ...[
                    Text('Esperado: ' + _cop(account['saldoEsperado']),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                    Text('Desde ' + account['fechaInicio'].toString() +
                        ' · Inicial ' + _cop(account['saldoInicial'])),
                    Text('Ventas +' + _cop(account['ingresosVentas']) +
                        ' · Caja -' + _cop(account['egresosCaja'])),
                    Text('Adicionales +' + _cop(account['ingresosAdicionales']) +
                        ' · Egresos/retiros -' + _cop(account['egresosAdicionales'])),
                    OutlinedButton.icon(onPressed: () => _reconcile(account),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Conciliar saldo')),
                  ],
                ],
              )),
            ),
          ],
          const SizedBox(height: 18),
          const Text('Movimientos manuales', style:
              TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          if (_moves.isEmpty) const Text('Sin operaciones adicionales.'),
          for (final row in _moves) Card(child: ListTile(
            title: Text((row['tipo']?.toString() ?? 'Movimiento') + ' · ' +
                _cop(row['importe'])),
            subtitle: Text((row['concepto']?.toString() ?? '') + ' · ' +
                (row['estado']?.toString() ?? '') + '\n' +
                (row['creado_en']?.toString() ?? '')),
            isThreeLine: true,
            trailing: row['estado'] == 'ACTIVO'
                ? IconButton(tooltip: 'Anular conservando auditoría',
                    onPressed: () => _cancel(row),
                    icon: const Icon(Icons.block_outlined))
                : const Icon(Icons.history),
          )),
          const SizedBox(height: 18),
          const Text('Historial de conciliaciones', style:
              TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          for (final entry in _reconciliations.take(12)) ListTile(
            title: Text('Diferencia ' + _cop(entry['diferencia'])),
            subtitle: Text('Medio #' + entry['medio_pago_id'].toString() +
                ' · Esperado ' + _cop(entry['esperado']) +
                ' / Contado ' + _cop(entry['contado'])),
          ),
          const SizedBox(height: 55),
        ],
      )),
    );
  }
}
