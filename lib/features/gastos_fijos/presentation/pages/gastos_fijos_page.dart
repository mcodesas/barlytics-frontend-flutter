import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
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

  Future<void> _load() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          items = [];
          loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => loading = true);
    try {
      final response = await ref.read(apiClientProvider).get<List<dynamic>>(
            '/api/v1/gastos-fijos/sucursal/$branchId',
            (json) => (json as List?) ?? const [],
          );

      if (!mounted) return;
      setState(() {
        items = (response.data ?? const <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
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

    if (ok != true) {
      name.dispose();
      value.dispose();
      note.dispose();
      return;
    }

    final savedName = name.text.trim();
    final savedNote = note.text.trim();
    final rawValue = value.text.replaceAll('.', '').replaceAll(',', '.');
    final savedValue =
        category == 'Mano de obra' ? 0.0 : (double.tryParse(rawValue) ?? 0.0);

    name.dispose();
    value.dispose();
    note.dispose();

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
    if (confirmed != true) return;

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
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final q = search.text.trim().toLowerCase();

    final visible = items.where((item) {
      final type = item['gafiTipo']?.toString() ?? 'FIJO';
      if (filter == 'FIJOS' && type != 'FIJO') return false;
      if (filter == 'VARIABLES' && type != 'VARIABLE') return false;
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
  final NumberFormat money;

  const _Summary({
    required this.palette,
    required this.fixed,
    required this.variable,
    required this.hasLabor,
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
              label: 'Mano de obra',
              value: hasLabor ? 'Por cargo y día' : 'Sin configurar',
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

  const _SummaryCard({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
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

  const _Expense({
    required this.item,
    required this.palette,
    required this.money,
    required this.onEdit,
    required this.onDelete,
    required this.onLabor,
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
                '${item['gafiCategoria'] ?? 'Otros'} · '
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
        variable ? 'Variable' : 'Fijo',
        style: TextStyle(
          color: palette.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                      labor ? 'Calculado por cargo' : money.format(value),
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
                width: 150,
                child: Text(
                  labor ? 'Por cargo' : money.format(value),
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
  final dynamic api;

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
  DateTime effective = DateTime.now();

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

  Future<void> _load({dynamic keepSelectedId}) async {
    if (mounted) {
      setState(() {
        loading = true;
        loadWarning = null;
      });
    }

    try {
      final gastoId = widget.gasto['gafiId'];
      final response = await widget.api.get<List<dynamic>>(
        '/api/v1/gastos-fijos/$gastoId/cargos',
        (json) => (json as List?) ?? const [],
      );

      final loaded = (response.data ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      Map<String, dynamic>? nextSelected;
      if (loaded.isNotEmpty) {
        final targetId = keepSelectedId ?? selected?['gafcId'];
        nextSelected = loaded.firstWhere(
          (cargo) => cargo['gafcId'].toString() == targetId?.toString(),
          orElse: () => loaded.first,
        );
      }

      if (mounted) {
        setState(() {
          cargos = loaded;
          selected = nextSelected;
          rates = {
            for (final cargo in loaded)
              cargo['gafcId'].toString(): <Map<String, dynamic>>[],
          };
          loading = false;
        });
      }

      final loadedRates = <String, List<Map<String, dynamic>>>{};
      var failedRateLoads = 0;

      for (final cargo in loaded) {
        final cargoId = cargo['gafcId'];
        try {
          final rateResponse = await widget.api.get<List<dynamic>>(
            '/api/v1/gastos-fijos/cargos/$cargoId/tarifas',
            (json) => (json as List?) ?? const [],
          );
          loadedRates[cargoId.toString()] =
              (rateResponse.data ?? const <dynamic>[])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
        } catch (_) {
          failedRateLoads++;
          loadedRates[cargoId.toString()] = <Map<String, dynamic>>[];
        }
      }

      if (!mounted) return;
      setState(() {
        rates = loadedRates;
        loadWarning = failedRateLoads == 0
            ? null
            : failedRateLoads == 1
                ? 'Se cargaron los cargos, pero no fue posible consultar la tarifa de un cargo. Puedes seguir administrando los cargos y volver a intentar.'
                : 'Se cargaron los cargos, pero no fue posible consultar algunas tarifas. Puedes seguir administrando los cargos y volver a intentar.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        cargos = [];
        rates = {};
        selected = null;
        loading = false;
        loadWarning =
            'No fue posible cargar los cargos. Verifica que el backend y la migración de mano de obra estén actualizados.';
      });
      _message('No fue posible cargar los cargos.', error: true);
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

    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;

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
    controller.dispose();
    if (ok != true || name.isEmpty) return;

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
    if (ok != true) return;

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

  Future<void> _saveRate() async {
    if (selected == null || days.isEmpty || saving) return;

    final raw = value.text.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      _message('Ingresa un valor válido para la tarifa.', error: true);
      return;
    }

    final cargoId = selected!['gafcId'];
    setState(() => saving = true);
    try {
      await widget.api.post<Object?>(
        '/api/v1/gastos-fijos/cargos/$cargoId/tarifas',
        {
          'diasSemana': days.toList()..sort(),
          'valor': amount,
          'vigenciaDesde': DateFormat('yyyy-MM-dd').format(effective),
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

  Widget _rolesPane() => Column(
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
          Expanded(
            child: cargos.isEmpty
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
                    itemCount: cargos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final cargo = cargos[index];
                      final cargoId = cargo['gafcId'].toString();
                      final active = selected?['gafcId'].toString() == cargoId;
                      final configuredRates = rates[cargoId]?.length ?? 0;

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
                                            : '$configuredRates tarifa${configuredRates == 1 ? '' : 's'} registrada${configuredRates == 1 ? '' : 's'}',
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
                  ),
          ),
        ],
      );

  Widget _configurationPane() {
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
          'Define cuánto cuesta un día de trabajo para este cargo. Puedes usar una combinación rápida o seleccionar días individualmente.',
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
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, constraints) {
            final amount = TextField(
              controller: value,
              enabled: !saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor por día seleccionado',
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
                        setState(() => effective = picked);
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Vigente desde',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(effective)),
              ),
            );

            if (constraints.maxWidth < 570) {
              return Column(
                children: [
                  amount,
                  const SizedBox(height: 10),
                  date,
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _saveRate,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Aplicar tarifa'),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: amount),
                const SizedBox(width: 10),
                SizedBox(width: 190, child: date),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: saving ? null : _saveRate,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Aplicar'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Tarifas e histórico',
          style: TextStyle(
            color: widget.palette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _RatesList(
            rates: selectedRates,
            palette: widget.palette,
            money: money,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width * .94, 980.0);
    final height = math.min(size.height * .82, 680.0);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 18, 12, 0),
      title: Row(
        children: [
          const Icon(Icons.groups_2_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mano de obra',
              style: TextStyle(
                color: widget.palette.textPrimary,
                fontWeight: FontWeight.w900,
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
      content: SizedBox(
        width: width,
        height: height,
        child: loading
            ? const Center(child: AppLoader())
            : Column(
                children: [
                  if (loadWarning != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.palette.warning.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.palette.warning.withOpacity(.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: widget.palette.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              loadWarning!,
                              style: TextStyle(
                                color: widget.palette.textPrimary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reintentar',
                            onPressed: saving ? null : _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              SizedBox(height: 260, child: _rolesPane()),
                              const Divider(height: 24),
                              Expanded(child: _configurationPane()),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            SizedBox(width: 300, child: _rolesPane()),
                            const VerticalDivider(width: 28),
                            Expanded(child: _configurationPane()),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RatesList extends StatelessWidget {
  final List<Map<String, dynamic>> rates;
  final AppPalette palette;
  final NumberFormat money;

  const _RatesList({
    required this.rates,
    required this.palette,
    required this.money,
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

    return ListView.separated(
      itemCount: rates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, index) {
        final rate = rates[index];
        final day = (rate['gafdDiaSemana'] as num?)?.toInt() ??
            int.tryParse(rate['gafdDiaSemana']?.toString() ?? '') ??
            0;
        final amount = (rate['gafdValor'] as num?)?.toDouble() ??
            double.tryParse(rate['gafdValor']?.toString() ?? '') ??
            0;
        final from = rate['gafdVigenciaDesde']?.toString() ?? '';
        final until = rate['gafdVigenciaHasta']?.toString();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  day >= 1 && day <= 7 ? names[day] : 'Día $day',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                money.format(amount),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  until == null || until.isEmpty
                      ? 'Desde $from'
                      : '$from → $until',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
