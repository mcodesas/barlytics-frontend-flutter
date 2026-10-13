// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveDownloadedFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String dialogTitle,
  required String mimeType,
  required List<String> allowedExtensions,
}) async {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  return fileName;
}
