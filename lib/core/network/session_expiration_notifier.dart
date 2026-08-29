import 'package:flutter/foundation.dart';

/// Señal transversal emitida cuando la sesión autenticada deja de ser usable.
///
/// Puede ocurrir por token vencido/inválido (401), acceso rechazado (403) o
/// porque el backend dejó de responder a una petición que ya llevaba JWT.
/// Mantiene desacoplado el cliente HTTP del estado de autenticación y del router.
class SessionExpirationNotifier extends ChangeNotifier {
  void sessionExpired() => notifyListeners();
}
