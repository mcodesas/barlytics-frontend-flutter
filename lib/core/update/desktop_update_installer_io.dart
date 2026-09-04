import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

Future<void> downloadAndLaunchDesktopUpdate({
  required String url,
  required String expectedSha256,
  required String platformKey,
  required String version,
  required int build,
  void Function(double progress)? onProgress,
}) async {
  final extension = switch (platformKey) {
    'windows' => '.exe',
    'macos' => '.dmg',
    'linux' => '.deb',
    _ => '',
  };
  if (extension.isEmpty) {
    throw UnsupportedError('Plataforma de escritorio no soportada: $platformKey');
  }

  final updateDir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}barlytics-updates');
  await updateDir.create(recursive: true);
  final file = File(
    '${updateDir.path}${Platform.pathSeparator}BarLytics-$version-$build$extension',
  );
  if (await file.exists()) await file.delete();

  final uri = Uri.parse(url);
  final cacheBusted = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'v': '$version-$build',
    },
  );

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 25),
      followRedirects: true,
    ),
  );

  try {
    await dio.download(
      cacheBusted.toString(),
      file.path,
      deleteOnError: true,
      options: Options(
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0).toDouble());
        }
      },
    );

    final normalizedExpected = expectedSha256.trim().toLowerCase();
    if (normalizedExpected.isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;
      final actual = digest.toString().toLowerCase();
      if (actual != normalizedExpected) {
        await file.delete();
        throw StateError('La firma SHA-256 del instalador no coincide con la versión publicada.');
      }
    }

    onProgress?.call(1.0);
    await _launch(file.path);
  } on DioException catch (error) {
    if (await file.exists()) await file.delete();
    throw StateError('No fue posible descargar la actualización: ${error.message ?? 'error de red'}');
  }
}

Future<void> _launch(String filePath) async {
  if (Platform.isWindows) {
    await Process.start(
      filePath,
      const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/CLOSEAPPLICATIONS',
        '/NORESTART',
      ],
      mode: ProcessStartMode.detached,
    );
    // El instalador reemplaza BarLytics.exe y vuelve a abrir la aplicación al
    // finalizar. Esta instancia debe salir para liberar los binarios.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    exit(0);
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [filePath]);
    if (result.exitCode != 0) {
      throw ProcessException('open', [filePath], result.stderr.toString(), result.exitCode);
    }
    return;
  }

  if (Platform.isLinux) {
    try {
      final result = await Process.run('xdg-open', [filePath]);
      if (result.exitCode == 0) return;
    } on ProcessException {
      // Se intenta el fallback de GNOME a continuación.
    }
    final result = await Process.run('gio', ['open', filePath]);
    if (result.exitCode != 0) {
      throw ProcessException('gio', ['open', filePath], result.stderr.toString(), result.exitCode);
    }
    return;
  }

  throw UnsupportedError('La instalación de escritorio no está disponible en esta plataforma.');
}
