# Pagos mensuales desde App Store / Google Play (Flutter BarLytics)

Rama: `feat/suscripciones-tiendas-ios-android-20261111`.

## Comportamiento implementado

- iOS (iPhone/iPad): el flujo de activación presenta la compra mensual **dentro de App Store**, con el precio autorizado por la tienda.
- Android: presenta **Google Play Billing**, con el precio autorizado por Google.
- Web, Windows, Linux y macOS fuera de tiendas: se mantiene el checkout de Mercado Pago existente.
- El administrador elige un plan. El widget consulta `GET /api/v1/subscriptions/store/products` para resolver el SKU real, y después `InAppPurchase.queryProductDetails` para cargar el precio.
- Antes de abrir la hoja de pago, `POST /prepare` asocia un UUID permanente y opaco a la empresa.
- Al recibir `PurchaseStatus.purchased` o `restored`, se envía al backend la **referencia de transacción de Apple** o el **purchaseToken de Google**. El backend valida online contra las APIs oficiales y **no confía en fechas ni importes del móvil**.
- Solo después de confirmación del backend se ejecuta `completePurchase` y se refresca la suscripción de la empresa.
- Se permite **Restaurar compras**; no reasigna compras a empresas distintas.
- Al estar activa la suscripción, la app muestra enlace para administrarla desde la tienda correspondiente.

## Para probar

```bash
git switch feat/suscripciones-tiendas-ios-android-20261111
flutter pub get
flutter analyze
flutter test test/features/subscription/store_subscription_contract_test.dart
flutter run -d chrome
```

Para **pruebas de pagos reales** hay que configurar en consolas los productos mensuales correspondientes al mismo Bundle ID / applicationId `com.mcode.barlytics`, subir una build de TestFlight y otra de Google Play Internal Testing, habilitar las variables del backend de QA y usar cuentas de prueba oficiales. Las compras nativas no se prueban en Chrome.

Consulta la guía completa `docs/SUSCRIPCIONES_APP_STORE_GOOGLE_PLAY.md` en el repositorio backend para configuración de Apple/Google, SQL V74, secretos y webhooks.

## Advertencias

- La integración **no crea automáticamente SKU ni credenciales** en App Store Connect / Play Console.
- Si el backend responde que el proveedor está deshabilitado (valor por defecto), la interfaz presenta el problema y no inicia compras.
- La restauración y la validación de compras incompletas dependen de la conectividad y de la asociación previa con la empresa. No finalizar transacciones no verificadas.
- El upgrade / downgrade de un plan activo en la tienda requiere una implementación separada del flujo de cambio de base-plan / grupo de suscripciones. No permitir un cobro nuevo a la vez que una suscripción de otro proveedor está vigente.
- No mezclar claves de tienda ni secretos en Flutter: solo en el backend.


## Administración visual y sincronización automática del catálogo

La ruta existente **/planes_suscripcion** (acceso ADMIN Y SOPORTE) incorpora una tercera pestaña: **App Store y Google Play**. Esta pantalla no realiza pagos: crea productos en las tiendas mediante endpoints exclusivos del backend.

El nuevo panel incluye, por cada plan mensual activo:
- Dos tarjetas independientes (Apple y Google), con estado, SKU copiable, precio COP verificado y avisos de sincronización.
- Estado de habilitación del módulo y de credenciales por proveedor, sin exponer secretos.
- Diálogo de confirmación para crear productos, aplicar el precio válido de Apple y, en Google, aceptar el cálculo regional o activar el plan base mensual.
- Botón de volver a consultar el estado remoto, indicador de errores y un historial de operaciones.
- Diseño responsivo para móviles y escritorio, con scroll interior en la pestaña.
- Controles desactivados cuando `BARLYTICS_IAP_CATALOG_SYNC_ENABLED=false` o faltan credenciales.

### Protección de suscriptores existentes

Al actualizar el precio base de BarLytics, el servidor contrasta el precio publicado. Si difiere, aparece `PRICE_CHANGE_REVIEW`. Los cambios de precio a **planes existentes con suscriptores** no se publican silenciosamente: podrían requerir consentimiento del cliente o migración de cohortes en las tiendas. Por ahora, deben confirmarse y administrarse de forma controlada en la consola correspondiente.

### Configuración inicial en tu servidor

Consulta `docs/SUSCRIPCIONES_APP_STORE_GOOGLE_PLAY.md` del backend para:
- Clave **App Store Connect API** separada de la clave **App Store Server API**.
- Cuenta de servicio Play Developer API.
- Variables `BARLYTICS_ASC_ISSUER_ID`, `BARLYTICS_ASC_KEY_ID`, `BARLYTICS_ASC_PRIVATE_KEY_P8_BASE64`, `GOOGLE_APPLICATION_CREDENTIALS`.
- `BARLYTICS_IAP_CATALOG_SYNC_ENABLED=true` para sincronizar productos sin abrir cobros.
- `BARLYTICS_IAP_ENABLED=false` hasta aprobación final de Apple/Google y QA de pagos en Sandbox/TestFlight/Internal Testing.

**Esta integración no requiere añadir otro menú a la BD:** se incorpora al módulo de Planes y suscripciones ya autorizado, manteniendo el control por rol global en el backend.
