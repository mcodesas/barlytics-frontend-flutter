
# BarLytics / BarApp Frontend Flutter

Frontend empresarial multiplataforma para BarLytics / BarApp. Fue generado usando como fuente oficial la colección Postman del backend y el CSV de tareas frontend adjuntos en la conversación.

## Tecnologías

- Flutter y Dart.
- Dio para consumo HTTP.
- Riverpod para manejo de estado.
- GoRouter para navegación.
- Flutter Secure Storage para JWT.
- Arquitectura limpia modular por feature.
- Responsive design para móvil, tablet, iPad, web y escritorio.

## Arquitectura

Flujo obligatorio aplicado:

```text
Page / Widget
  -> Provider / StateNotifier
    -> UseCase
      -> Repository Interface
        -> Repository Implementation
          -> RemoteDataSource
            -> ApiClient / Dio
              -> Backend API
```

La UI no llama directamente a Dio. La URL base está centralizada en `lib/core/config/environment.dart`.

## Regla multiplataforma

Todas las funcionalidades están disponibles en todos los dispositivos soportados. El dispositivo solo adapta el layout y la experiencia visual. Los permisos dependen de rol, perfil y sesión, no del dispositivo.

Breakpoints:

- Mobile: `< 600`.
- Tablet/iPad: `600 - 1024`.
- Desktop/Web: `>= 1024`.

## Configuración local

Backend local web/iOS:

```bash
flutter run -d chrome --dart-define=ENV=local
```

Android emulator:

```bash
flutter run --dart-define=ENV=android
```

URL manual:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## Backend esperado

El backend debe estar corriendo en:

```text
http://localhost:8080
```

Swagger del backend:

```text
http://localhost:8080/swagger-ui/index.html
```

## Autenticación

La pantalla de login consume:

```text
POST /api/v1/auth/login
```

El token JWT se almacena con `FlutterSecureStorage` y se envía automáticamente como:

```text
Authorization: Bearer <token>
```

Ante HTTP 401, el interceptor limpia la sesión.

## Módulos implementados

| Módulo | Endpoint base | Feature |
|---|---:|---|
| Ciudades | `/api/v1/ciudades` | `ciudades` |
| Cuentas venta | `/api/v1/cuentasventa` | `cuentas_venta` |
| Detalle cuenta venta | `/api/v1/detallecuentaventa` | `detalle_cuenta_venta` |
| Empresas | `/api/v1/empresas` | `empresas` |
| Inventario | `/api/v1/inventario` | `inventario` |
| Marcas | `/api/v1/marcas` | `marcas` |
| Medios pago | `/api/v1/mediospago` | `medios_pago` |
| Menus | `/api/v1/menus` | `menus` |
| Mesas | `/api/v1/mesas` | `mesas` |
| Monedas | `/api/v1/monedas` | `monedas` |
| Movimientos | `/api/v1/movimientos` | `movimientos` |
| Opciones menu | `/api/v1/opcionesmenu` | `opciones_menu` |
| Pagos | `/api/v1/pagos` | `pagos` |
| Paises | `/api/v1/paises` | `paises` |
| Parametros | `/api/v1/parametros` | `parametros` |
| Precios | `/api/v1/precios` | `precios` |
| Productos | `/api/v1/productos` | `productos` |
| Regiones | `/api/v1/regiones` | `regiones` |
| Reportes | `/api/v1/reportes` | `reportes` |
| Roles | `/api/v1/roles` | `roles` |
| Sucursales | `/api/v1/sucursales` | `sucursales` |
| Tipos producto | `/api/v1/tiposproducto` | `tipos_producto` |
| Usuarios | `/api/v1/usuarios` | `usuarios` |
| Ventas | `/api/v1/ventas` | `ventas` |
| Zonas horarias | `/api/v1/zonashorarias` | `zonas_horarias` |

Además se incluyó módulo de reportes con endpoints:

- `/api/v1/reportes/ventas`
- `/api/v1/reportes/ventas/medio-pago`
- `/api/v1/reportes/stock-actual`
- `/api/v1/reportes/productos-mas-vendidos`
- `/api/v1/reportes/movimientos-inventario`

## Estructura principal

```text
lib/
  app/
    router/
    theme/
    bootstrap/
  core/
    config/
    constants/
    crud/
    errors/
    network/
    storage/
    utils/
    widgets/
  features/
    auth/
    home/
    dashboard/
    <modulo>/
      data/
      domain/
      presentation/
```

## Ejecutar

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## Pruebas

```bash
flutter test
```

## Tareas del CSV cubiertas

