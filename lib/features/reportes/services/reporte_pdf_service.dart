import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportePdfService {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );
  static final NumberFormat _number = NumberFormat.decimalPattern('es_CO');

  Future<Uint8List> build({
    required String title,
    required String description,
    required DateTime? start,
    required DateTime? end,
    required String branchName,
    required List<Map<String, dynamic>> rows,
    required Map<String, dynamic> metrics,
    required List<String> currencyKeys,
    required List<String> percentageKeys,
    String? chartLabelKey,
    String? chartValueKey,
    bool signedChart = false,
  }) async {
    final pdf = pw.Document();

    final printableRows = rows.take(500).toList(growable: false);
    final columns = _resolveColumns(printableRows);
    final chartRows = _chartRows(
      rows: printableRows,
      labelKey: chartLabelKey,
      valueKey: chartValueKey,
    );

    final pageFormat = columns.length > 10
        ? PdfPageFormat.a3.landscape
        : columns.length > 6
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4;
    final tableFontSize = columns.length > 14
        ? 4.4
        : columns.length > 10
            ? 5.2
            : columns.length > 7
                ? 6.2
                : 7.0;
    final tablePadding = columns.length > 12
        ? 2.4
        : columns.length > 8
            ? 3.2
            : 5.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BarLytics · $title',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text(
                      'Página ${context.pageNumber} de ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ],
                ),
              ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generado por BarLytics',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey600,
                ),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          _header(
            title: title,
            description: description,
            start: start,
            end: end,
            branchName: branchName,
          ),
          if (metrics.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Indicadores principales'),
            pw.SizedBox(height: 8),
            _metricsGrid(metrics, currencyKeys, percentageKeys),
          ],
          if (chartRows.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Gráfico'),
            pw.SizedBox(height: 8),
            _horizontalBars(
              chartRows,
              chartValueKey!,
              currencyKeys.contains(chartValueKey),
              percentageKeys.contains(chartValueKey),
              signedChart,
            ),
          ],
          pw.SizedBox(height: 14),
          _sectionTitle('Detalle (${rows.length} registros)'),
          pw.SizedBox(height: 8),
          if (printableRows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'No hay información para los filtros seleccionados.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            )
          else
            pw.Table.fromTextArray(
              headers: columns.map(_humanize).toList(growable: false),
              data: printableRows
                  .map(
                    (row) => columns
                        .map(
                          (key) => _formatValue(
                            row[key],
                            currency: currencyKeys.contains(key),
                            percentage: percentageKeys.contains(key),
                          ),
                        )
                        .toList(growable: false),
                  )
                  .toList(growable: false),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: tableFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(fontSize: tableFontSize),
              cellPadding: pw.EdgeInsets.symmetric(
                horizontal: tablePadding,
                vertical: 4,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          if (rows.length > printableRows.length) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'El PDF incluye los primeros ${printableRows.length} registros de ${rows.length}.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.blueGrey600,
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _header({
    required String title,
    required String description,
    required DateTime? start,
    required DateTime? end,
    required String branchName,
  }) {
    final period = start == null || end == null
        ? 'Corte actual'
        : '${DateFormat('dd/MM/yyyy').format(start)} al ${DateFormat('dd/MM/yyyy').format(end)}';

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BarLytics',
            style: pw.TextStyle(
              color: PdfColors.lightBlue100,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            description,
            style: const pw.TextStyle(
              color: PdfColors.blueGrey100,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag('Periodo: $period'),
              _tag('Sucursal: $branchName'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _tag(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey700,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          text,
          style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
        ),
      );

  pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      );

  pw.Widget _metricsGrid(
    Map<String, dynamic> metrics,
    List<String> currencyKeys,
    List<String> percentageKeys,
  ) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics.entries
          .map(
            (entry) => pw.Container(
              width: 158,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _humanize(entry.key),
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _formatValue(
                      entry.value,
                      currency: currencyKeys.contains(entry.key),
                      percentage: percentageKeys.contains(entry.key),
                    ),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  pw.Widget _horizontalBars(
    List<Map<String, dynamic>> rows,
    String valueKey,
    bool currency,
    bool percentage,
    bool signed,
  ) {
    final maxValue = rows
        .map((row) => _toDouble(row[valueKey]).abs())
        .fold<double>(0, (currentMax, value) => currentMax > value ? currentMax : value);

    return pw.Column(
      children: rows.take(10).map((row) {
        final label = row['_chart_label']?.toString() ?? '-';
        final value = _toDouble(row[valueKey]);
        final factor = maxValue <= 0 ? 0.0 : (value.abs() / maxValue).clamp(0.0, 1.0);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      label,
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    _formatValue(
                      value,
                      currency: currency,
                      percentage: percentage,
                    ),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                height: 7,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 470 * factor,
                  decoration: pw.BoxDecoration(
                    color: signed
                        ? (value < 0 ? PdfColors.red : PdfColors.green)
                        : PdfColors.lightBlue700,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  List<Map<String, dynamic>> _chartRows({
    required List<Map<String, dynamic>> rows,
    required String? labelKey,
    required String? valueKey,
  }) {
    if (labelKey == null || valueKey == null) return const [];
    return rows
        .where((row) => row.containsKey(labelKey) && row.containsKey(valueKey))
        .map(
          (row) => <String, dynamic>{
            ...row,
            '_chart_label': _formatValue(row[labelKey]),
          },
        )
        .toList(growable: false);
  }

  List<String> _resolveColumns(List<Map<String, dynamic>> rows) {
    const hidden = <String>{
      'estado_prioridad',
      'diferencia_absoluta',
    };
    const preferred = <String>[
      'producto',
      'fecha_conteo',
      'stock_esperado',
      'conteo_fisico',
      'diferencia_unidades',
      'unidades_por_presentacion',
      'diferencia_presentaciones',
      'estado_conteo',
      'diferencia_porcentaje',
      'diferencia_valor_compra',
      'responsable',
    ];
    final available = <String>[];
    for (final row in rows.take(20)) {
      for (final key in row.keys) {
        if (key.startsWith('_') || key.endsWith('_id') || hidden.contains(key)) {
          continue;
        }
        if (!available.contains(key)) available.add(key);
      }
    }
    final columns = <String>[
      ...preferred.where(available.contains),
      ...available.where((key) => !preferred.contains(key)),
    ];
    return columns;
  }

  String _formatValue(
    dynamic value, {
    bool currency = false,
    bool percentage = false,
  }) {
    if (value == null) return '-';
    if (currency && value is num) return _currency.format(value);
    if (percentage && value is num) return '${value.toStringAsFixed(1)} %';
    if (value is num) {
      if (value % 1 == 0) return _number.format(value.toInt());
      return NumberFormat.decimalPatternDigits(locale: 'es_CO', decimalDigits: 2)
          .format(value);
    }
    if (value is DateTime) return DateFormat('dd/MM/yyyy HH:mm').format(value);
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
      return text.length <= 10
          ? DateFormat('dd/MM/yyyy').format(parsed)
          : DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
    }
    return text.trim().isEmpty ? '-' : text;
  }

  String _humanize(String value) {
    final spaced = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return 'Dato';
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
