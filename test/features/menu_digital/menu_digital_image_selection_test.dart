import 'dart:convert';
import 'dart:typed_data';

import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_image_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Detecta PNG por firma y crea data URI correcta', () {
    final bytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x01, 0x02,
    ]);
    expect(MenuDigitalImageSelection.mimeType(bytes), 'image/png');
    expect(MenuDigitalImageSelection.dataUri(bytes, maxBytes: 10),
        'data:image/png;base64,${base64Encode(bytes)}');
  });

  test('Detecta JPEG y WEBP y bloquea formatos extraños', () {
    expect(MenuDigitalImageSelection.mimeType(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00])),
        'image/jpeg');
    expect(MenuDigitalImageSelection.mimeType(Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
      0x57, 0x45, 0x42, 0x50,
    ])), 'image/webp');
    expect(MenuDigitalImageSelection.mimeType(
        Uint8List.fromList([0, 1, 2, 3])), isNull);
    expect(MenuDigitalImageSelection.dataUri(
        Uint8List.fromList([0, 1, 2, 3]), maxBytes: 100), isNull);
  });

  test('Impide imágenes mayores al límite backend', () {
    final bytes = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0x00, 0x01,
    ]);
    expect(MenuDigitalImageSelection.dataUri(
        bytes, maxBytes: 4), isNull);
    expect(MenuDigitalImageSelection.dataUri(
        bytes, maxBytes: 5), isNotNull);
  });
}
