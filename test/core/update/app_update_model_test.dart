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

  test('manifest de release incremental detecta compilación nueva', () {
    final manifest = AppUpdateManifest.fromJson({
      'version': '1.0.0',
      'build': 2014320100,
      'platforms': {
        'windows': {
          'version': '1.0.0',
          'build': 2014320100,
          'enabled': true,
          'url': 'https://www.barlytics.com.co/downloads/BarLytics-Windows-Setup.exe',
        },
        'macos': {
          'version': '1.0.0',
          'build': 2014320000,
          'enabled': true,
          'url': 'https://www.barlytics.com.co/downloads/BarLytics-macOS.dmg',
        },
        'android': {
          'version': '1.0.0',
          'build': 2014320100,
          'enabled': true,
          'url': 'https://play.google.com/store/apps/details?id=com.mcode.barlytics',
        },
        'ios': {
          'version': '1.0.0',
          'build': 2026110421151,
          'enabled': true,
          'channel': 'testflight',
          'url': 'https://apps.apple.com/app/testflight/id899247664',
        },
      },
    });
    final windows = manifest.releaseFor(AppUpdatePlatform.windows);
    final macos = manifest.releaseFor(AppUpdatePlatform.macos);
    final ios = manifest.releaseFor(AppUpdatePlatform.ios);
    expect(compareAppVersions(
      currentVersion: '1.0.0', currentBuild: 1,
      latestVersion: windows.version, latestBuild: windows.build,
    ), lessThan(0));
    expect(macos.build, lessThan(windows.build));
    expect(ios.channel, 'testflight');
    expect(ios.enabled, isTrue);
    expect(compareAppVersions(
      currentVersion: '1.0.0', currentBuild: ios.build,
      latestVersion: ios.version, latestBuild: ios.build,
    ), 0);
  });

  test('nunca muestra update deshabilitado o el build instalado', () {
    final manifest = AppUpdateManifest.fromJson({
      'version': '1.0.0',
      'build': 20,
      'platforms': {
        'android': {'enabled': false, 'build': 22},
      },
    });
    expect(manifest.releaseFor(AppUpdatePlatform.android).enabled, isFalse);
    expect(compareAppVersions(
      currentVersion: '1.0.0', currentBuild: 20,
      latestVersion: '1.0.0', latestBuild: 20,
    ), 0);
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
