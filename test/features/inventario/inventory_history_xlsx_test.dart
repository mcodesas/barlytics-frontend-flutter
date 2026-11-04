import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/inventario/presentation/utils/inventory_history_xlsx.dart';

void main() {
  test('El Excel local es ZIP XLSX y contiene detalle y resumen', () {
    final bytes = buildInventoryHistoryXlsx(
      detail: [
        ['Producto', 'Contado', 'Stock sistema'],
        ['Antioqueño Azul Media', 0, 'Sin movimientos'],
        ['Millonarios = nombre', 12, 4],
      ],
      summary: [
        ['BARLYTICS | RESUMEN', 'Valor'],
        ['Productos contados', 2],
      ],
    );
    expect(bytes.sublist(0, 2), [0x50, 0x4b]);
    final decoded = ZipDecoder().decodeBytes(bytes);
    final names = decoded.files.map((entry) => entry.name).toSet();
    expect(names, containsAll([
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
      'xl/worksheets/sheet2.xml',
    ]));
  });

  test('Genera Excel con solamente encabezados cuando no hay datos', () {
    final bytes = buildInventoryHistoryXlsx(
      detail: [ ['Producto', 'Esperado', 'Contado'] ],
      summary: [ ['Campo', 'Valor'], ['Productos', 0] ],
    );
    expect(bytes.length, greaterThan(300));
    expect(ZipDecoder().decodeBytes(bytes).files.length, 7);
  });

  test('Maneja acentos y nombres con caracteres XML de forma segura', () {
    final bytes = buildInventoryHistoryXlsx(
      detail: [
        ['Producto', 'Contado'],
        ['Cerveza Águila & <carta>', 0],
        ['=HYPERLINK("malicioso")', 1],
      ],
      summary: [['Métrica', 'Valor']],
    );
    expect(ZipDecoder().decodeBytes(bytes).files.length, 7);
  });
}
