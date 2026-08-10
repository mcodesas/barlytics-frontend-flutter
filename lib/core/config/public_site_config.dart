class PublicSiteConfig {
  const PublicSiteConfig._();

  /// Número en formato internacional, solo dígitos. Ejemplo Colombia: 573001234567.
  static const whatsappNumber = String.fromEnvironment(
    'BARLYTICS_WHATSAPP',
    defaultValue: '',
  );



  /// Carpeta web o URL base donde se publican las grabaciones reales de la demo.
  /// Por defecto busca archivos en web/demos/{desktop|tablet|phone}/<modulo>.gif.
  static const demoMediaBaseUrl = String.fromEnvironment(
    'BARLYTICS_DEMO_MEDIA_BASE_URL',
    defaultValue: 'demos',
  );

  static const windowsDownloadUrl = String.fromEnvironment(
    'BARLYTICS_DOWNLOAD_WINDOWS_URL',
    defaultValue: '',
  );
  static const macDownloadUrl = String.fromEnvironment(
    'BARLYTICS_DOWNLOAD_MAC_URL',
    defaultValue: '',
  );
  static const androidDownloadUrl = String.fromEnvironment(
    'BARLYTICS_DOWNLOAD_ANDROID_URL',
    defaultValue: '',
  );
  static const linuxDownloadUrl = String.fromEnvironment(
    'BARLYTICS_DOWNLOAD_LINUX_URL',
    defaultValue: '',
  );

  static String downloadUrlFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return windowsDownloadUrl;
      case 'macos':
        return macDownloadUrl;
      case 'android':
        return androidDownloadUrl;
      case 'linux':
        return linuxDownloadUrl;
      default:
        return '';
    }
  }
}
