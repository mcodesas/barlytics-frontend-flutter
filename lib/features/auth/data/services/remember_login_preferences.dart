import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

/// Preferencia de uso del gestor de contraseñas, NO almacenamiento de claves.
/// Flutter Web y macOS pueden guardar sesiones en preferencias locales, por eso
/// nunca se escribe aquí la contraseña del usuario.
class RememberedLogin {
  const RememberedLogin({required this.enabled, required this.identifier});

  final bool enabled;
  final String identifier;
}

class RememberLoginPreferences {
  const RememberLoginPreferences();

  // No usar el prefijo "auth" / "barlytics." reservado para el cierre
  // de sesión: recordar la cuenta no implica mantener un JWT activo.
  static const enabledKey = StorageKeys.rememberLoginEnabled;
  static const identifierKey = StorageKeys.rememberLoginIdentifier;

  Future<RememberedLogin> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(enabledKey) ?? false;
    return RememberedLogin(
      enabled: enabled,
      identifier: enabled ? (prefs.getString(identifierKey) ?? '') : '',
    );
  }

  /// Se llama SOLO después de que el backend haya validado el acceso.
  Future<void> save({
    required bool enabled,
    required String identifier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setString(identifierKey, identifier.trim());
      await prefs.setBool(enabledKey, true);
    } else {
      await prefs.remove(identifierKey);
      await prefs.remove(enabledKey);
    }
  }

  /// Desmarcar revoca inmediatamente la preferencia para próximos ingresos.
  Future<void> forget() async => save(enabled: false, identifier: '');
}
