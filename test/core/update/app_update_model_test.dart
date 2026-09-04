import 'package:barlytics_frontend/core/update/app_update_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareAppVersions', () {
    test('detecta una version semantica superior', () {
      expect(
        compareAppVersions(
          currentVersion: '1.0.0',
          currentBuild: 10,
          latestVersion: '1.1.0',
          latestBuild: 1,
        ),
        lessThan(0),
      );
    });

    test('usa build cuando la version es igual', () {
      expect(
        compareAppVersions(
          currentVersion: '1.0.0',
          currentBuild: 1,
          latestVersion: '1.0.0',
          latestBuild: 2,
        ),
        lessThan(0),
      );
    });

    test('no actualiza si la instalada es igual o superior', () {
      expect(
        compareAppVersions(
          currentVersion: '2.0.0',
          currentBuild: 1,
          latestVersion: '1.9.9',
          latestBuild: 99,
        ),
        greaterThan(0),
      );
    });
  });

  test('manifiesto resuelve URL y checksum por plataforma', () {
    final manifest = AppUpdateManifest.fromJson({
      'version': '1.2.0',
      'build': 8,
      'mandatory': false,
      'publishedAt': '2026-09-04T18:00:00Z',
      'platforms': {
        'windows': {
          'url': 'https://www.barlytics.com.co/downloads/BarLytics-Windows-Setup.exe',
          'sha256': 'ABC123',
        },
      },
    });

    final release = manifest.releaseFor(AppUpdatePlatform.windows);
    expect(release.version, '1.2.0');
    expect(release.build, 8);
    expect(release.sha256, 'abc123');
    expect(release.url, endsWith('.exe'));
  });

  test('móvil utiliza URL pública de respaldo cuando latest.json no la incluye', () {
    final manifest = AppUpdateManifest.fromJson({
      'version': '1.2.0',
      'build': 8,
    });
    final release = manifest.releaseFor(
      AppUpdatePlatform.android,
      fallbackUrl: 'https://play.google.com/store/apps/details?id=com.barlytics.barlytics_frontend',
    );
    expect(release.url, contains('play.google.com'));
  });
}
