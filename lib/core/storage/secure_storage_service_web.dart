import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento de sesión para Flutter Web en red local.
///
/// No usa flutter_secure_storage en Web porque ese plugin intenta usar
/// window.crypto.subtle.generateKey. En navegadores, crypto.subtle solo está
/// disponible en contextos seguros: HTTPS o localhost. Cuando la app se abre
/// desde otro dispositivo por HTTP, por ejemplo http://192.168.1.50:3000,
/// crypto.subtle queda undefined y aparece el error:
/// "Cannot read properties of undefined (reading 'generateKey')".
///
/// Para pruebas LAN se usa SharedPreferences, que en Web persiste en localStorage.
class SecureStorageService {
  const SecureStorageService();

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clear() async {
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
