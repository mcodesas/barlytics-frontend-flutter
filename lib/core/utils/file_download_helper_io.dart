import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  return downloadBytesFile(
    fileName: fileName,
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: mimeType,
  );
}

Future<bool> downloadBytesFile({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final extensions = _extension(fileName);

  if (Platform.isAndroid || Platform.isIOS) {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar archivo',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extensions,
      bytes: bytes,
    );
    return result != null;
  }

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (path == null) return false;

  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}

List<String>? _extension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  return <String>[fileName.substring(dot + 1).toLowerCase()];
}
