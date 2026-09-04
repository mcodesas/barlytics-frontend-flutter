import 'package:flutter/foundation.dart';

enum AppUpdatePlatform {
  windows('windows', 'Windows'),
  macos('macos', 'macOS'),
  linux('linux', 'Linux'),
  android('android', 'Android'),
  ios('ios', 'iPhone / iPad');

  const AppUpdatePlatform(this.key, this.label);

  final String key;
  final String label;

  bool get isDesktop => this == windows || this == macos || this == linux;
  bool get isMobile => this == android || this == ios;

  static AppUpdatePlatform? current() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => AppUpdatePlatform.windows,
      TargetPlatform.macOS => AppUpdatePlatform.macos,
      TargetPlatform.linux => AppUpdatePlatform.linux,
      TargetPlatform.android => AppUpdatePlatform.android,
      TargetPlatform.iOS => AppUpdatePlatform.ios,
      _ => null,
    };
  }
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    required this.enabled,
    required this.mandatory,
    required this.releaseNotes,
    required this.publishedAt,
  });

  final String version;
  final int build;
  final String url;
  final String sha256;
  final bool enabled;
  final bool mandatory;
  final String releaseNotes;
  final DateTime? publishedAt;

  String get displayVersion => '$version+$build';
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.version,
    required this.build,
    required this.mandatory,
    required this.releaseNotes,
    required this.publishedAt,
    required this.platforms,
    required this.legacyUrls,
  });

  final String version;
  final int build;
  final bool mandatory;
  final String releaseNotes;
  final DateTime? publishedAt;
  final Map<String, Map<String, dynamic>> platforms;
  final Map<String, String> legacyUrls;

  factory AppUpdateManifest.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('El manifiesto de actualizaciones no es válido.');
    }
    final data = Map<String, dynamic>.from(json);
    final version = data['version']?.toString().trim() ?? '';
    final build = _asInt(data['build']);
    if (version.isEmpty || build <= 0) {
      throw const FormatException('El manifiesto no contiene versión/build válidos.');
    }

    final platformData = <String, Map<String, dynamic>>{};
    final rawPlatforms = data['platforms'];
    if (rawPlatforms is Map) {
      for (final entry in rawPlatforms.entries) {
        if (entry.value is Map) {
          platformData[entry.key.toString().toLowerCase()] =
              Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }

    final legacyUrls = <String, String>{};
    for (final key in const ['windows', 'macos', 'linux', 'android', 'ios']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) legacyUrls[key] = value;
    }

    return AppUpdateManifest(
      version: version,
      build: build,
      mandatory: _asBool(data['mandatory']),
      releaseNotes: data['releaseNotes']?.toString().trim() ?? '',
      publishedAt: DateTime.tryParse(data['publishedAt']?.toString() ?? ''),
      platforms: platformData,
      legacyUrls: legacyUrls,
    );
  }

  AppUpdateRelease releaseFor(AppUpdatePlatform platform, {String fallbackUrl = ''}) {
    final data = platforms[platform.key] ?? const <String, dynamic>{};
    final platformVersion = data['version']?.toString().trim();
    final platformBuild = _asInt(data['build']);
    final url = (data['url']?.toString().trim().isNotEmpty ?? false)
        ? data['url'].toString().trim()
        : (legacyUrls[platform.key]?.trim().isNotEmpty ?? false)
            ? legacyUrls[platform.key]!.trim()
            : fallbackUrl.trim();

    return AppUpdateRelease(
      version: platformVersion == null || platformVersion.isEmpty ? version : platformVersion,
      build: platformBuild > 0 ? platformBuild : build,
      url: url,
      sha256: data['sha256']?.toString().trim().toLowerCase() ?? '',
      enabled: data.containsKey('enabled') ? _asBool(data['enabled']) : true,
      mandatory: data.containsKey('mandatory') ? _asBool(data['mandatory']) : mandatory,
      releaseNotes: (data['releaseNotes']?.toString().trim().isNotEmpty ?? false)
          ? data['releaseNotes'].toString().trim()
          : releaseNotes,
      publishedAt: DateTime.tryParse(data['publishedAt']?.toString() ?? '') ?? publishedAt,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si';
  }
}

class AppUpdateCandidate {
  const AppUpdateCandidate({
    required this.platform,
    required this.currentVersion,
    required this.currentBuild,
    required this.release,
  });

  final AppUpdatePlatform platform;
  final String currentVersion;
  final int currentBuild;
  final AppUpdateRelease release;
}

int compareAppVersions({
  required String currentVersion,
  required int currentBuild,
  required String latestVersion,
  required int latestBuild,
}) {
  final current = _versionParts(currentVersion);
  final latest = _versionParts(latestVersion);
  final length = current.length > latest.length ? current.length : latest.length;
  for (var i = 0; i < length; i++) {
    final a = i < current.length ? current[i] : 0;
    final b = i < latest.length ? latest[i] : 0;
    if (a != b) return a.compareTo(b);
  }
  return currentBuild.compareTo(latestBuild);
}

List<int> _versionParts(String value) {
  final clean = value.trim().split('-').first;
  return clean.split('.').map((part) => int.tryParse(part) ?? 0).toList(growable: false);
}
