import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/environment.dart';
import '../config/public_site_config.dart';
import '../constants/api_paths.dart';
import '../network/api_client.dart';
import 'app_update_config.dart';
import 'app_update_model.dart';
import 'desktop_update_installer.dart';

class AppUpdateService {
  AppUpdateService(this._apiClient);

  static const _snoozeDuration = Duration(hours: 8);
  final ApiClient _apiClient;

  Future<AppUpdateCandidate?> checkForUpdate({bool ignoreSnooze = false}) async {
    if (kIsWeb) return null;
    if (Environment.current != EnvironmentType.prod && !AppUpdateConfig.enableInDebug) return null;
    if (kDebugMode && !AppUpdateConfig.enableInDebug) return null;

    final platform = AppUpdatePlatform.current();
    if (platform == null) return null;

    PublicSiteConfig publicConfig = PublicSiteConfig.empty;
    try {
      final response = await _apiClient.get<PublicSiteConfig>(
        ApiPaths.publicSiteConfig,
        PublicSiteConfig.fromJson,
      );
      publicConfig = response.data ?? PublicSiteConfig.empty;
    } catch (_) {
      // El manifiesto público tiene una URL estable de respaldo, por lo que una
      // indisponibilidad temporal del backend no debe bloquear la comprobación.
    }

    final manifestUrl = publicConfig.updateManifestUrl.trim().isNotEmpty
        ? publicConfig.updateManifestUrl.trim()
        : AppUpdateConfig.fallbackManifestUrl;
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || !_isAllowedUpdateUri(uri)) return null;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ),
    );

    final manifestUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'check': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await dio.get<Object?>(manifestUri.toString());
    final manifest = AppUpdateManifest.fromJson(response.data);
    final release = manifest.releaseFor(
      platform,
      fallbackUrl: publicConfig.downloadUrlFor(platform.key),
    );

    if (!release.enabled) return null;

    final downloadUri = Uri.tryParse(release.url);
    if (!_isAllowedUpdateUri(downloadUri)) {
      // Android/iOS solo se activan cuando BARLYTICS_DOWNLOAD_*_URL apunta a
      // su tienda. Desktop obtiene la URL directamente de latest.json.
      return null;
    }

    final comparison = compareAppVersions(
      currentVersion: AppUpdateConfig.currentVersion,
      currentBuild: AppUpdateConfig.currentBuild,
      latestVersion: release.version,
      latestBuild: release.build,
    );
    if (comparison >= 0) return null;

    final candidate = AppUpdateCandidate(
      platform: platform,
      currentVersion: AppUpdateConfig.currentVersion,
      currentBuild: AppUpdateConfig.currentBuild,
      release: release,
    );

    if (!ignoreSnooze && !release.mandatory && await _isSnoozed(candidate)) {
      return null;
    }
    return candidate;
  }

  Future<void> snooze(AppUpdateCandidate candidate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeKey(candidate),
      DateTime.now().add(_snoozeDuration).millisecondsSinceEpoch,
    );
  }

  Future<void> performUpdate(
    AppUpdateCandidate candidate, {
    void Function(double progress)? onProgress,
  }) async {
    if (candidate.platform.isDesktop) {
      await downloadAndLaunchDesktopUpdate(
        url: candidate.release.url,
        expectedSha256: candidate.release.sha256,
        platformKey: candidate.platform.key,
        version: candidate.release.version,
        build: candidate.release.build,
        onProgress: onProgress,
      );
      return;
    }

    final uri = Uri.tryParse(candidate.release.url);
    if (uri == null || !_isAllowedUpdateUri(uri)) {
      throw StateError('La URL de actualización móvil no es válida.');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('No fue posible abrir la tienda de aplicaciones.');
    }
  }

  Future<bool> _isSnoozed(AppUpdateCandidate candidate) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_snoozeKey(candidate)) ?? 0;
    if (until <= DateTime.now().millisecondsSinceEpoch) {
      if (until > 0) await prefs.remove(_snoozeKey(candidate));
      return false;
    }
    return true;
  }

  bool _isAllowedUpdateUri(Uri? uri) {
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme.toLowerCase() == 'https') return true;
    return AppUpdateConfig.enableInDebug && uri.scheme.toLowerCase() == 'http';
  }

  String _snoozeKey(AppUpdateCandidate candidate) =>
      'barlytics_update_snooze_${candidate.platform.key}_${candidate.release.version}_${candidate.release.build}';
}
