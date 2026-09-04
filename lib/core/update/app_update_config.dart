class AppUpdateConfig {
  const AppUpdateConfig._();

  // Los workflows de release inyectan estos valores leyendo pubspec.yaml.
  // Los defaults mantienen coherencia con la versión actual para builds manuales.
  static const currentVersion = String.fromEnvironment(
    'BARLYTICS_APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const currentBuild = int.fromEnvironment(
    'BARLYTICS_APP_BUILD',
    defaultValue: 1,
  );

  static const fallbackManifestUrl = String.fromEnvironment(
    'BARLYTICS_UPDATE_MANIFEST_URL',
    defaultValue: 'https://www.barlytics.com.co/downloads/latest.json',
  );

  static const enableInDebug = bool.fromEnvironment(
    'BARLYTICS_ENABLE_UPDATES',
    defaultValue: false,
  );
}
