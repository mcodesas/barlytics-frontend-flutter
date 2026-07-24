import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro para escritorio/móvil.
///
/// En plataformas con dart:io se usa flutter_secure_storage.
/// En Web NO se usa esta implementación porque flutter_secure_storage Web
/// depende de WebCrypto y falla cuando la app se abre por HTTP desde una IP LAN
/// como http://192.168.x.x:3000.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();
}
