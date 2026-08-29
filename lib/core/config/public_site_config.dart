class PublicSiteConfig {
  const PublicSiteConfig({
    required this.whatsappNumber,
    required this.windowsDownloadUrl,
    required this.macDownloadUrl,
    required this.iosDownloadUrl,
    required this.androidDownloadUrl,
    required this.linuxDownloadUrl,
  });

  /// Configuración vacía mientras el frontend consulta el backend.
  static const empty = PublicSiteConfig(
    whatsappNumber: '',
    windowsDownloadUrl: '',
    macDownloadUrl: '',
    iosDownloadUrl: '',
    androidDownloadUrl: '',
    linuxDownloadUrl: '',
  );

  /// Carpeta web o URL base donde se publican las grabaciones reales de la demo.
  /// Esta clave no forma parte de los parámetros comerciales solicitados y se
  /// mantiene como configuración de compilación del contenido estático.
  static const demoMediaBaseUrl = String.fromEnvironment(
    'BARLYTICS_DEMO_MEDIA_BASE_URL',
    defaultValue: 'demos',
  );

  final String whatsappNumber;
  final String windowsDownloadUrl;
  final String macDownloadUrl;
  final String iosDownloadUrl;
  final String androidDownloadUrl;
  final String linuxDownloadUrl;

  factory PublicSiteConfig.fromJson(Object? json) {
    if (json is! Map) return PublicSiteConfig.empty;
    final data = Map<String, dynamic>.from(json);
    return PublicSiteConfig(
      whatsappNumber: data['whatsapp']?.toString() ?? '',
      windowsDownloadUrl: data['windowsDownloadUrl']?.toString() ?? '',
      macDownloadUrl: data['macDownloadUrl']?.toString() ?? '',
      iosDownloadUrl: data['iosDownloadUrl']?.toString() ?? '',
      androidDownloadUrl: data['androidDownloadUrl']?.toString() ?? '',
      linuxDownloadUrl: data['linuxDownloadUrl']?.toString() ?? '',
    );
  }

  String downloadUrlFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return windowsDownloadUrl;
      case 'macos':
        return macDownloadUrl;
      case 'ios':
        return iosDownloadUrl;
      case 'android':
        return androidDownloadUrl;
      case 'linux':
        return linuxDownloadUrl;
      default:
        return '';
    }
  }
}
