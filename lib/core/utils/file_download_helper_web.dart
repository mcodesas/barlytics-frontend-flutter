import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

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
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
