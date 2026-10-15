# BarLytics — Plan maestro de validación funcional

**Rama:** `fix/historial-navegacion-eliminar-pedidos` (frontend y backend). **Estado inicial:** pendiente de ejecución. Inventario derivado de la estructura de `lib/features/**/presentation/pages` y `modules/**/api`. Los casos no equivalen a pruebas ejecutadas.

## Matriz de ejecución por plataforma

Cada caso `QA-nnn` se prueba en **cuatro entornos independientes**, en **tres rondas** por entorno:

| Entorno | Ronda 1: funcional | Ronda 2: interfaz / UX | Ronda 3: integración / seguridad |
| --- | --- | --- | --- |
| Web navegador escritorio (Chrome/Edge) | Pendiente | Pendiente | Pendiente |
| Celular (Android y iPhone cuando aplique) | Pendiente | Pendiente | Pendiente |
| Tablet (iPad/Android tablet) | Pendiente | Pendiente | Pendiente |
| Escritorio nativo (Windows/macOS/Linux) | Pendiente | Pendiente | Pendiente |

**Ronda 1:** ruta, acción, resultado, reglas de negocio, persistencia de datos.  
**Ronda 2:** selección de botones, responsive, scroll, teclado, modales y accesibilidad.  
**Ronda 3:** backend, DB, roles, multi-tenant, condiciones de error, pagos e impresión.

En cada caso anotar: fecha, ID, ronda, plataforma/dispositivo, versión, rol, sucursal de prueba, pasos, esperado, obtenido, evidencia, incidencia y commit de corrección. Estado: `PENDIENTE`, `EN PRUEBA`, `APROBADO`, `FALLÓ`, `BLOQUEADO` o `NO APLICA`.

## Registro de ejecuciones

| Fecha | Caso | Entorno | Ronda | Estado | Observaciones |
| --- | --- | --- | --- | --- | --- |
| 2026-10-15 | QA-001 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario) |
| 2026-10-15 | QA-002 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario) |
| 2026-10-15 | QA-003 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario) |
| 2026-10-15 | QA-004 | Web | 1 — Funcional | **APROBADO EN REPRUEBA (persistencia)** | Usuario confirma que conserva la sesión al cerrar y reabrir navegador. Incidencia previa corregida con backend 7e544e7f y frontend 2f2ff95d. Expiración y revocación pendientes de verificación específica. |
| 2026-10-15 | QA-005 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario) |

**Avance verificable:** QA-001, QA-002, QA-003 y QA-005 aprobadas en Web / Ronda 1; QA-004 aprobada en reprueba de persistencia (restan escenarios de expiración y revocación). Los demás entornos y rondas permanecen pendientes; cada caso maestro se completa cuando se cubren las combinaciones aplicables.

## Catálogo de casos

### Acceso y seguridad
- [ ] **QA-001** Ingreso por usuario y contraseña, error de credenciales y bloqueo
- [ ] **QA-002** Recuperación de contraseña y correo
- [ ] **QA-003** Google Sign-In y Apple Sign-In donde aplique
- [ ] **QA-004** Expiración, persistencia y cierre de sesión
  - **Criterio Web:** al cerrar y volver a abrir el navegador debe restaurar la sesión, conservando rol y sucursal, sin nuevo login siempre que sea válida; al vencer el JWT deberá renovarse de forma segura. Logout explícito, revocación y cambio de contraseña deben impedir la restauración. **PENDIENTE DE VERIFICACIÓN / AJUSTE**: el frontend Web persiste JWT, pero actualmente la renovación automática del token está restringida a clientes nativos.
- [ ] **QA-005** Selección de uno o varios roles y permisos por menú
- [ ] **QA-006** Aislamiento entre empresas y sucursales

### Registro, planes y onboarding
- [ ] **QA-007** Registro y activación de correo
- [ ] **QA-008** Elección y cambio de plan antes de pagar
- [ ] **QA-009** Pago de suscripción con tarjeta y PSE en pruebas
- [ ] **QA-010** Cancelar y renovar suscripción
- [ ] **QA-011** Puesta en marcha obligatoria y reanudable
- [ ] **QA-012** Catálogo de productos precargados con precios e imágenes

### Empresas, sucursales y usuarios
- [ ] **QA-013** CRUD empresas y permisos
- [ ] **QA-014** Crear, editar, activar, inactivar y eliminar sucursal
- [ ] **QA-015** Modal de sucursal con teclado abierto
- [ ] **QA-016** Cambio de sucursal en todos los módulos
- [ ] **QA-017** Gestión de usuarios y cupos por plan
- [ ] **QA-018** Roles personalizados, orden de menú y permisos

