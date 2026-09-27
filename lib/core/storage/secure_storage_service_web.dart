import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento de sesión para Flutter Web en red local.
///
/// No usa flutter_secure_storage en Web porque ese plugin intenta usar
/// window.crypto.subtle.generateKey. En navegadores, crypto.subtle solo está
/// disponible en contextos seguros: HTTPS o localhost. Cuando la app se abre
/// desde otro dispositivo por HTTP, por ejemplo http://192.168.1.50:3000,
/// crypto.subtle queda undefined.
///
/// SharedPreferences persiste en localStorage y una caché read-through evita
/// acceder a localStorage en cada petición HTTP para recuperar el mismo JWT.
class SecureStorageService {
  SecureStorageService();

  final Map<String, String?> _cache = <String, String?>{};
  final Set<String> _loadedKeys = <String>{};

  Future<String?> read(String key) async {
    if (_loadedKeys.contains(key)) return _cache[key];

    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    _loadedKeys.add(key);
    _cache[key] = value;
    return value;
  }

  Future<void> write(String key, String value) async {
    _loadedKeys.add(key);
    _cache[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> delete(String key) async {
    _loadedKeys.add(key);
    _cache[key] = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clear() async {
    _cache.clear();
    _loadedKeys.clear();

    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith('barlytics.') || key.startsWith('auth'))
        .toList(growable: false);

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
