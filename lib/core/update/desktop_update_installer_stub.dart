Future<void> downloadAndLaunchDesktopUpdate({
  required String url,
  required String expectedSha256,
  required String platformKey,
  required String version,
  required int build,
  void Function(double progress)? onProgress,
}) {
  throw UnsupportedError('La instalación automática no está disponible en esta plataforma.');
}
