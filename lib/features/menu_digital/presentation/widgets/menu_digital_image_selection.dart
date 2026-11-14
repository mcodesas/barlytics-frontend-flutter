import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Selección orientada a la fototeca del dispositivo.
/// Android/iOS utilizan el selector de fotos nativo. En web el navegador
/// conserva el control de la interfaz del selector del sistema operativo.
class MenuDigitalImageSelection {
  MenuDigitalImageSelection._();

  static final ImagePicker _picker = ImagePicker();

  /// El limite de imágenes también se controla tras recibir el resultado,
  /// porque algunos navegadores no respetan el máximo solicitado.
  static Future<List<XFile>> fromGallery({
    int limit = 1,
    double maxDimension = 1400,
    int quality = 72,
  }) async {
    if (limit < 1) return const [];
    if (limit == 1) {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: quality,
        requestFullMetadata: false,
      );
      return photo == null ? const [] : [photo];
    }
    final photos = await _picker.pickMultiImage(
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
      limit: limit,
      requestFullMetadata: false,
    );
    return photos.take(limit).toList();
  }

  /// Nunca confiar en la extensión de archivo: la API solo permite estos
  /// tres tipos y acepta su firma binaria real.
  static String? mimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A &&
        bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF &&
        bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static String? dataUri(Uint8List bytes, {required int maxBytes}) {
    if (bytes.isEmpty || bytes.length > maxBytes) return null;
    final mime = mimeType(bytes);
    if (mime == null) return null;
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
