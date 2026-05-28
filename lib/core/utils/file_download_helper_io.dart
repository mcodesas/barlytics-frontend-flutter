import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  await downloadBytesFile(
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: mimeType,
  );
}

Future<void> downloadBytesFile({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: fileName,
    bytes: bytes,
  );
}
