import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveDownloadedFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String dialogTitle,
  required String mimeType,
  required List<String> allowedExtensions,
}) {
  return FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    bytes: bytes,
  );
}
