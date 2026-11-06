import 'dart:io';

/// Información técnica de sistema operativo; no incluye nombre de usuario,
/// directorios personales ni números de serie.
String errorDeviceContext() =>
    Platform.operatingSystem + ' ' + Platform.operatingSystemVersion;
