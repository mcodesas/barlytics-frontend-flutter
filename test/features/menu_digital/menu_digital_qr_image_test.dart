import 'dart:typed_data';

import 'package:barlytics_frontend/features/menu_digital/domain/menu_digital_qr_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QR no permite un enlace sin HTTPS', () async {
    await expectLater(
      MenuDigitalQrImage.png('http://example.com'),
      throwsFormatException,
    );
  });

  test('El QR PNG se genera sin solicitar una URL al servidor', () async {
    final data = await MenuDigitalQrImage.png(
      'https://www.barlytics.com.co/api/v1/menu-digital/public/'
      '123e4567-e89b-12d3-a456-426614174000/compartir',
    );
    expect(data, isA<Uint8List>());
    expect(data.take(8).toList(),
        [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(ByteData.sublistView(data, 16, 20).getUint32(0), 760);
    expect(ByteData.sublistView(data, 20, 24).getUint32(0), 760);
  });
}
