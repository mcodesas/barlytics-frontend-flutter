import 'package:flutter/foundation.dart';

/// Señal transversal emitida cuando la sesión autenticada deja de ser usable.
///
/// Ocurre cuando un token autenticado deja de ser válido (401). Un 403
/// funcional o una caída de red no eliminan una sesión válida.
/// Mantiene desacoplado el cliente HTTP del estado de autenticación y del router.
class SessionExpirationNotifier extends ChangeNotifier {
  void sessionExpired() => notifyListeners();
}
