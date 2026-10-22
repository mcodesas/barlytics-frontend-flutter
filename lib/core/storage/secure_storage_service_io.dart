import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

class StorageKeysForMigration {
  static const keys = ['auth_token', 'refresh_token', 'user_id', 'empresa_id', 'sucursal_id', 'email', 'roles', 'subscription_status', 'subscription_active', 'business_setup_complete'];
}

/// Almacenamiento de sesión para plataformas dart:io.
///
/// En macOS local se usa SharedPreferences para evitar errores del Keychain
/// en aplicaciones firmadas localmente. En Android/iOS se mantiene
/// FlutterSecureStorage.
///
/// Las lecturas usan caché read-through en memoria durante la sesión para que
/// cada llamada HTTP no tenga que volver al Keychain/Keystore por el mismo JWT.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, String?> _cache = <String, String?>{};
  final Set<String> _loadedKeys = <String>{};

  Future<String?> read(String key) async {
    if (_loadedKeys.contains(key)) return _cache[key];

    String? value;
    if (Platform.isMacOS) {
      // Migrar credenciales antiguas de preferencias al Keychain.
      value = await _storage.read(key: key);
      if (value == null) {
        final preferences = await SharedPreferences.getInstance();
        value = preferences.getString(key);
        if (value != null) {
          await _storage.write(key: key, value: value);
          await preferences.remove(key);
        }
      }
    } else {
      value = await _storage.read(key: key);
    }

    _loadedKeys.add(key);
    _cache[key] = value;
    return value;
  }

  Future<void> write(String key, String value) async {
    _loadedKeys.add(key);
    _cache[key] = value;

    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
      return;
    }

    await _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    _loadedKeys.add(key);
    _cache[key] = null;

    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
      return;
    }

    await _storage.delete(key: key);
  }

  Future<void> clear() async {
    _cache.clear();
    _loadedKeys.clear();

    if (Platform.isMacOS) {
      final preferences = await SharedPreferences.getInstance();
      // Solo estos dos datos no sensibles sobreviven al cierre de sesión
      // si el usuario eligió explícitamente recordar su cuenta.
      final remember = preferences.getBool(StorageKeys.rememberLoginEnabled) == true;
      final identifier = preferences.getString(StorageKeys.rememberLoginIdentifier);
      await preferences.clear();
      if (remember) {
        await preferences.setBool(StorageKeys.rememberLoginEnabled, true);
        if (identifier != null && identifier.isNotEmpty) {
          await preferences.setString(StorageKeys.rememberLoginIdentifier, identifier);
        }
      }
      return;
    }

    await _storage.deleteAll();
  }
}
