import 'dart:typed_data';

import 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart' as implementation;

Future<String?> saveDownloadedFile({
  required Uint8List bytes,
  required String fileName,
  required String dialogTitle,
  required String mimeType,
  required List<String> allowedExtensions,
}) {
  return implementation.saveDownloadedFileImpl(
    bytes: bytes,
    fileName: fileName,
    dialogTitle: dialogTitle,
    mimeType: mimeType,
    allowedExtensions: allowedExtensions,
  );
}