### Mesas, ventas y caja
- [ ] **QA-019** CRUD de mesas según rol y mesas inactivas
- [ ] **QA-020** Abrir mesa, cuentas múltiples y cambio de nombres
- [ ] **QA-021** Agregar, mover y quitar productos entre cuentas
- [ ] **QA-022** Venta directa sin mesa
- [ ] **QA-023** Pagar con efectivo, tarjeta, Nequi, DaviPlata, PSE y pagos mixtos
- [ ] **QA-024** Propinas, cambio y edición de medios de pago
- [ ] **QA-025** Finalizar, cancelar y reabrir venta según reglas
- [ ] **QA-026** Historial con selección de fechas y búsqueda
- [ ] **QA-027** Factura por sistema PDF y ticket LAN 80 mm con nombre de sucursal
- [ ] **QA-028** Cierre de caja: base inicial, efectivo, otros medios, gastos y diferencias
- [ ] **QA-029** Confirmación y exportación de cierre

### Comandas y pedidos de cocina
- [ ] **QA-030** Personalización, recetas y tipos preparados
- [ ] **QA-031** Enviar nuevos productos a cocina una sola vez
- [ ] **QA-032** Reimprimir comandas
- [ ] **QA-033** Impresora independiente por estación y sucursal
- [ ] **QA-034** Estados nueva, preparación, lista y entregada
- [ ] **QA-035** Retorno a mesa y notificaciones de producto listo

### Productos, catálogo y precios
- [ ] **QA-036** CRUD productos, foto, tipo y marca
- [ ] **QA-037** Inactivar o eliminar uno o varios productos
- [ ] **QA-038** Precios de compra, venta y margen por empaque
- [ ] **QA-039** Cambiar productos de sucursal
- [ ] **QA-040** Importar plantilla Excel con validaciones
- [ ] **QA-041** Catálogo inicial y productos elaborados

### Inventario y movimientos
- [ ] **QA-042** Entrada inicial, compra y venta
- [ ] **QA-043** Ajustes positivos, negativos y justificación
- [ ] **QA-044** Préstamos y devoluciones
- [ ] **QA-045** Conteo y conciliación con catálogo
- [ ] **QA-046** Traspaso entre sucursales sin stock inicial
- [ ] **QA-047** Stock, alertas y auditoría de movimientos

### Pedidos de compra y proveedores
- [ ] **QA-048** Próximo pedido aun con inventario suficiente
- [ ] **QA-049** Productos por proveedor y teléfonos de WhatsApp
- [ ] **QA-050** Confirmar pedidos múltiples
- [ ] **QA-051** Recibir pedido y actualizar stock
- [ ] **QA-052** Registrar pago de pedido y salida de caja
- [ ] **QA-053** Eliminar pedido con pagos conservando trazabilidad
- [ ] **QA-054** Historial y fechas de pedidos

### Reportes y gastos
- [ ] **QA-055** Resumen y ganancias por día y mes
- [ ] **QA-056** Ganancias descontando costos y mano de obra
- [ ] **QA-057** Gastos fijos, variables y turnos L-V/S-D
- [ ] **QA-058** Inventario esperado vs conteo
- [ ] **QA-059** Pedidos sugeridos, rotación y movimientos
- [ ] **QA-060** Exportación a Excel, PDF y WhatsApp

### Administración y soporte
- [ ] **QA-061** Dashboard gerente en tiempo real
- [ ] **QA-062** Parámetros y medios de pago por sucursal
- [ ] **QA-063** Tablas paramétricas y permisos globales
- [ ] **QA-064** Auditoría, diagnósticos y explorador de datos
- [ ] **QA-065** Ayuda contextual y navegación responsive

### Distribución
- [ ] **QA-066** Sitio público, funciones y descargas
- [ ] **QA-067** Protección antibots y enlaces seguros
- [ ] **QA-068** Actualizaciones y descarga Windows/Linux/macOS
- [ ] **QA-069** Publicación y arranque Android/iOS


## Reglas
1. Ejecutar **una prueba a la vez**, no marcar aprobado por solo inspeccionar código o por un workflow exitoso.
2. Reproducir y corregir un fallo en la rama de trabajo, registrar commit, volver a ejecutar antes de pasar al siguiente caso.
3. Usar entorno y usuarios de prueba; no ejecutar cambios destructivos ni pagos reales en producción.
4. Las funciones dependientes de hardware, tienda o plataforma se marcan `NO APLICA` únicamente en el entorno donde de verdad no existan.
5. Al cierre registrar reporte por caso y matriz de 4 × 3. Una función está aprobada globalmente cuando estén aprobadas las combinaciones aplicables.

## Primera prueba propuesta
**QA-001 / Web / Ronda 1 — Inicio de sesión.** Abrir `/login`; entrar con cuenta de pruebas válida y comprobar que se muestra la vista autorizada sin errores. Repetir con credenciales inválidas. No compartir contraseñas ni tokens en evidencias.
