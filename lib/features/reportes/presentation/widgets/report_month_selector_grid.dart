import 'package:flutter/material.dart';

/// Cuadrícula de meses sin viewport con scroll propio.
///
/// AlertDialog mide el tamaño intrínseco de su contenido. GridView.builder
/// (aun con shrinkWrap: true) no puede calcularlo y provoca
/// RenderShrinkWrappingViewport.debugThrowIfNotCheckingIntrinsics.
/// Cuatro filas normales permiten que AlertDialog sea el único scrollable.
class ReportMonthSelectorGrid extends StatelessWidget {
  const ReportMonthSelectorGrid({
    super.key,
    required this.monthNames,
    required this.selectedYear,
    required this.selectedMonth,
    required this.currentYear,
    required this.currentMonth,
    required this.onSelected,
  }) : assert(monthNames.length == 12);

  final List<String> monthNames;
  final int selectedYear;
  final int selectedMonth;
  final int currentYear;
  final int currentMonth;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 3 ? 0 : 8),
            child: Row(
              children: [
                for (var column = 0; column < 3; column++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: column == 2 ? 0 : 8),
                      child: _monthButton(
                        scheme,
                        row * 3 + column + 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _monthButton(ColorScheme scheme, int month) {
    final futureMonth =
        selectedYear == currentYear && month > currentMonth;
    final selected = selectedMonth == month;

    return Material(
      color: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withOpacity(.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: futureMonth ? null : () => onSelected(month),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withOpacity(.55),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              monthNames[month - 1],
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: futureMonth
                    ? scheme.onSurface.withOpacity(.30)
                    : selected
                        ? scheme.onPrimary
                        : scheme.onSurface,
                fontWeight: selected
                    ? FontWeight.w900
                    : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
