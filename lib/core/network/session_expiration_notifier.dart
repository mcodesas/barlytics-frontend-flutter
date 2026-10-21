import 'package:flutter/foundation.dart';

/// Señal transversal emitida cuando la sesión autenticada deja de ser usable.
///
/// Ocurre cuando un token autenticado deja de ser válido (401). Un 403
/// funcional o una caída de red no eliminan una sesión válida.
/// Mantiene desacoplado el cliente HTTP del estado de autenticación y del router.
class SessionExpirationNotifier extends ChangeNotifier {
  bool _subscriptionRequired = false;
  bool get subscriptionRequired => _subscriptionRequired;

  void sessionExpired() {
    _subscriptionRequired = false;
    notifyListeners();
  }

  /// HTTP 402: la sesión sigue siendo válida pero debe renovarse el plan.
  void subscriptionExpired() {
    _subscriptionRequired = true;
    notifyListeners();
  }
}
