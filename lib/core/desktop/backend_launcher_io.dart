import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Levanta el backend Spring Boot incluido con la instalación de escritorio.
///
/// Estructura esperada junto al ejecutable Flutter:
///   backend/barlytics-commerce-service.jar
///   backend/application-desktop.yml              opcional
///   runtime-java/bin/java.exe                    opcional; si no existe usa java del sistema
///
/// Variables de entorno soportadas:
///   BARLYTICS_DISABLE_EMBEDDED_BACKEND=true      desactiva el arranque automático
///   BARLYTICS_JAVA_EXE=C:\\ruta\\java.exe         ruta manual a Java
///   BARLYTICS_BACKEND_DIR=C:\\ruta\\backend       carpeta del backend
///   BARLYTICS_BACKEND_JAR=C:\\ruta\\app.jar       jar del backend
///   BARLYTICS_SERVER_ADDRESS=0.0.0.0             permite acceso desde otros dispositivos LAN
///   BARLYTICS_SERVER_PORT=8282                   puerto del backend
class DesktopBackendLauncher {
  static const String _healthHost = '127.0.0.1';
  static const String _defaultBindAddress = '0.0.0.0';
  static const int _defaultPort = 8282;
  static const String _healthPath = '/actuator/health';

  static Process? _process;
  static bool _initialized = false;

  static Future<void> startIfNeeded() async {
    if (_initialized) return;
    _initialized = true;

    if (!_isDesktop) return;

    final environment = Platform.environment;
    final disabled = _isTruthy(environment['BARLYTICS_DISABLE_EMBEDDED_BACKEND']);
    if (disabled) return;

    final port = int.tryParse(environment['BARLYTICS_SERVER_PORT'] ?? '') ?? _defaultPort;
    final bindAddress = environment['BARLYTICS_SERVER_ADDRESS']?.trim().isNotEmpty == true
        ? environment['BARLYTICS_SERVER_ADDRESS']!.trim()
        : _defaultBindAddress;

    if (await _isBackendAlive(port)) return;

    final appDir = File(Platform.resolvedExecutable).parent;
    final backendDir = Directory(
      environment['BARLYTICS_BACKEND_DIR'] ?? _join(appDir.path, 'backend'),
    );

    final jarFile = File(
      environment['BARLYTICS_BACKEND_JAR'] ??
          _join(backendDir.path, 'barlytics-commerce-service.jar'),
    );

    if (!jarFile.existsSync()) {
      await _appendLog(
        appDir.path,
        'No se encontró el backend en: ${jarFile.path}. Se omite arranque automático.',
      );
      return;
    }

    final javaExecutable = _resolveJavaExecutable(appDir.path, environment);
    final configFile = File(_join(backendDir.path, 'application-desktop.yml'));

    final args = <String>[
      '-Dfile.encoding=UTF-8',
      '-Dspring.profiles.active=desktop',
      '-jar',
      jarFile.path,
      '--server.address=$bindAddress',
      '--server.port=$port',
    ];

    if (configFile.existsSync()) {
      args.add('--spring.config.additional-location=${configFile.absolute.uri}');
    }

    try {
      _process = await Process.start(
        javaExecutable,
        args,
        workingDirectory: backendDir.existsSync() ? backendDir.path : appDir.path,
        runInShell: javaExecutable == 'java',
      );

      _pipeProcessLogs(appDir.path, _process!);

      // Espera corta para que, si arranca rápido, la UI ya encuentre el servicio.
      // Si tarda más por la conexión a BD, la app continúa y los logs quedan registrados.
      await _waitUntilAlive(
        port: port,
        maxAttempts: 12,
        delay: const Duration(milliseconds: 500),
      );
    } catch (error, stackTrace) {
      await _appendLog(
        appDir.path,
        'Error levantando backend: $error\n$stackTrace',
      );
    }
  }

  static Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    process.kill();
    _process = null;
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool _isTruthy(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static String _resolveJavaExecutable(
    String appDir,
    Map<String, String> environment,
  ) {
    final configuredJava = environment['BARLYTICS_JAVA_EXE'];
    if (configuredJava != null && configuredJava.trim().isNotEmpty) {
      return configuredJava;
    }

    final bundledJava = File(
      _join(
        _join(_join(appDir, 'runtime-java'), 'bin'),
        Platform.isWindows ? 'java.exe' : 'java',
      ),
    );

    if (bundledJava.existsSync()) return bundledJava.path;

    return 'java';
  }

  static Future<bool> _isBackendAlive(int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client
          .get(_healthHost, port, _healthPath)
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _waitUntilAlive({
    required int port,
    required int maxAttempts,
    required Duration delay,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (await _isBackendAlive(port)) return;
      await Future<void>.delayed(delay);
    }
  }

  static void _pipeProcessLogs(String appDir, Process process) {
    process.stdout
        .transform(utf8.decoder)
        .listen((data) => unawaited(_appendLog(appDir, data)));
    process.stderr
        .transform(utf8.decoder)
        .listen((data) => unawaited(_appendLog(appDir, '[ERROR] $data')));
  }

  static Future<void> _appendLog(String appDir, String message) async {
    try {
      final logsDir = Directory(_join(appDir, 'logs'));
      if (!logsDir.existsSync()) logsDir.createSync(recursive: true);

      final logFile = File(_join(logsDir.path, 'backend-launcher.log'));
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // No se relanza para no bloquear el inicio del frontend por problemas de log.
    }
  }

  static String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) return '$left$right';
    return '$left${Platform.pathSeparator}$right';
  }
}