- 1. Crear proyecto base Flutter multiplataforma (core - Alta)
- 2. Definir arquitectura frontend Flutter modular (core - Alta)
- 3. Definir estrategia responsive y breakpoints (core - Alta)
- 4. Crear componentes base de layout adaptativo (core - Alta)
- 5. Definir experiencia visual por dispositivo (core - Media)
- 6. Configurar cliente HTTP Dio para consumo de APIs (api - Alta)
- 7. Crear modelo estándar de respuesta API (api - Alta)
- 8. Crear manejo global de errores frontend (api - Alta)
- 9. Crear almacenamiento seguro de sesión (auth - Alta)
- 10. Configurar ambientes frontend (core - Media)
- 11. Crear pantalla de login (auth - Alta)
- 12. Crear flujo de sesión autenticada (auth - Alta)
- 13. Crear consulta de usuario autenticado (auth - Alta)
- 14. Crear consulta y renderizado de menú dinámico (auth - Alta)
- 15. Crear control visual por permisos (auth - Media)
- 16. Crear funcionalidad de logout (auth - Media)
- 17. Crear flujo de recuperación de contraseña (auth - Media)
- 18. Crear flujo de cambio de contraseña (auth - Media)
- 19. Crear pantalla de selección de empresa y sucursal (sucursales - Alta)
- 20. Crear componente visual de contexto actual (sucursales - Media)
- 21. Crear layout principal adaptativo (core - Alta)
- 22. Configurar rutas protegidas con GoRouter (core - Alta)
- 23. Crear dashboard inicial por permisos (dashboard - Media)
- 24. Crear módulo visual de empresas (empresas - Media)
- 25. Crear módulo visual de sucursales (sucursales - Media)
- 26. Crear módulo visual de usuarios (usuarios - Media)
- 27. Crear módulo visual de roles y permisos (roles - Media)
- 28. Crear módulo visual de parámetros (parámetros - Media)
- 29. Crear módulo de catálogos geográficos (catalogos - Media)
- 30. Crear módulo visual de medios de pago (pagos - Media)
- 31. Crear módulo visual de marcas (productos - Media)
- 32. Crear módulo visual de tipos de producto (productos - Media)
- 33. Crear módulo visual de productos (productos - Alta)
- 34. Crear módulo visual de precios (precios - Alta)
- 35. Crear pantalla de inventario actual por sucursal (inventario - Alta)
- 36. Crear flujo de inventario inicial (inventario - Media)
- 37. Crear flujo de entrada de inventario (inventario - Alta)
- 38. Crear flujo de salida de inventario (inventario - Alta)
- 39. Crear pantalla de movimientos de inventario (inventario - Media)
- 40. Crear pantalla de stock bajo (inventario - Media)
- 41. Crear pantalla de mesas por sucursal (mesas - Alta)
- 42. Crear flujo para crear y editar mesas (mesas - Alta)
- 43. Crear flujo para abrir venta en mesa (ventas - Alta)
- 44. Crear pantalla de venta activa (ventas - Alta)
- 45. Crear flujo para crear cuenta en venta (cuentas-venta - Alta)
- 46. Crear selector de productos para venta (ventas - Alta)
- 47. Crear flujo para agregar producto a cuenta (cuentas-venta - Alta)
- 48. Crear flujo para modificar cantidad de producto (cuentas-venta - Alta)
- 49. Crear flujo para eliminar producto de cuenta (cuentas-venta - Alta)
- 50. Crear pantalla de detalle de cuenta (cuentas-venta - Alta)
- 51. Crear flujo para cancelar venta (ventas - Alta)
- 52. Crear flujo para cerrar venta (ventas - Alta)
- 53. Crear pantalla de pagos de cuenta (pagos - Alta)
- 54. Crear flujo de pagos mixtos (pagos - Alta)
- 55. Crear flujo para anular pago (pagos - Media)
- 56. Crear pantalla de consulta de pagos (pagos - Media)
- 57. Crear reporte visual de ventas por fecha (reportes - Media)
- 58. Crear reporte visual de pagos por medio (reportes - Media)
- 59. Crear reporte visual de productos más vendidos (reportes - Media)
- 60. Crear reporte visual de stock actual (reportes - Media)
- 61. Validar compatibilidad visual en Android (qa - Alta)
- 62. Validar compatibilidad visual en Web (qa - Alta)
- 63. Validar compatibilidad visual en iPhone (qa - Media)
- 64. Validar compatibilidad visual en iPad (qa - Media)
- 65. Crear guía de diseño responsive (core - Media)
- 66. Crear pruebas unitarias de servicios API (pruebas - Media)
- 67. Crear pruebas de providers/controladores (pruebas - Media)
- 68. Crear pruebas de widgets principales (pruebas - Media)
- 69. Crear pruebas responsive (pruebas - Media)
- 70. Validar flujo completo de autenticación (flujos - Alta)
- 71. Validar flujo completo de administración (flujos - Alta)
- 72. Validar flujo completo de producto listo para venta (flujos - Alta)
- 73. Validar flujo completo de venta en mesa (flujos - Alta)
- 74. Validar flujo completo de pago mixto (flujos - Alta)
- 75. Validar flujo completo de cancelación de venta (flujos - Alta)

## Decisiones técnicas

- Se generaron modelos Dart tipados desde los campos encontrados en requests/responses de Postman.
- Se implementó un CRUD genérico para no duplicar lógica entre módulos.
- Cada módulo conserva su carpeta `data/domain/presentation` y wrappers propios.
- La colección Postman se conserva en `docs/postman/` como contrato de integración.
- El CSV de tareas se conserva en `docs/issues/` para trazabilidad funcional.

## Nota de ejecución

Este paquete contiene el código Flutter. Si tu entorno local exige carpetas nativas completas de Android/iOS/Windows/macOS/Linux, ejecuta desde la raíz:

```bash
flutter create . --platforms=android,ios,web,windows,macos,linux
```

Ese comando no modifica la lógica de `lib/`; solo regenera wrappers nativos según el SDK Flutter instalado.

## Actualización: experiencia visual para usuario MESERO

Se agregó una experiencia específica para usuarios con rol `MESERO`:

- Redirección automática a `/mesero` después del login.
- Navegación principal mediante barra inferior: Mesas, Productos y Resumen.
- Menú lateral/drawer limitado a Mi perfil y Cerrar sesión.
- Pantalla funcional para seleccionar mesa, abrir venta, crear cuentas, asignar productos y ver total pendiente por mesa.

Documentación detallada: `docs/flujo_mesero_ui.md`.
