import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento de sesión para plataformas dart:io.
///
/// En macOS local se usa SharedPreferences para evitar errores del Keychain
/// en aplicaciones firmadas localmente.
/// En Android/iOS se mantiene FlutterSecureStorage.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(key);
    }

    return _storage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
      return;
    }

    await _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
      return;
    }

    await _storage.delete(key: key);
  }

  Future<void> clear() async {
    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      return;
    }

    await _storage.deleteAll();
  }
}
