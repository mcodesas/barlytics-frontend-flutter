/// Llaves usadas para almacenamiento seguro y local.
class StorageKeys {
  // Solo identificador y consentimiento. Nunca almacenar una contraseña aquí.
  static const rememberLoginEnabled = 'login_remember_password_enabled';
  static const rememberLoginIdentifier = 'login_remember_identifier';
  static const authToken = 'auth_token';
  static const refreshToken = 'refresh_token';
  static const userId = 'user_id';
  static const empresaId = 'empresa_id';
  static const sucursalId = 'sucursal_id';
  static const email = 'email';
  static const roles = 'roles';
  static const subscriptionStatus = 'subscription_status';
  static const subscriptionActive = 'subscription_active';
  static const businessSetupComplete = 'business_setup_complete';
}
