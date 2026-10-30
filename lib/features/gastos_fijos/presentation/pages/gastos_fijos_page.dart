import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

class GastosFijosPage extends ConsumerStatefulWidget {
  const GastosFijosPage({super.key});

  @override
  ConsumerState<GastosFijosPage> createState() => _GastosFijosPageState();
}

class _GastosFijosPageState extends ConsumerState<GastosFijosPage> {
  final TextEditingController search = TextEditingController();
  final NumberFormat money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String filter = 'TODOS';
  double laborToday = 0;
  double laborMonthly = 0;
  int laborCargoCount = 0;
  bool laborSummaryError = false;

  static const _categories = <String>[
    'Arriendo',
    'Servicios',
    'Mano de obra',
    'Internet',
    'Seguridad',
    'Contabilidad',
    'Mantenimiento',
    'Licencias',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  List<Map<String, dynamic>> _parseMapList(Object? json) {
    if (json is! List) return <Map<String, dynamic>>[];
    return json
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadLaborSummary(Map<String, dynamic>? laborExpense) async {
    if (laborExpense == null || !mounted) {
      if (mounted) {
        setState(() {
          laborToday = 0;
          laborMonthly = 0;
          laborCargoCount = 0;
          laborSummaryError = false;
        });
      }
      return;
    }

    final api = ref.read(apiClientProvider);
    try {
      final expenseId = laborExpense['gafiId'];
      final cargoResponse = await api.get<List<Map<String, dynamic>>>(
        '/api/v1/gastos-fijos/$expenseId/cargos',
        _parseMapList,
      );
      final cargos = cargoResponse.data ?? <Map<String, dynamic>>[];
      final rateResponse = await api.get<List<Map<String, dynamic>>>(
        '/api/v1/gastos-fijos/$expenseId/tarifas',
        _parseMapList,
      );
      final ratesByCargo = <String, List<Map<String, dynamic>>>{};
      for (final rate in rateResponse.data ?? <Map<String, dynamic>>[]) {
        final id = rate['gafcId']?.toString() ?? '';
        if (id.isNotEmpty) ratesByCargo.putIfAbsent(id, () => []).add(rate);
      }

      final today = DateTime.now();
      final lastDay = DateTime(today.year, today.month + 1, 0).day;
      var todayTotal = 0.0;
      var monthTotal = 0.0;
      // Incluir también el costo histórico de cargos hoy inactivos.
      for (final rateList in ratesByCargo.values) {
        todayTotal += costoManoObraEnFecha(rateList, today);
        for (var day = 1; day <= lastDay; day++) {
          monthTotal += costoManoObraEnFecha(
              rateList, DateTime(today.year, today.month, day));
        }
      }

      if (!mounted) return;
      setState(() {
        laborToday = todayTotal;
        laborMonthly = monthTotal;
        laborCargoCount = cargos.length;
        laborSummaryError = false;
      });
    } catch (error) {
      debugPrint('Error calculando resumen de mano de obra: $error');
      if (!mounted) return;
      setState(() {
        // Un fallo HTTP no significa que el costo real sea cero.
        laborSummaryError = true;
      });
      _message('No se pudo consultar el costo de mano de obra. Reintenta actualizar.', error: true);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          items = [];
          laborToday = 0;
          laborMonthly = 0;
          laborCargoCount = 0;
          laborSummaryError = false;
          loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => loading = true);
    try {
      final response =
          await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
                '/api/v1/gastos-fijos/sucursal/$branchId',
                _parseMapList,
              );

      if (!mounted) return;
      final loadedItems = response.data ?? <Map<String, dynamic>>[];
      setState(() {
        items = loadedItems;
      });

      Map<String, dynamic>? laborExpense;
      for (final item in loadedItems) {
        if (_isLabor(item)) {
          laborExpense = item;
          break;
        }
      }
      await _loadLaborSummary(laborExpense);
    } catch (_) {
      _message('No fue posible cargar los gastos de la sucursal.', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _monthlyEquivalent(Map<String, dynamic> item) {
    if (_isLabor(item)) return 0;
    final value = _number(item['gafiValor']);
    switch (item['gafiPeriodicidad']?.toString().toUpperCase()) {
      case 'DIARIO':
        return value * 30.4375;
      case 'SEMANAL':
        return value * (30.4375 / 7);
      case 'QUINCENAL':
        return value * (30.4375 / 15);
      case 'ANUAL':
        return value / 12;
      case 'MENSUAL':
      default:
        return value;
    }
  }

  bool _isLabor(Map<String, dynamic> item) =>
      item['gafiCategoria']?.toString().trim().toLowerCase() == 'mano de obra';

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      _message('Selecciona una sucursal antes de registrar gastos.', error: true);
      return;
    }

    final name = TextEditingController(
      text: current?['gafiNombre']?.toString() ?? '',
    );
    final value = TextEditingController(
      text: current?['gafiValor']?.toString() ?? '',
    );
    final note = TextEditingController(
      text: current?['gafiObservacion']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final categories = [..._categories];
    String category = current?['gafiCategoria']?.toString() ?? 'Otros';
    if (!categories.contains(category)) categories.add(category);

    String type = current?['gafiTipo']?.toString() ?? 'FIJO';
    String period = current?['gafiPeriodicidad']?.toString() ?? 'MENSUAL';
    DateTime startDate = DateTime.tryParse(
          current?['gafiFechaInicio']?.toString() ?? '',
        ) ??
        DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final labor = category == 'Mano de obra';
          if (labor) type = 'VARIABLE';

          return AlertDialog(
            title: Text(current == null ? 'Nuevo gasto' : 'Editar gasto'),
            content: SizedBox(
              width: math.min(MediaQuery.sizeOf(ctx).width * .86, 600),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del gasto',
                          prefixIcon: Icon(Icons.edit_note_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa un nombre.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories
                            .map(
                              (x) => DropdownMenuItem(
                                value: x,
                                child: Text(x),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() {
                            category = v;
                            if (category == 'Mano de obra') {
                              type = 'VARIABLE';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          prefixIcon: Icon(Icons.tune_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FIJO',
                            child: Text('Fijo · valor recurrente'),
                          ),
                          DropdownMenuItem(
                            value: 'VARIABLE',
                            child: Text('Variable · valor estimado'),
                          ),
                        ],
                        onChanged: labor
                            ? null
                            : (v) {
                                if (v != null) {
                                  setDialogState(() => type = v);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      if (labor)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'La mano de obra no usa un valor fijo aquí. '
                            'Después podrás definir cargos y tarifas por día de la semana.',
                          ),
                        )
                      else
                        TextFormField(
                          controller: value,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: type == 'FIJO'
                                ? 'Valor recurrente'
                                : 'Valor estimado',
                            prefixIcon:
                                const Icon(Icons.payments_outlined),
                          ),
                          validator: (v) {
                            final raw = (v ?? '')
                                .replaceAll('.', '')
                                .replaceAll(',', '.');
                            final amount = double.tryParse(raw);
                            if (amount == null || amount < 0) {
                              return 'Ingresa un valor válido.';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: period,
                        decoration: const InputDecoration(
                          labelText: 'Periodicidad',
                          prefixIcon: Icon(Icons.event_repeat_outlined),
                        ),
                        items: const {
                          'DIARIO': 'Diario',
                          'SEMANAL': 'Semanal',
                          'QUINCENAL': 'Quincenal',
                          'MENSUAL': 'Mensual',
                          'ANUAL': 'Anual',
                        }
                            .entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => period = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => startDate = selected);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Vigente desde',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(startDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: note,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'Observación',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;

    final savedName = name.text.trim();
    final savedNote = note.text.trim();
    final rawValue = value.text.replaceAll('.', '').replaceAll(',', '.');
    final savedValue =
        category == 'Mano de obra' ? 0.0 : (double.tryParse(rawValue) ?? 0.0);

    final body = <String, dynamic>{
      'sucuId': branchId,
      'gafiNombre': savedName,
      'gafiCategoria': category,
      'gafiValor': savedValue,
      'gafiPeriodicidad': period,
      'gafiFechaInicio': DateFormat('yyyy-MM-dd').format(startDate),
      'gafiEstado': 1,
      'gafiTipo': category == 'Mano de obra' ? 'VARIABLE' : type,
      'gafiObservacion': savedNote,
    };

    try {
      final api = ref.read(apiClientProvider);
      if (current == null) {
        await api.post<Object?>('/api/v1/gastos-fijos', body, (json) => json);
      } else {
        await api.put<Object?>(
          '/api/v1/gastos-fijos/${current['gafiId']}',
          body,
          (json) => json,
        );
      }
      await _load();
      _message(current == null ? 'Gasto creado.' : 'Gasto actualizado.');
    } catch (_) {
      _message('No fue posible guardar el gasto.', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Desactivar gasto'),
        content: Text(
          '¿Deseas desactivar "${item['gafiNombre'] ?? 'este gasto'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(apiClientProvider)
          .delete<Object?>('/api/v1/gastos-fijos/${item['gafiId']}', (json) => json);
      await _load();
      _message('Gasto desactivado.');
    } catch (_) {
      _message('No fue posible desactivar el gasto.', error: true);
    }
  }

  Future<Map<String, dynamic>?> _ensureLaborExpense() async {
    for (final item in items) {
      if (_isLabor(item)) return item;
    }

    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return null;

    try {
      await ref.read(apiClientProvider).post<Object?>(
        '/api/v1/gastos-fijos',
        {
          'sucuId': branchId,
          'gafiNombre': 'Mano de obra',
          'gafiCategoria': 'Mano de obra',
          'gafiValor': 0,
          'gafiPeriodicidad': 'MENSUAL',
          'gafiFechaInicio': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'gafiEstado': 1,
          'gafiTipo': 'VARIABLE',
          'gafiObservacion': 'Costo calculado por cargo y día trabajado.',
        },
        (json) => json,
      );
      await _load();
      for (final item in items) {
        if (_isLabor(item)) return item;
      }
    } catch (_) {
      _message(
        'No fue posible preparar la configuración de mano de obra.',
        error: true,
      );
    }
    return null;
  }

  Future<void> _labor() async {
    final expense = await _ensureLaborExpense();
    if (expense == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LaborDialog(
        gasto: expense,
        palette: ref.read(selectedAppPaletteProvider),
        api: ref.read(apiClientProvider),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final q = search.text.trim().toLowerCase();

    final visible = items.where((item) {
      final type = item['gafiTipo']?.toString() ?? 'FIJO';
      if (filter == 'FIJOS' && type != 'FIJO') return false;
      if (filter == 'VARIABLES' &&
          (type != 'VARIABLE' || _isLabor(item))) {
        return false;
      }
      if (filter == 'MANO_OBRA' && !_isLabor(item)) return false;

      final haystack =
          '${item['gafiNombre'] ?? ''} ${item['gafiCategoria'] ?? ''}'
              .toLowerCase();
      return q.isEmpty || haystack.contains(q);
    }).toList();

    final fixedMonthly = items
        .where((e) => (e['gafiTipo'] ?? 'FIJO') == 'FIJO')
        .fold<double>(0, (sum, e) => sum + _monthlyEquivalent(e));

    final variableMonthly = items
        .where((e) => (e['gafiTipo'] ?? 'FIJO') == 'VARIABLE' && !_isLabor(e))
        .fold<double>(0, (sum, e) => sum + _monthlyEquivalent(e));

    final hasLabor = items.any(_isLabor);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _load,
          color: palette.secondary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _wrap(
                  _Header(
                    palette: palette,
                    onAdd: () => _edit(),
                    onLabor: _labor,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _wrap(
                  _Summary(
                    palette: palette,
                    fixed: fixedMonthly,
                    variable: variableMonthly,
                    hasLabor: hasLabor,
                    laborToday: laborToday,
                    laborMonthly: laborMonthly,
                    laborCargoCount: laborCargoCount,
                    laborSummaryError: laborSummaryError,
                    money: money,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _wrap(
                  _Toolbar(
                    palette: palette,
                    search: search,
                    filter: filter,
                    onSearch: (_) => setState(() {}),
                    onFilter: (v) => setState(() => filter = v),
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppLoader()),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        items.isEmpty
                            ? 'Aún no hay gastos registrados.'
                            : 'No hay gastos para este filtro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final item = visible[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _wrap(
                          _Expense(
                            item: item,
                            palette: palette,
                            money: money,
                            onEdit: () => _edit(item),
                            onDelete: () => _delete(item),
                            onLabor: _isLabor(item) ? _labor : null,
                            laborToday:
                                _isLabor(item) ? laborToday : null,
                            laborMonthly:
                                _isLabor(item) ? laborMonthly : null,
                            laborCargoCount:
                                _isLabor(item) ? laborCargoCount : null,
                            laborSummaryError:
                                _isLabor(item) && laborSummaryError,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrap(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: child,
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;
  final VoidCallback onLabor;

  const _Header({
    required this.palette,
    required this.onAdd,
    required this.onLabor,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          final narrow = constraints.maxWidth < 720;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gastos del negocio',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Controla costos fijos, variables y mano de obra para calcular mejor la utilidad.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onLabor,
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('Mano de obra'),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo gasto'),
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      );
}

class _Summary extends StatelessWidget {
  final AppPalette palette;
  final double fixed;
  final double variable;
  final bool hasLabor;
  final double laborToday;
  final double laborMonthly;
  final int laborCargoCount;
  final bool laborSummaryError;
  final NumberFormat money;

  const _Summary({
    required this.palette,
    required this.fixed,
    required this.variable,
    required this.hasLabor,
    required this.laborToday,
    required this.laborMonthly,
    required this.laborCargoCount,
    required this.laborSummaryError,
    required this.money,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          final cards = [
            _SummaryCard(
              palette: palette,
              icon: Icons.lock_outline,
              label: 'Fijos · mensual aprox.',
              value: money.format(fixed),
            ),
            _SummaryCard(
              palette: palette,
              icon: Icons.tune,
              label: 'Variables · mensual aprox.',
              value: money.format(variable),
            ),
            _SummaryCard(
              palette: palette,
              icon: Icons.groups_2_outlined,
              label: 'Mano de obra · hoy',
              value: !hasLabor
                  ? 'Sin configurar'
                  : laborSummaryError
                      ? 'No disponible'
                      : money.format(laborToday),
              subtitle: !hasLabor
                  ? null
                  : laborSummaryError
                      ? 'No se pudieron consultar las tarifas'
                      : '${money.format(laborMonthly)} / mes actual · '
                          '$laborCargoCount cargo${laborCargoCount == 1 ? '' : 's'}',
            ),
          ];

          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      );
}

class _SummaryCard extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _SummaryCard({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: palette.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController search;
  final String filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;

  const _Toolbar({
    required this.palette,
    required this.search,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          final searchField = TextField(
            controller: search,
            onChanged: onSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar gasto o categoría',
              border: InputBorder.none,
            ),
          );

          final selector = DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filter,
              onChanged: (v) {
                if (v != null) onFilter(v);
              },
              items: const [
                DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                DropdownMenuItem(value: 'FIJOS', child: Text('Fijos')),
                DropdownMenuItem(value: 'VARIABLES', child: Text('Variables')),
                DropdownMenuItem(
                  value: 'MANO_OBRA',
                  child: Text('Mano de obra'),
                ),
              ],
            ),
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: constraints.maxWidth < 620
                ? Column(
                    children: [
                      searchField,
                      const Divider(height: 1),
                      Align(alignment: Alignment.centerRight, child: selector),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: searchField),
                      selector,
                    ],
                  ),
          );
        },
      );
}

class _Expense extends StatelessWidget {
  final Map<String, dynamic> item;
  final AppPalette palette;
  final NumberFormat money;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLabor;
  final double? laborToday;
  final double? laborMonthly;
  final int? laborCargoCount;
  final bool laborSummaryError;

  const _Expense({
    required this.item,
    required this.palette,
    required this.money,
    required this.onEdit,
    required this.onDelete,
    required this.onLabor,
    this.laborToday,
    this.laborMonthly,
    this.laborCargoCount,
    this.laborSummaryError = false,
  });

  @override
  Widget build(BuildContext context) {
    final variable = item['gafiTipo'] == 'VARIABLE';
    final value = (item['gafiValor'] as num?)?.toDouble() ??
        double.tryParse(item['gafiValor']?.toString() ?? '') ??
        0;
    final labor = onLabor != null;

    final info = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            labor ? Icons.groups_2_outlined : Icons.receipt_long_outlined,
            color: palette.secondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['gafiNombre']?.toString() ?? 'Gasto',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labor
                    ? '${laborCargoCount ?? 0} cargo${(laborCargoCount ?? 0) == 1 ? '' : 's'} configurado${(laborCargoCount ?? 0) == 1 ? '' : 's'} · tarifas por día'
                    : '${item['gafiCategoria'] ?? 'Otros'} · '
                        '${item['gafiPeriodicidad'] ?? 'MENSUAL'}',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        labor ? 'Mano de obra' : (variable ? 'Variable' : 'Fijo'),
        style: TextStyle(
          color: palette.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!labor)
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (labor)
          IconButton(
            tooltip: 'Configurar cargos',
            onPressed: onLabor,
            icon: const Icon(Icons.tune_outlined),
          ),
        IconButton(
          tooltip: 'Desactivar',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    badge,
                    Text(
                      labor
                          ? laborSummaryError
                              ? 'Costo no disponible'
                              : 'Hoy ${money.format(laborToday ?? 0)} · Mes aprox. ${money.format(laborMonthly ?? 0)}'
                          : money.format(value),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    actions,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              badge,
              const SizedBox(width: 12),
              SizedBox(
                width: labor ? 210 : 150,
                child: Text(
                  labor
                      ? laborSummaryError
                          ? 'Costo no disponible'
                          : 'Hoy ${money.format(laborToday ?? 0)}\nMes ${money.format(laborMonthly ?? 0)}'
                      : money.format(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _LaborDialog extends StatefulWidget {
  final Map<String, dynamic> gasto;
  final AppPalette palette;
  final ApiClient api;

  const _LaborDialog({
    required this.gasto,
    required this.palette,
    required this.api,
  });

  @override
  State<_LaborDialog> createState() => _LaborDialogState();
}

class _LaborDialogState extends State<_LaborDialog> {
  final TextEditingController value = TextEditingController();
  final NumberFormat money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> cargos = [];
  Map<String, List<Map<String, dynamic>>> rates = {};
  Map<String, dynamic>? selected;
  bool loading = true;
  bool saving = false;
  String? loadWarning;
  Set<int> days = {1, 2, 3, 4, 5};
  String rateMode = 'RECURRENTE';
  DateTime effective = DateTime.now();
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  List<Map<String, dynamic>> _parseMapList(Object? json) {
    if (json is! List) return <Map<String, dynamic>>[];
    return json
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _load({dynamic keepSelectedId}) async {
    if (!mounted) return;

    setState(() {
      loading = true;
      loadWarning = null;
    });

    final gastoId = widget.gasto['gafiId'];
    List<Map<String, dynamic>> loaded;

    try {
      final response = await widget.api.get<List<Map<String, dynamic>>>(
        '/api/v1/gastos-fijos/$gastoId/cargos',
        _parseMapList,
      );
      loaded = response.data ?? <Map<String, dynamic>>[];
    } catch (error) {
      debugPrint('Error cargando cargos de mano de obra: $error');
      if (!mounted) return;
      setState(() {
        loading = false;
        loadWarning =
            'No fue posible cargar los cargos. Pulsa reintentar. Si el problema continúa, revisa la consola para ver el detalle técnico.';
      });
      return;
    }

    if (!mounted) return;

    Map<String, dynamic>? nextSelected;
    if (loaded.isNotEmpty) {
      final targetId = keepSelectedId ?? selected?['gafcId'];
      nextSelected = loaded.firstWhere(
        (cargo) => cargo['gafcId'].toString() == targetId?.toString(),
        orElse: () => loaded.first,
      );
    }

    // Pintamos los cargos inmediatamente. La carga de tarifas es secundaria y
    // nunca debe ocultar una lista que el backend ya devolvió correctamente.
    setState(() {
      cargos = loaded;
      selected = nextSelected;
      rates = {
        for (final cargo in loaded)
          cargo['gafcId'].toString(): <Map<String, dynamic>>[],
      };
      loading = false;
      loadWarning = null;
    });

    await _loadRates(loaded);
  }

  Future<void> _loadRates(List<Map<String, dynamic>> loaded) async {
    if (loaded.isEmpty || !mounted) return;
    try {
      final response = await widget.api.get<List<Map<String, dynamic>>>(
        '/api/v1/gastos-fijos/${widget.gasto['gafiId']}/tarifas',
        _parseMapList,
      );
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final rate in response.data ?? <Map<String, dynamic>>[]) {
        final key = rate['gafcId']?.toString() ?? '';
        if (key.isNotEmpty) {
          grouped.putIfAbsent(key, () => []).add(rate);
        }
      }
      if (!mounted) return;
      setState(() {
        rates = {
          for (final cargo in cargos)
            cargo['gafcId'].toString():
                grouped[cargo['gafcId'].toString()] ?? <Map<String, dynamic>>[],
        };
        loadWarning = null;
      });
    } catch (error) {
      debugPrint('Error cargando tarifas de mano de obra: $error');
      if (!mounted) return;
      setState(() {
        loadWarning = 'Los cargos están disponibles, pero no se pudo cargar el historial de tarifas. Reintenta la consulta.';
      });
    }
  }

  Future<void> _addRole() async {
    if (saving) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Crear cargo de trabajo')),
          ],
        ),
        content: SizedBox(
          width: math.min(MediaQuery.sizeOf(ctx).width * .86, 520),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .68,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.palette.secondary.withOpacity(.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.palette.cardBorder),
                      ),
                      child: Text(
                        'Un cargo representa una función del personal que comparte una misma forma de pago. '
                        'Por ejemplo: Mesero, Bartender, Cajero, Cocinero o Administrador. '
                        'Después de crearlo podrás indicar cuánto pagas por día y qué días trabaja.',
                        style: TextStyle(
                          color: widget.palette.textSecondary,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del cargo',
                        hintText: 'Ej. Mesero',
                        helperText: 'Usa el nombre de la función, no el nombre de la persona.',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Escribe el nombre del cargo.';
                        if (text.length > 100) return 'Máximo 100 caracteres.';
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() == true) {
                          Navigator.pop(ctx, controller.text.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Siguiente paso: configurar la tarifa y los días de trabajo.',
                      style: TextStyle(
                        color: widget.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, controller.text.trim());
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Crear y configurar'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final normalizedName = name.trim().toLowerCase();
    final existing = cargos.cast<Map<String, dynamic>?>().firstWhere(
          (cargo) =>
              cargo?['gafcNombre']?.toString().trim().toLowerCase() ==
              normalizedName,
          orElse: () => null,
        );
    if (existing != null) {
      setState(() => selected = existing);
      _message(
        'El cargo "${existing['gafcNombre']}" ya existe. Puedes configurar su tarifa.',
      );
      return;
    }

    setState(() => saving = true);
    try {
      final response = await widget.api.post<Map<String, dynamic>>(
        '/api/v1/gastos-fijos/${widget.gasto['gafiId']}/cargos',
        {'gafcNombre': name.trim(), 'gafcEstado': 1},
        (json) => json is Map
            ? Map<String, dynamic>.from(json)
            : <String, dynamic>{},
      );

      final createdId = response.data?['gafcId'];
      await _load(keepSelectedId: createdId);

      if (mounted) {
        _message(
          'Cargo "$name" creado. Configura ahora su tarifa y los días de trabajo.',
        );
      }
    } catch (_) {
      _message('No fue posible crear el cargo.', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _renameRole() async {
    if (selected == null || saving) return;
    final controller = TextEditingController(
      text: selected!['gafcNombre']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Renombrar cargo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del cargo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    if (ok != true || name.isEmpty || !mounted) return;

    final id = selected!['gafcId'];
    setState(() => saving = true);
    try {
      await widget.api.put<Object?>(
        '/api/v1/gastos-fijos/cargos/$id',
        {'gafcNombre': name, 'gafcEstado': 1},
        (json) => json,
      );
      await _load(keepSelectedId: id);
      _message('Cargo actualizado.');
    } catch (_) {
      _message('No fue posible actualizar el cargo.', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteRole() async {
    if (selected == null || saving) return;
    final id = selected!['gafcId'];
    final name = selected!['gafcNombre']?.toString() ?? 'este cargo';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Desactivar cargo'),
        content: Text(
          '¿Deseas desactivar "$name"? El histórico de tarifas se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => saving = true);
    try {
      await widget.api.delete<Object?>(
        '/api/v1/gastos-fijos/cargos/$id',
        (json) => json,
      );
      selected = null;
      await _load();
      _message('Cargo desactivado.');
    } catch (_) {
      _message('No fue posible desactivar el cargo.', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  Future<void> _editRate(Map<String, dynamic> rate) async {
    if (saving || selected == null) return;
    final cargoId = selected!['gafcId'];
    final tarifaId = rate['gafdId'];
    if (tarifaId == null) return;

    final update = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditLaborRateDialog(
        rate: rate,
        palette: widget.palette,
      ),
    );
    if (update == null || !mounted) return;

    setState(() => saving = true);
    try {
      await widget.api.put<Object?>(
        '/api/v1/gastos-fijos/cargos/$cargoId/tarifas/$tarifaId',
        update,
        (json) => json,
      );
      await _load(keepSelectedId: cargoId);
      _message('Tarifa actualizada. Los demás días no se modificaron.');
    } catch (error) {
      _message('No fue posible modificar la tarifa: $error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteRate(Map<String, dynamic> rate) async {
    if (saving || selected == null) return;
    final cargoId = selected!['gafcId'];
    final tarifaId = rate['gafdId'];
    if (tarifaId == null) return;
    final mode = (rate['gafdModo'] ?? 'RECURRENTE').toString().toUpperCase();
    final weekday = (rate['gafdDiaSemana'] as num?)?.toInt() ??
        int.tryParse(rate['gafdDiaSemana']?.toString() ?? '') ?? 0;
    const names = <String>['', 'lunes', 'martes', 'miércoles',
        'jueves', 'viernes', 'sábado', 'domingo'];
    final dayLabel = weekday >= 1 && weekday <= 7
        ? names[weekday] : 'día seleccionado';
    final until = DateTime.tryParse(
        rate['gafdVigenciaHasta']?.toString() ?? '');
    final currentTime = DateTime.now();
    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final historicalOnly = until != null && until.isBefore(today);
    final description = switch (mode) {
      'RECURRENTE' =>
        historicalOnly
            ? 'Esta tarifa de $dayLabel ya terminó. Eliminarla definitivamente '
                'cambiará los costos históricos de ese día y podría '
                'recalcular reportes anteriores. Las demás tarifas no cambian.'
            : 'Se dejará de aplicar la tarifa de $dayLabel desde hoy. '
                'Los demás días del cargo seguirán iguales y se conservarán '
                'los costos de jornadas anteriores.',
      'DIA' =>
        'Se eliminará la tarifa de esta fecha específica. '
        'Si corresponde a un día pasado, se recalcularán los reportes '
        'históricos de ganancias que incluyen esa fecha.',
      _ =>
        'Se eliminará el período completo, no los demás períodos ni las '
        'tarifas semanales. La parte histórica del período se conserva '
        'si todavía está vigente. Eliminar un período ya terminado '
        'puede recalcular reportes históricos.',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Row(
          children: [
            Icon(Icons.event_busy_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Eliminar tarifa de mano de obra')),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Confirmar eliminación'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.delete<Object?>(
        '/api/v1/gastos-fijos/cargos/$cargoId/tarifas/$tarifaId',
        (json) => json,
      );
      await _load(keepSelectedId: cargoId);
      _message('Tarifa eliminada o finalizada. Los demás días se conservaron.');
    } catch (error) {
      _message('No fue posible eliminar la tarifa: $error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _saveRate() async {
    if (selected == null || (rateMode == 'RECURRENTE' && days.isEmpty) || saving) return;

    final raw = value.text.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      _message('Ingresa un valor válido para la tarifa.', error: true);
      return;
    }

    if (rateMode == 'PERIODO' &&
        (endDate == null || endDate!.isBefore(DateTime(effective.year, effective.month, effective.day)))) {
      _message('Selecciona una fecha final igual o posterior a la inicial.', error: true);
      return;
    }

    final cargoId = selected!['gafcId'];
    setState(() => saving = true);
    try {
      await widget.api.post<Object?>(
        '/api/v1/gastos-fijos/cargos/$cargoId/tarifas',
        {
          'modo': rateMode,
          if (rateMode == 'RECURRENTE') 'diasSemana': days.toList()..sort(),
          'valor': amount,
          'vigenciaDesde': DateFormat('yyyy-MM-dd').format(effective),
          if (rateMode == 'PERIODO')
            'vigenciaHasta': DateFormat('yyyy-MM-dd').format(endDate!),
        },
        (json) => json,
      );
      value.clear();
      await _load(keepSelectedId: cargoId);
      _message('Tarifa aplicada.');
    } catch (_) {
      _message('No fue posible guardar la tarifa.', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _preset(List<int> presetDays) {
    setState(() => days = {...presetDays});
  }

  // La lista forma parte del scroll general en móvil; en escritorio usa
  // su propia área flexible para mantener el panel dividido.
  Widget _roleList({bool embedded = false}) {
    return cargos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 42,
                            color: widget.palette.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Aún no hay cargos',
                            style: TextStyle(
                              color: widget.palette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crea el primero para definir cuánto cuesta la mano de obra por día.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: embedded,
                    physics: embedded
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: cargos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final cargo = cargos[index];
                      final cargoId = cargo['gafcId'].toString();
                      final active = selected?['gafcId'].toString() == cargoId;
                      final allRates = rates[cargoId] ?? const <Map<String, dynamic>>[];
                       final now = DateTime.now();
                       final today = DateTime(now.year, now.month, now.day);
                       final configuredRates = allRates.where((rate) {
                         final from = DateTime.tryParse(rate['gafdVigenciaDesde']?.toString() ?? '');
                         final until = DateTime.tryParse(rate['gafdVigenciaHasta']?.toString() ?? '');
                         return from != null && !from.isAfter(today) &&
                             (until == null || !until.isBefore(today));
                       }).length;
                       final otherRates = allRates.length - configuredRates;

                      return Material(
                        color: active
                            ? widget.palette.secondary.withOpacity(.10)
                            : widget.palette.surface.withOpacity(.40),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => selected = cargo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: active
                                    ? widget.palette.secondary.withOpacity(.45)
                                    : widget.palette.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: widget.palette.secondary.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    color: widget.palette.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cargo['gafcNombre']?.toString() ?? 'Cargo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: widget.palette.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        configuredRates == 0
                                            ? 'Sin tarifas configuradas'
                                            : '$configuredRates vigentes · $otherRates históricas/programadas',
                                        style: TextStyle(
                                          color: configuredRates == 0
                                              ? widget.palette.warning
                                              : widget.palette.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  active
                                      ? Icons.check_circle
                                      : Icons.chevron_right,
                                  color: active
                                      ? widget.palette.secondary
                                      : widget.palette.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
  }

  Widget _rolesPane({bool embedded = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cargos de trabajo',
            style: TextStyle(
              color: widget.palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cada cargo puede tener una tarifa diferente según los días de la semana.',
            style: TextStyle(
              color: widget.palette.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : _addRole,
              icon: const Icon(Icons.add),
              label: const Text('Crear cargo'),
            ),
          ),
          const SizedBox(height: 12),
          if (embedded)
            _roleList(embedded: true)
          else
            Expanded(child: _roleList()),
        ],
      );

  Widget _configurationPane({bool mobile = false}) {
    if (selected == null) {
      return Center(
        child: Text(
          'Selecciona o agrega un cargo para configurar sus tarifas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: widget.palette.textSecondary),
        ),
      );
    }

    final selectedRates = rates[selected!['gafcId'].toString()] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selected!['gafcNombre']?.toString() ?? 'Cargo',
                style: TextStyle(
                  color: widget.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Renombrar cargo',
              onPressed: saving ? null : _renameRole,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Desactivar cargo',
              onPressed: saving ? null : _deleteRole,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Text(
          'Define cuánto cuesta un día de trabajo. Puedes registrarlo por una sola fecha, un período o una recurrencia semanal.',
          style: TextStyle(
            color: widget.palette.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Recurrente'),
              selected: rateMode == 'RECURRENTE',
              onSelected: (_) => setState(() => rateMode = 'RECURRENTE'),
            ),
            ChoiceChip(
              label: const Text('Un día'),
              selected: rateMode == 'DIA',
              onSelected: (_) => setState(() => rateMode = 'DIA'),
            ),
            ChoiceChip(
              label: const Text('Período'),
              selected: rateMode == 'PERIODO',
              onSelected: (_) => setState(() {
                rateMode = 'PERIODO';
                endDate ??= effective;
              }),
            ),
          ],
        ),
        if (rateMode == 'RECURRENTE') ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Lunes - Viernes'),
              selected: days.length == 5 && days.every((x) => x <= 5),
              onSelected: (_) => _preset([1, 2, 3, 4, 5]),
            ),
            ChoiceChip(
              label: const Text('Sábado - Domingo'),
              selected:
                  days.length == 2 && days.contains(6) && days.contains(7),
              onSelected: (_) => _preset([6, 7]),
            ),
            ChoiceChip(
              label: const Text('Todos'),
              selected: days.length == 7,
              onSelected: (_) => _preset([1, 2, 3, 4, 5, 6, 7]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(7, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text(
                const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                    [index],
              ),
              selected: days.contains(day),
              onSelected: (selectedValue) {
                setState(() {
                  if (selectedValue) {
                    days.add(day);
                  } else {
                    days.remove(day);
                  }
                });
              },
            );
          }),
        ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, constraints) {
            final amount = TextField(
              controller: value,
              enabled: !saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Costo diario del cargo',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            );

            final date = InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effective,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                           effective = picked;
                           if (endDate != null && endDate!.isBefore(picked)) {
                             endDate = picked;
                           }
                         });
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: rateMode == 'RECURRENTE'
                      ? 'Vigente desde'
                      : rateMode == 'DIA' ? 'Fecha de trabajo' : 'Fecha inicial',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(effective)),
              ),
            );

            final endPicker = InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate != null && !endDate!.isBefore(effective)
                            ? endDate! : effective,
                        firstDate: effective,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => endDate = picked);
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha final (incluida)',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(endDate == null
                    ? 'Seleccionar'
                    : DateFormat('dd/MM/yyyy').format(endDate!)),
              ),
            );

            final saveButton = FilledButton.icon(
              onPressed: saving ? null : _saveRate,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar tarifa'),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  amount,
                  const SizedBox(height: 10),
                  date,
                  if (rateMode == 'PERIODO') ...[
                    const SizedBox(height: 10),
                    endPicker,
                  ],
                  const SizedBox(height: 10),
                  saveButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: amount),
                const SizedBox(width: 10),
                SizedBox(width: 175, child: date),
                if (rateMode == 'PERIODO') ...[
                  const SizedBox(width: 10),
                  SizedBox(width: 175, child: endPicker),
                ],
                const SizedBox(width: 10),
                saveButton,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tarifas e histórico',
                style: TextStyle(
                  color: widget.palette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Tooltip(
              message: 'Edita o elimina una tarifa por día sin tocar el cargo',
              child: Icon(Icons.info_outline_rounded,
                  size: 18, color: widget.palette.textSecondary),
            ),
          ],
        ),
        Text(
          'Usa los iconos de cada fila para cambiar o quitar solo ese día.',
          style: TextStyle(
            color: widget.palette.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        if (mobile)
          _RatesList(
            rates: selectedRates,
            palette: widget.palette,
            money: money,
            busy: saving,
            embedded: true,
            onEdit: _editRate,
            onDelete: _deleteRate,
          )
        else
          Expanded(
            child: _RatesList(
              rates: selectedRates,
              palette: widget.palette,
              money: money,
              busy: saving,
              onEdit: _editRate,
              onDelete: _deleteRate,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    // Dialog ya respeta el teclado y los safe areas del sistema. Reservar
    // un margen adicional evita que iPhone y navegadores oculten acciones.
    final availableHeight = size.height -
        media.padding.vertical - media.viewInsets.bottom - 40;
    final height = math.min(720.0, math.max(180.0, availableHeight));
    final width = math.min(980.0, math.max(280.0, size.width - 32));
    final mobile = size.width < 760;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mano de obra',
                      style: TextStyle(
                        color: widget.palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: loading
                    ? const Center(child: AppLoader())
                    : Column(
                        children: [
                          if (loadWarning != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.palette.warning.withOpacity(.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.palette.warning.withOpacity(.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: widget.palette.warning),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(
                                    loadWarning!,
                                    style: TextStyle(
                                      color: widget.palette.textPrimary,
                                      fontSize: 12,
                                    ),
                                  )),
                                  IconButton(
                                    tooltip: 'Reintentar',
                                    onPressed: saving ? null : _load,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: mobile
                                ? Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      key: const Key('labor-dialog-mobile-scroll'),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior.onDrag,
                                      padding: const EdgeInsets.only(
                                          right: 8, bottom: 28),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _rolesPane(embedded: true),
                                          const Divider(height: 24),
                                          _configurationPane(mobile: true),
                                        ],
                                      ),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      SizedBox(width: 300, child: _rolesPane()),
                                      const VerticalDivider(width: 28),
                                      Expanded(child: _configurationPane()),
                                    ],
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Edita una sola tarifa ya registrada; nunca modifica ni elimina el cargo.
class _EditLaborRateDialog extends StatefulWidget {
  const _EditLaborRateDialog({
    required this.rate,
    required this.palette,
  });

  final Map<String, dynamic> rate;
  final AppPalette palette;

  @override
  State<_EditLaborRateDialog> createState() => _EditLaborRateDialogState();
}

class _EditLaborRateDialogState extends State<_EditLaborRateDialog> {
  late final TextEditingController amountController;
  late DateTime from;
  DateTime? until;
  late final String mode;
  String? error;

  @override
  void initState() {
    super.initState();
    mode = (widget.rate['gafdModo'] ?? 'RECURRENTE').toString().toUpperCase();
    final amount = (widget.rate['gafdValor'] as num?)?.toDouble() ??
        double.tryParse(widget.rate['gafdValor']?.toString() ?? '') ?? 0;
    amountController = TextEditingController(
      text: amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toString(),
    );
    final started = DateTime.tryParse(
            widget.rate['gafdVigenciaDesde']?.toString() ?? '') ??
        DateTime.now();
    until = DateTime.tryParse(
        widget.rate['gafdVigenciaHasta']?.toString() ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Una recurrencia abierta puede cambiar desde hoy sin reescribir meses
    // históricos. Se permite elegir su inicio para una corrección retroactiva.
    from = mode == 'RECURRENTE' && until == null && started.isBefore(today)
        ? today
        : started;
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Desde qué fecha tendrá efecto la tarifa',
    );
    if (selected == null || !mounted) return;
    setState(() {
      from = selected;
      if (mode == 'PERIODO' && until != null && until!.isBefore(from)) {
        until = from;
      }
    });
  }

  Future<void> _pickUntil() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: until != null && !until!.isBefore(from) ? until! : from,
      firstDate: from,
      lastDate: DateTime(2100),
      helpText: 'Hasta cuándo se aplica esta tarifa',
    );
    if (selected != null && mounted) setState(() => until = selected);
  }

  void _submit() {
    final raw = amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      setState(() => error = 'Ingresa un costo diario válido.');
      return;
    }
    if (mode == 'PERIODO' && (until == null || until!.isBefore(from))) {
      setState(() => error = 'La fecha final no puede ser anterior a la inicial.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'valor': amount,
      'vigenciaDesde': DateFormat('yyyy-MM-dd').format(from),
      if (mode == 'PERIODO')
        'vigenciaHasta': DateFormat('yyyy-MM-dd').format(until!),
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekday = (widget.rate['gafdDiaSemana'] as num?)?.toInt() ??
        int.tryParse(widget.rate['gafdDiaSemana']?.toString() ?? '') ?? 0;
    const labels = ['', 'Lunes', 'Martes', 'Miércoles',
        'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final dayName = weekday >= 1 && weekday <= 7 ? labels[weekday] : 'día';
    final subtitle = switch (mode) {
      'DIA' => 'Corrige la fecha y el costo de este día específico.',
      'PERIODO' => 'Corrige el período completo y su costo diario.',
      _ => 'Corrige solo $dayName. Si eliges una fecha posterior al inicio, '
          'se conserva el precio anterior hasta el día previo.',
    };

    Widget dateField(String label, DateTime date, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
        );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_calendar_outlined, color: widget.palette.secondary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Modificar tarifa')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  color: widget.palette.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Costo diario en pesos',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              dateField(
                mode == 'DIA' ? 'Fecha de trabajo' :
                mode == 'PERIODO' ? 'Inicio' : 'Vigente desde',
                from,
                _pickFrom,
              ),
              if (mode == 'PERIODO') ...[
                const SizedBox(height: 8),
                dateField('Hasta', until ?? from, _pickUntil),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              if (mode == 'DIA' || mode == 'PERIODO') ...[
                const SizedBox(height: 10),
                Text(
                  'Atención: modificar una tarifa ya aplicada puede '
                  'recalcular la mano de obra de reportes anteriores.',
                  style: TextStyle(
                    color: widget.palette.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

class _RatesList extends StatelessWidget {
  final List<Map<String, dynamic>> rates;
  final AppPalette palette;
  final NumberFormat money;
  final bool busy;
  final bool embedded;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _RatesList({
    required this.rates,
    required this.palette,
    required this.money,
    required this.busy,
    this.embedded = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const names = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    if (rates.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay tarifas para este cargo.',
          style: TextStyle(color: palette.textSecondary),
        ),
      );
    }

    // Un PERIODO se guarda con hasta siete filas (una por día semanal),
    // pero representa una sola decisión de negocio en el historial.
    final unique = <String, Map<String, dynamic>>{};
    for (final rate in rates) {
      final modo = rate['gafdModo']?.toString() ?? 'RECURRENTE';
      final key = modo == 'PERIODO'
          ? 'PERIODO|${rate['gafdVigenciaDesde']}|${rate['gafdVigenciaHasta']}|${rate['gafdValor']}'
          : 'TARIFA|${rate['gafdId']}';
      unique.putIfAbsent(key, () => rate);
    }
    final visibleRates = unique.values.toList(growable: true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int rateRank(Map<String, dynamic> rate) {
      final start = DateTime.tryParse(rate['gafdVigenciaDesde']?.toString() ?? '');
      final end = DateTime.tryParse(rate['gafdVigenciaHasta']?.toString() ?? '');
      if (start != null && start.isAfter(today)) return 1;
      if (end != null && end.isBefore(today)) return 2;
      return 0;
    }
    visibleRates.sort((a, b) {
      final priority = rateRank(a).compareTo(rateRank(b));
      if (priority != 0) return priority;
      final firstDay = (a['gafdDiaSemana'] as num?)?.toInt() ?? 0;
      final secondDay = (b['gafdDiaSemana'] as num?)?.toInt() ?? 0;
      return firstDay.compareTo(secondDay);
    });

    return ListView.separated(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      itemCount: visibleRates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, index) {
        final rate = visibleRates[index];
        final day = (rate['gafdDiaSemana'] as num?)?.toInt() ??
            int.tryParse(rate['gafdDiaSemana']?.toString() ?? '') ??
            0;
        final amount = (rate['gafdValor'] as num?)?.toDouble() ??
            double.tryParse(rate['gafdValor']?.toString() ?? '') ??
            0;
        final from = rate['gafdVigenciaDesde']?.toString() ?? '';
        final until = rate['gafdVigenciaHasta']?.toString();
        final modo = rate['gafdModo']?.toString() ?? 'RECURRENTE';

        final status = rateRank(rate);
        final statusColor = status == 0 ? palette.success
            : status == 1 ? palette.secondary : palette.textSecondary;
        final statusLabel = status == 0 ? 'Vigente'
            : status == 1 ? 'Programada' : 'Histórica';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: status == 0
                ? palette.secondary.withOpacity(.05)
                : palette.background.withOpacity(.28),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: status == 0
                  ? palette.secondary.withOpacity(.21)
                  : palette.cardBorder.withOpacity(.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      modo == 'DIA' ? 'Día único'
                          : modo == 'PERIODO' ? 'Período'
                          : (day >= 1 && day <= 7 ? names[day] : 'Día $day'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(money.format(amount),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      )),
                  const SizedBox(width: 7),
                  IconButton(
                    tooltip: 'Modificar únicamente esta tarifa',
                    onPressed: busy ? null : () => onEdit(rate),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    icon: Icon(Icons.edit_outlined,
                        size: 19, color: palette.secondary),
                  ),
                  IconButton(
                    tooltip: 'Eliminar únicamente esta tarifa',
                    onPressed: busy ? null : () => onDelete(rate),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 19, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 7,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.11),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  Text(
                    until == null || until.isEmpty
                        ? 'Desde $from'
                        : '$from → $until',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Selecciona una única tarifa por cargo y fecha sin doble conteo.
/// Una excepción puntual tiene prioridad sobre un período y ambos
/// prevalecen frente a la tarifa recurrente de la misma fecha.
double costoManoObraEnFecha(
    Iterable<Map<String, dynamic>> tarifas, DateTime fecha) {
  int dia = fecha.weekday;
  DateTime normalize(DateTime x) => DateTime(x.year, x.month, x.day);
  int prioridad(String? tipo) {
    if (tipo == 'DIA') return 0;
    if (tipo == 'PERIODO') return 1;
    return 2;
  }

  final disponibles = tarifas.where((tarifa) {
    final rawDia = tarifa['gafdDiaSemana'];
    final diaTarifa = rawDia is num ? rawDia.toInt() :
        int.tryParse(rawDia?.toString() ?? '') ?? 0;
    final desde = DateTime.tryParse(tarifa['gafdVigenciaDesde']?.toString() ?? '');
    final hasta = DateTime.tryParse(tarifa['gafdVigenciaHasta']?.toString() ?? '');
    return diaTarifa == dia &&
        desde != null &&
        !normalize(desde).isAfter(normalize(fecha)) &&
        (hasta == null || !normalize(hasta).isBefore(normalize(fecha)));
  }).toList();

  if (disponibles.isEmpty) return 0;
  disponibles.sort((a, b) {
    final byType = prioridad(a['gafdModo']?.toString())
        .compareTo(prioridad(b['gafdModo']?.toString()));
    if (byType != 0) return byType;
    final fromA = a['gafdVigenciaDesde']?.toString() ?? '';
    final fromB = b['gafdVigenciaDesde']?.toString() ?? '';
    final byDate = fromB.compareTo(fromA);
    if (byDate != 0) return byDate;
    final rawIdA = a['gafdId'];
    final rawIdB = b['gafdId'];
    final idA = rawIdA is num ? rawIdA.toInt() : int.tryParse(rawIdA?.toString() ?? '') ?? 0;
    final idB = rawIdB is num ? rawIdB.toInt() : int.tryParse(rawIdB?.toString() ?? '') ?? 0;
    return idB.compareTo(idA);
  });
  final amount = disponibles.first['gafdValor'];
  return amount is num
      ? amount.toDouble()
      : double.tryParse(amount?.toString() ?? '') ?? 0;
}
