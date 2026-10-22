import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/utils/currency_utils.dart';

/// Presentación únicamente de lectura del desglose enviado por Ganancias.
/// No altera el cálculo de gastos ni incorpora estados de nómina.
class ProfitExpenseBreakdown extends StatefulWidget {
  const ProfitExpenseBreakdown({
    super.key,
    required this.items,
    required this.finance,
    required this.palette,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> finance;
  final AppPalette palette;

  @override
  State<ProfitExpenseBreakdown> createState() => _ProfitExpenseBreakdownState();
}

class _ExpenseCategory {
  const _ExpenseCategory(this.key, this.title, this.description, this.icon);

  final String key;
  final String title;
  final String description;
  final IconData icon;
}

const _categories = <_ExpenseCategory>[
  _ExpenseCategory('FIJO', 'Fijos', 'Recurrentes', Icons.event_repeat_rounded),
  _ExpenseCategory('VARIABLE', 'Variables', 'Configurados', Icons.tune_rounded),
  _ExpenseCategory('GASTOS TURNO', 'Del turno', 'Salidas de caja', Icons.receipt_long_rounded),
  _ExpenseCategory('MANO DE OBRA', 'Mano de obra', 'Por cargo', Icons.groups_2_outlined),
  _ExpenseCategory('OTROS', 'Otros', 'Otros conceptos', Icons.more_horiz_rounded),
];

String _categoryFor(Object? category) {
  final value = category?.toString().trim().toUpperCase() ?? '';
  return switch (value) {
    'FIJO' => 'FIJO',
    'VARIABLE' => 'VARIABLE',
    'GASTOS TURNO' => 'GASTOS TURNO',
    'MANO DE OBRA' => 'MANO DE OBRA',
    _ => 'OTROS',
  };
}

double _expenseValue(Object? value) {
  if (value is num) return value.toDouble();
  var valueText = value?.toString().trim() ?? '';
  if (valueText.isEmpty) return 0;
  valueText = valueText.replaceAll(RegExp(r'[^0-9,.-]'), '');
  final comma = valueText.lastIndexOf(',');
  final point = valueText.lastIndexOf('.');
  if (comma >= 0 && point >= 0) {
    valueText = comma > point
        ? valueText.replaceAll('.', '').replaceAll(',', '.')
        : valueText.replaceAll(',', '');
  } else if (comma >= 0) {
    valueText = valueText.replaceAll(',', '.');
  }
  return double.tryParse(valueText) ?? 0;
}

class _ExpenseGroup {
  _ExpenseGroup({
    required this.category,
    required this.name,
  });

  final String category;
  final String name;
  double total = 0;
  final List<Map<String, dynamic>> movements = [];

  void add(Map<String, dynamic> movement) {
    total += _expenseValue(movement['valor']);
    movements.add(movement);
  }
}

class _ProfitExpenseBreakdownState extends State<ProfitExpenseBreakdown> {
  final TextEditingController _searchController = TextEditingController();
  String? _categoryFilter;
  bool _showAll = false;

  @override
  void didUpdateWidget(covariant ProfitExpenseBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _searchController.clear();
      _categoryFilter = null;
      _showAll = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _tone(String category) {
    return switch (category) {
      'FIJO' => widget.palette.info,
      'VARIABLE' => widget.palette.warning,
      'GASTOS TURNO' => widget.palette.secondary,
      'MANO DE OBRA' => widget.palette.primary,
      _ => widget.palette.textSecondary,
    };
  }

  String _concept(Map<String, dynamic> movement) {
    final value = movement['concepto']?.toString().trim();
    return value == null || value.isEmpty ? 'Sin concepto' : value;
  }

  String _detail(Map<String, dynamic> movement) {
    final parts = <String>[];
    final dateText = movement['fecha']?.toString();
    if (dateText != null && dateText.isNotEmpty) {
      final parsed = DateTime.tryParse(dateText);
      parts.add(parsed == null ? dateText : DateFormat('dd/MM/yyyy').format(parsed));
    }
    final type = movement['tipo']?.toString().trim();
    if (type != null && type.isNotEmpty) parts.add(type);
    return parts.join('  ·  ');
  }

  Widget _categoryCard({
    required _ExpenseCategory category,
    required double total,
    required double denominator,
    required int count,
    required double width,
  }) {
    final palette = widget.palette;
    final selected = _categoryFilter == category.key;
    final tone = _tone(category.key);
    final fraction = denominator <= 0 ? 0.0 : total / denominator * 100;

    return SizedBox(
      width: width,
      child: Material(
        color: selected ? tone.withOpacity(0.17) : palette.background.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? tone.withOpacity(0.72) : palette.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => setState(() {
            _categoryFilter = selected ? null : category.key;
            _showAll = false;
          }),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tone.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(category.icon, color: tone, size: 19),
                    ),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle, color: tone, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtils.format(total),
                    style: TextStyle(color: palette.textPrimary, fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${fraction.toStringAsFixed(1)} % del total · $count registros',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expenseRow(_ExpenseGroup group, double positiveSum) {
    final palette = widget.palette;
    final category = _categories.firstWhere((item) => item.key == group.category);
    final tone = _tone(group.category);
    final part = positiveSum > 0
        ? (group.total.abs() / positiveSum).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final repeats = group.movements.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(0.32),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 37,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        repeats
                            ? '${category.title} · ${group.movements.length} movimientos'
                            : (() {
                                final detail = _detail(group.movements.first);
                                return detail.isEmpty ? category.title : '${category.title} · $detail';
                              })(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.format(group.total),
                      style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(part * 100).toStringAsFixed(1)} %',
                      style: TextStyle(color: palette.textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: part,
                backgroundColor: tone.withOpacity(0.10),
                color: tone,
              ),
            ),
            if (repeats)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Ver ${group.movements.length} movimientos individuales',
                    style: TextStyle(color: tone, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  children: [
                    for (final movement in group.movements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _detail(movement).isEmpty
                                    ? _concept(movement)
                                    : _detail(movement),
                                style: TextStyle(color: palette.textSecondary, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyUtils.format(_expenseValue(movement['valor'])),
                              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final subtotal = <String, double>{};
    final counts = <String, int>{};
    for (final item in widget.items) {
      final category = _categoryFor(item['categoria']);
      subtotal[category] = (subtotal[category] ?? 0) + _expenseValue(item['valor']);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final detailedTotal = subtotal.values.fold<double>(0, (sum, value) => sum + value);
    final hasExpected = widget.finance.containsKey('gastos_operativos_periodo');
    final expected = hasExpected
        ? _expenseValue(widget.finance['gastos_operativos_periodo'])
        : detailedTotal;
    final difference = detailedTotal - expected;
    final positiveSum = subtotal.values.fold<double>(0, (sum, val) => sum + math.max(0, val));
    final query = _searchController.text.trim().toLowerCase();

    final groupsMap = <String, _ExpenseGroup>{};
    for (final movement in widget.items) {
      final category = _categoryFor(movement['categoria']);
      if (_categoryFilter != null && category != _categoryFilter) continue;
      final concept = _concept(movement);
      final searchable = '$concept ${movement['tipo'] ?? ''} ${movement['fecha'] ?? ''}'.toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) continue;
      final key = '$category|${concept.toLowerCase()}';
      groupsMap.putIfAbsent(key, () => _ExpenseGroup(category: category, name: concept)).add(movement);
    }
    final groups = groupsMap.values.toList(growable: false)
      ..sort((first, second) => second.total.abs().compareTo(first.total.abs()));
    final visible = _showAll ? groups : groups.take(8).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 24, tint: palette.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: palette.secondary, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de gastos del período',
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta cada concepto y cuánto representa. La mano de obra refleja los cargos y tarifas configurados.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 610;
              final totalBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL DE GASTOS OPERATIVOS',
                      style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5)),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyUtils.format(expected),
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: narrow ? 29 : 34),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.items.length} registros de gasto en el rango elegido',
                    style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                  ),
                ],
              );
              final balance = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (difference.abs() <= 0.01 ? palette.success : palette.warning).withOpacity(0.11),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: (difference.abs() <= 0.01 ? palette.success : palette.warning).withOpacity(0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      difference.abs() <= 0.01 ? Icons.verified_outlined : Icons.warning_amber_rounded,
                      size: 20,
                      color: difference.abs() <= 0.01 ? palette.success : palette.warning,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        !hasExpected
                            ? 'Detalle informativo'
                            : difference.abs() <= 0.01
                                ? 'Desglose conciliado'
                                : 'Diferencia por revisar: ${CurrencyUtils.format(difference.abs())}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    totalBlock,
                    const SizedBox(height: 12),
                    balance,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: totalBlock),
                  const SizedBox(width: 16),
                  Flexible(child: balance),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 680 ? 2 : 4;
              const gap = 10.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              final categories = _categories.where((item) =>
                  item.key != 'OTROS' || (counts[item.key] ?? 0) > 0).toList(growable: false);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final category in categories)
                    _categoryCard(
                      category: category,
                      total: subtotal[category.key] ?? 0,
                      denominator: positiveSum,
                      count: counts[category.key] ?? 0,
                      width: width,
                    ),
                ],
              );
            },
          ),
          if (positiveSum > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 9,
                child: Row(
                  children: [
                    for (final category in _categories)
                      if ((subtotal[category.key] ?? 0) > 0)
                        Expanded(
                          flex: math.max(1, ((subtotal[category.key] ?? 0) / positiveSum * 1000).round()),
                          child: ColoredBox(color: _tone(category.key)),
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 21),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Conceptos detallados',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              Text(
                '${groups.length} conceptos',
                style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() => _showAll = false),
            decoration: InputDecoration(
              hintText: 'Buscar un gasto, cargo o descripción',
              hintStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () => setState(_searchController.clear),
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: palette.background.withOpacity(0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 37,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() {
                      _categoryFilter = null;
                      _showAll = false;
                    }),
                  ),
                ),
                for (final category in _categories)
                  if ((counts[category.key] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(category.title),
                        selected: _categoryFilter == category.key,
                        onSelected: (_) => setState(() {
                          _categoryFilter = category.key;
                          _showAll = false;
                        }),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.manage_search_rounded, size: 35, color: palette.textSecondary),
                  const SizedBox(height: 9),
                  Text(
                    widget.items.isEmpty
                        ? 'Todavía no hay gastos para este período.'
                        : 'No hay conceptos que coincidan con los filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else ...[
            for (final group in visible) _expenseRow(group, positiveSum),
            if (groups.length > 8)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showAll ? 'Mostrar menos' : 'Ver todos los ${groups.length} conceptos'),
                ),
              ),
          ],
          if (hasExpected && difference.abs() > 0.01)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'El total detallado es ${CurrencyUtils.format(detailedTotal)}; difiere del gasto operativo calculado por el servidor. Revisa los datos del período.',
                style: TextStyle(color: palette.warning, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
