import 'dart:typed_data';

import 'package:archive/archive.dart';

/// XLSX con detalle y resumen generado en el dispositivo cuando el servidor
/// no puede exportar. Las cadenas inline impiden ejecutar fórmulas de usuarios.
Uint8List buildInventoryHistoryXlsx({
  required List<List<Object?>> detail,
  required List<List<Object?>> summary,
}) {
  final archive = Archive();
  void add(String path, String xml) {
    archive.addFile(ArchiveFile.string(path, xml));
  }

  add('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''');
  add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');
  add('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Todos los conteos" sheetId="1" r:id="rId1"/>
<sheet name="Resumen" sheetId="2" r:id="rId2"/></sheets>
</workbook>''');
  add('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');
  add('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2">
<font><sz val="11"/><name val="Aptos"/></font>
<font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font>
</fonts>
<fills count="2">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FF087D8A"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="1" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
</cellXfs>
</styleSheet>''');
  add('xl/worksheets/sheet1.xml', _worksheet(detail, filter: true));
  add('xl/worksheets/sheet2.xml', _worksheet(summary, filter: false));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _worksheet(List<List<Object?>> rows, {required bool filter}) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" ')
    ..write('topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
    ..write('<sheetData>');
  for (var r = 0; r < rows.length; r++) {
    buffer.write('<row r="' + (r + 1).toString() + '">');
    for (var c = 0; c < rows[r].length; c++) {
      final address = _column(c) + (r + 1).toString();
      final value = rows[r][c];
      final header = r == 0 ? ' s="1"' : '';
      if (value is num && value.isFinite) {
        buffer.write('<c r="$address"$header><v>$value</v></c>');
      } else {
        buffer.write('<c r="$address" t="inlineStr"$header><is><t xml:space="preserve">');
        buffer.write(_escape(value?.toString() ?? ''));
        buffer.write('</t></is></c>');
      }
    }
    buffer.write('</row>');
  }
  buffer.write('</sheetData>');
  if (filter && rows.length > 1 && rows.first.isNotEmpty) {
    final region = 'A1:' + _column(rows.first.length - 1) +
        rows.length.toString();
    buffer.write('<autoFilter ref="$region"/>');
  }
  buffer.write('</worksheet>');
  return buffer.toString();
}

String _column(int index) {
  var value = index + 1;
  var output = '';
  while (value > 0) {
    value--;
    output = String.fromCharCode(65 + value % 26) + output;
    value ~/= 26;
  }
  return output;
}

String _escape(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
