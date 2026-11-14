import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// PNG del QR generado en el dispositivo.
/// No consulta el endpoint /qr: permite descargar desde Flutter Web, iOS,
/// Android y escritorio aunque el servidor de imágenes falle con HTTP 500.
class MenuDigitalQrImage {
  MenuDigitalQrImage._();

  static QrPainter _painter(String url) {
    if (!url.startsWith('https://')) {
      throw const FormatException('No existe un enlace HTTPS para la carta.');
    }
    return QrPainter(
      data: url,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square, color: Color(0xFF0B1724)),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0B1724)),
    );
  }

  /// PNG de 760 x 760 con quiet zone blanca alrededor del código.
  static Future<Uint8List> png(String url) async {
    const size = 760.0;
    const quietZone = 36.0;
    final painter = _painter(url);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, size, size),
      ui.Paint()..color = Colors.white,
    );
    canvas.save();
    canvas.translate(quietZone, quietZone);
    painter.paint(canvas,
        const ui.Size(size - 2 * quietZone, size - 2 * quietZone));
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size.toInt(), size.toInt());
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('El dispositivo no pudo generar la imagen PNG.');
        }
        return data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  static Widget preview(String url, {double size = 180}) {
    return QrImageView(
      data: url,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      size: size,
      padding: const EdgeInsets.all(10),
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square, color: Color(0xFF0B1724)),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0B1724)),
    );
  }
}
