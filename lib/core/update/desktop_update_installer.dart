import 'desktop_update_installer_stub.dart'
    if (dart.library.io) 'desktop_update_installer_io.dart' as implementation;

Future<void> downloadAndLaunchDesktopUpdate({
  required String url,
  required String expectedSha256,
  required String platformKey,
  required String version,
  required int build,
  void Function(double progress)? onProgress,
}) {
  return implementation.downloadAndLaunchDesktopUpdate(
    url: url,
    expectedSha256: expectedSha256,
    platformKey: platformKey,
    version: version,
    build: build,
    onProgress: onProgress,
  );
}
