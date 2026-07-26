# BarLytics / BarApp Frontend Flutter

Cliente Flutter multiplataforma de BarLytics. Esta documentación fue revisada contra `lib/` y el backend el **2026-07-24**.

## Stack

- Flutter con Dart `>=3.4.0 <4.0.0`.
- Riverpod para sesión, contexto de sucursal y estado operativo.
- Dio con interceptores para JWT, errores y tiempos de espera.
- GoRouter para rutas públicas, protegidas y redirección por rol.
- Flutter Secure Storage y Shared Preferences.
- PDF, File Picker y URL Launcher.
- 544 archivos Dart distribuidos en 32 features.

## Arquitectura real

Las features CRUD mantienen el flujo:

```text
Page → Provider → UseCase → Repository → RemoteDataSource → ApiClient/Dio
```

Las pantallas operativas complejas, como Productos y Reportes, consumen el `ApiClient` compartido desde widgets Riverpod para coordinar paneles, PDF y consultas agregadas. Al extenderlas se debe evitar crear clientes Dio adicionales y extraer la lógica reutilizable a providers o servicios.

Carpetas principales:

```text
lib/
├── app/{bootstrap,router,theme}
├── core/{branch,config,constants,crud,network,storage,utils,widgets}
└── features/auth, ciudades, cuentas_venta, dashboard, detalle_cuenta_venta, empresas, home, inventario, marcas, medios_pago, menus, mesas, mesero, monedas, movimientos, navigation, opciones_menu, pagos, paises, parametros, precios, productos, profile, regiones, reportes, roles, sucursales, tablas_parametricas, tipos_producto, usuarios, ventas, zonas_horarias
```

## URL del backend

El puerto local vigente es **8282**, no 8080.

- Windows, iOS simulator y escritorio: `http://127.0.0.1:8282`.
- Android emulator: `http://10.0.2.2:8282`.
- Flutter Web local: usa automáticamente el host del navegador y el puerto 8282.
- Puede forzarse con `--dart-define=API_BASE_URL=...`.
- También pueden usarse `API_HOST` y `API_PORT`.

Ejemplo web accesible por LAN:

```bash
flutter run -d web-server   --web-hostname 0.0.0.0   --web-port 3000   --dart-define=ENV=local   --dart-define=API_PORT=8282
```

## Sesión, roles y sucursal

- Login mediante `POST /api/v1/auth/login`.
- Recuperación con `forgot-password`, validación del código y `reset-password`.
- JWT guardado de forma segura y enviado como Bearer.
- Menú autorizado consultado en `/api/v1/auth/me/menus`.
- Sucursales permitidas consultadas en `/api/v1/sucursales/mis-sucursales`.
- La sucursal activa se conserva en almacenamiento seguro.
- Los roles de inventario no ingresan al flujo de mesas y son dirigidos a `/productos`.
- Mesero y cajero usan el espacio operativo `/mesero`.

## Experiencias principales

### Mesero y caja

- Mesas, productos, resumen, historial de ventas y cierre de caja sin recargar toda la navegación.
- Apertura de venta, múltiples cuentas, cantidades, traslado de productos y eliminación controlada.
- Pagos mixtos, propina, cambio y QR configurado por sucursal.
- Cierre con base, gastos, conteo por medio de pago, diferencia, actualización y PDF.

### Inventario

- Productos con paginación, buscador, filtros compactos y contexto de sucursal.
- Acciones compactas `Agregar`, `Quitar`, `Historial` y `Modificar`.
- El panel de ingreso/retiro solicita tipo de movimiento, cantidad, unidad, motivo y referencia.
- Historial de movimientos por producto y sucursal.
- Edición en hoja inferior con imagen, vencimiento, presentación de compra y límites de stock.
- Conteo físico diario tipo checklist y cruce contra inventario esperado.
- Precios por sucursal y validación de costos/venta.

### Reportes, ganancias y pedido

- Resumen ejecutivo, ventas, recaudo, stock, ranking, movimientos, rotación, alertas y responsables.
- Ganancias por **día**, **mes** o **cruce de inventario**.
- Próximo pedido según stock mínimo, máximo opcional y presentación de compra.
- Selección tipo POS, observación, confirmación persistente, PDF y WhatsApp.

### Administración

- Usuarios, roles, empresas, sucursales, parámetros y catálogos geográficos.
- Tablas paramétricas agrupadas: tipos de producto, marcas y medios de pago.
- Medios de pago y QR administrados por sucursal.

## Diseño y responsive

- La funcionalidad se conserva en móvil, tablet, web y escritorio; cambia únicamente el layout.
- Los filtros deben usar `AppControlMetrics`.
- Altura estándar de filtros, buscadores, fechas y dropdowns: **40 px**.
- Los flujos de edición operativa usan hojas inferiores en móvil en lugar de diálogos encadenados.
- Evitar texto menor a 12 px para información operativa relevante.

## Rutas destacadas

- `/login`, `/forgot-password`, `/reset-password`
- `/home`, `/profile`
- `/mesero`, `/mesero/productos`, `/mesero/resumen`, `/mesero/historial`, `/mesero/cierre-caja`
- `/productos`, `/inventario`, `/movimientos`, `/precios`
- `/ganancias`, `/proximo_pedido`, `/reportes`
- `/tablas_parametricas`, `/medios_pago`
- Módulos administrativos CRUD.

## Ejecución

```bash
flutter pub get
flutter run -d chrome --dart-define=ENV=local
flutter test
flutter analyze
```

Para escritorio/LAN, el backend puede iniciarse mediante las utilidades de `lib/core/desktop/` cuando el paquete distribuido incluye el ejecutable o JAR esperado.

## Hallazgos de consistencia

- La navegación activa de reportes usa `ReportesPage` y los endpoints especializados bajo `/api/v1/reportes/...`. Los artefactos CRUD generados `reportesConfig`, `ReportesListPage`, `ReportesDetailPage` y `ReportesFormPage` apuntan al base path inexistente `/api/v1/reportes`; se consideran código legado y no deben reutilizarse.
- `_lookupTiposAutenticacion` declara `/api/v1/tiposautenticacion`, pero el backend entregado no expone un controller CRUD para ese catálogo. Actualmente el lookup no tiene usos activos.
- Al depurar código generado, retirar estos artefactos o implementar explícitamente el contrato backend antes de habilitarlos en rutas o formularios.

## Contrato

Los endpoints y modelos deben verificarse contra:

- `barlytics-api-contracts/barlytics-commerce-service/api-docs.json`
- La colección Postman sincronizada.

No deben inventarse campos ni rutas desde la UI. Cuando el backend cambia, primero se actualiza el contrato y después los modelos/servicios Flutter.
