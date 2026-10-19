# BarLytics — Plan maestro de validación funcional

**Origen del plan:** `fix/historial-navegacion-eliminar-pedidos`. **Ramas activas del ciclo 2026-10-19:** frontend `fix/ios-header-role-selector-overlap-20261017`, backend `feat/setup-roles-per-company-20261017`. Los resultados históricos se conservan como evidencia, pero no sustituyen una nueva validación de versiones actuales.

**Rama de continuación para incidencias iPad:** `fix/ios-header-role-selector-overlap-20261017`. Esta rama no equivale a una validación de nueva build, ni autoriza PR o merge.

## Ciclo nuevo — QA multiplataforma desde cero (2026-10-19)

**Objetivo:** reiniciar desde **QA-001**, probando **el mismo caso funcional en tres frentes simultáneos: Móvil, Escritorio y Web**. No reiniciar IDs ni borrar los resultados anteriores. Registrar cada plataforma por separado: aprobar en Web **no aprueba** Móvil ni Escritorio.

**Dispositivos:**
- **Móvil:** Android e iPhone (iOS/TestFlight); tablet iPad/Android tablet para casos responsive. Informar modelo y build.
- **Escritorio:** Windows, macOS y Linux según el instalador disponible. Cada sistema operativo se registra individualmente, no se presupone equivalencia.
- **Web:** navegadores Chrome/Edge y Safari cuando corresponda; probar al menos navegador de escritorio y vista reducida para UX.

**Regla de avance:** abrir simultáneamente los tres frentes para QA-001; recoger resultados de cada plataforma, solucionar fallos en las ramas activas y repetir solo combinaciones afectadas. Continuar al QA-002 cuando los escenarios obligatorios de QA-001 estén aprobados o debidamente bloqueados/NO APLICA con motivo. Las rondas 1, 2 y 3 se mantienen, pero se registran por cada plataforma.

**Separación de versiones:** verificar la versión/build realmente instalada antes de cada prueba. Las correcciones recientes de caja, roles, Cocina/Barra e iPad están en ramas sin PR, merge ni despliegue: **no se pueden dar por validadas con las apps publicadas**. Preparar builds de prueba de las ramas antes de verificar dichas correcciones, sin tocar producción sin autorización.

### Estado del ciclo nuevo (ronda 1 / funcional)

| Caso | Web | Móvil Android | Móvil iOS | Escritorio Windows | Escritorio macOS | Escritorio Linux | Observaciones |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **QA-001** Inicio de sesión | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | Ciclo reiniciado: no heredar aprobado histórico. |
| **QA-002** Recuperación de contraseña | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | Iniciar después de cerrar QA-001. |
| **QA-003** Inicio de sesión social | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | Marcar NO APLICA solo tras comprobar disponibilidad real. |

**Seguimiento:** registrar resultados con fecha, entorno, SO/navegador, build, rol, sucursal, pasos, estado, evidencia/observaciones, issue/commit cuando haya corrección. Las celdas sin dispositivo ejecutado siguen PENDIENTE. Conservar la evidencia QA-001…QA-008 de 2026-10-15/17 únicamente en el registro histórico inferior.

### Subcaso visual: login web simplificado — 2026-10-19

- **Decisión de producto:** mostrar **únicamente el formulario de inicio de sesión**, centrado en el espacio disponible. Se eliminó el panel promocional izquierdo, el video, el texto comercial y los indicadores anteriores.
- **Web escritorio:** comprobar en Chrome/Edge y Safari que el formulario mantiene logo, correo, contraseña, inicio de sesión social, recuperación, registro y enlaces; centrado horizontal/verticalmente con ancho máximo de 530 px.
- **Registro compacto (ajuste UX):** verificar que debajo de “Entrar a BarLytics” aparezca discretamente “¿Aún no tienes cuenta? Crear mi cuenta” en una sola línea cuando alcance el ancho, con enlace visible y clic hacia `/registro`; en móvil web debe ajustarse sin overflow. No se muestra recuadro ni botón grande. La fila Caja/Mesas y la nota técnica JWT siguen ocultas en web; “Personalizar colores” conserva una jerarquía secundaria.
- **Regresión nativa:** comprobar que las aplicaciones Android, iOS, Windows, macOS y Linux conservan la opción “Registrarse” y los accesos originales. **Pendiente de validación visual/funcional**, no aprobado.
- **Web angosta y ventana baja:** verificar que el formulario sigue visible, permite desplazarse con el teclado y el enlace "Volver" no tapa los campos.
- **Apps nativas:** conservar diseño anterior en Android, iOS, Windows, macOS y Linux. Esta simplificación solo se aplica a Flutter web.
- **Estado:** implementado en rama, pendiente de compilar y validar en navegador. No se ha publicado una nueva versión por esta corrección.

### QA-001 — Inicio de sesión, credenciales inválidas y bloqueo (nueva ejecución)

| Paso | Acción | Resultado esperado |
| --- | --- | --- |
| 1 | Abrir BarLytics en Web, app móvil y app de escritorio | Login legible, responsive, sin recortes ni overflow; no exponer rutas privadas sin autenticación |
| 2 | Iniciar sesión con cuenta de prueba habilitada | Acceso autorizado; empresa, sucursal y menú corresponden a la sesión |
| 3 | Cerrar sesión; intentar contraseña equivocada con cuenta de pruebas | Mensaje entendible sin filtrar datos, sin iniciar sesión |
| 4 | Comprobar límites/intentos de acceso **solo en cuenta de prueba** | Bloqueo/temporización según reglas, sin afectar cuentas productivas |
| 5 | Restaurar sesión válida, cerrar y reabrir aplicación/navegador | El comportamiento de persistencia corresponde a la plataforma (la prueba profunda se hará en QA-004) |

**Entrega de resultados:** Web: [Aprobado/Falló/Bloqueado/No aplica + evidencia]; Móvil Android: [...]; Móvil iOS: [...]; Escritorio Windows: [...]; Escritorio macOS: [...]; Escritorio Linux: [...]. Agrupar por caso QA-001, no marcar todas las plataformas por un solo resultado.

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
| 2026-10-15 | QA-005 | Web | 1 — Funcional | **APROBADO EN TERCERA REPRUEBA** | Usuario confirmó que los roles y las sucursales asignadas se actualizan correctamente sin reiniciar sesión. Se conservan dos repruebas fallidas previas en historial de incidencias. |
| 2026-10-15 | QA-006 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario). |
| 2026-10-15 | QA-007 | Web | 1 — Funcional | **APROBADO** | Ninguna (resultado informado por el usuario). |
| 2026-10-17 | QA-008 (guía iPad: cambio de roles y sucursales) | iPad — TestFlight | 1 — Funcional | **APROBADO** | Usuario confirmó los 6 pasos sin observaciones: todos los roles; rol único; varios roles; cambiar de sucursal; volver a la anterior; cerrar/reabrir aplicación conservando sesión y contexto. **Registro independiente del QA-008 maestro (elección de plan antes de pagar), que sigue pendiente.** |

**Avance verificable:** QA-001, QA-002, QA-003 y QA-006 aprobadas en Web / Ronda 1; QA-005 aprobada en tercera reprueba con actualización dinámica de roles y sucursales; QA-004 aprobada en reprueba de persistencia (restan escenarios de expiración y revocación). Los demás entornos y rondas permanecen pendientes; cada caso maestro se completa cuando se cubren las combinaciones aplicables.

### Incidencias responsive pendientes

| 2026-10-15 | QA-026 | Celular (Web móvil/iPhone) | 2 — Interfaz / UX | **FALLÓ — REPRUEBA PENDIENTE** | Captura del usuario: fecha de sección en columna de letras, indicadores y total salen del ancho, barra inferior resalta Mesas durante Historial. Ajustes frontend 3dfbdfab y 3a3dd778. |

### Historial de QA-005

- 2026-10-15: Primera incidencia: roles no se actualizaban sin reiniciar sesión.
- 2026-10-15: Reprueba fallida: los roles se actualizaban, pero aparecían sucursales no asignadas.
- 2026-10-15: Segunda reprueba fallida: continuaban apareciendo todas las sucursales.
- 2026-10-15: **Tercera reprueba aprobada**, según validación funcional del usuario en Web; los restantes entornos y rondas siguen pendientes.

### Ronda guiada de iPad / TestFlight — cambio de roles y sucursales

- **QA-008 (identificador de sesión guiada, no del catálogo maestro)** — 2026-10-17 — **APROBADO**, 6/6 pasos; entorno **iPad TestFlight**, ronda **funcional**, sin observaciones, confirmado por el usuario. Validó: todos los roles (menús sin duplicados), rol único (menús correspondientes), selección múltiple (consolidación de permisos), cambio A→B de sucursal (mesas/ventas/inventario/caja visibles según sede), regreso B→A (sin datos cruzados) y continuidad de sesión y contexto tras cerrar/reabrir la app.
- **Trazabilidad del catálogo:** aporta evidencia parcial a **QA-004** (persistencia; no prueba expiración/revocación), **QA-005** (selección de roles; no prueba revocación en segunda sesión), **QA-016** (cambio de sucursal en la sesión, sin cobertura de todos los módulos en ronda 3) y **QA-018** (roles personalizados y menú; no reemplaza pruebas administrativas de configuración). Estas casillas maestras se mantienen pendientes de sus escenarios restantes.
- **Sin incidencia que corregir:** no se requiere modificación funcional por este resultado. La corrección visual del encabezado para iPad permanece sin validar tras su integración en una nueva build de TestFlight.
- **Próximo caso guiado (QA-009):** verificar aislamiento multisucursal en **cierre de caja**, sin finalizar cierres reales ni modificar operaciones de producción: cambiar sucursal A/B, contrastar resumen/base/ventas/pagos/gastos y regresar; registrar cualquier contaminación cruzada con evidencia. No confundir con **QA-009 del catálogo maestro** (pago de suscripción).

## Catálogo de casos

### Acceso y seguridad
- [ ] **QA-001** Ingreso por usuario y contraseña, error de credenciales y bloqueo
- [ ] **QA-002** Recuperación de contraseña y correo
- [ ] **QA-003** Google Sign-In y Apple Sign-In donde aplique
- [ ] **QA-004** Expiración, persistencia y cierre de sesión
  - **Criterio Web:** al cerrar y volver a abrir el navegador debe restaurar la sesión, conservando rol y sucursal, sin nuevo login siempre que sea válida; al vencer el JWT deberá renovarse de forma segura. Logout explícito, revocación y cambio de contraseña deben impedir la restauración. **PENDIENTE DE VERIFICACIÓN / AJUSTE**: el frontend Web persiste JWT, pero actualmente la renovación automática del token está restringida a clientes nativos.
- [ ] **QA-005** Selección de uno o varios roles y permisos por menú
  - **Caso adicional obligatorio:** administrador agrega y revoca roles a un usuario actualmente autenticado desde una segunda sesión; sus menús deben actualizarse en máximo 20-30 segundos, sin logout ni F5; los endpoints restringidos deben rechazar roles revocados de inmediato. Estado: **REPRUEBA PENDIENTE**.
- [ ] **QA-006** Aislamiento entre empresas y sucursales

### Registro, planes y onboarding
- [ ] **QA-007** Registro y activación de correo
- [ ] **QA-008** Elección y cambio de plan antes de pagar
- [ ] **QA-009** Pago de suscripción con tarjeta y PSE en pruebas
- [ ] **QA-010** Cancelar y renovar suscripción
- [ ] **QA-011** Puesta en marcha obligatoria y reanudable
- [ ] **QA-012** Catálogo de productos precargados con precios e imágenes
  - **Prueba específica Señorazo (pendiente):** después de desplegar backend con V31, el asistente de nueva empresa debe listar los 58 productos activos del respaldo de la sucursal Señorazo; no deben aparecer los 12 ejemplos genéricos anteriores. Verificar 9 tipos, nombres y marcas, precios de compra/venta y compra por cantidad; los 51 productos que tienen foto en el respaldo deben mostrarla. Los otros 7 no tienen foto de origen (no inventar imágenes).
  - **Seguridad y datos:** importar productos seleccionados en una empresa nueva de pruebas, sin transferir stock ni modificar productos/precios/ventas del Señorazo. Confirmar que las demás empresas no reciben productos sin seleccionarlos.
  - **Archivos backend:** V31__catalogo_inicial_productos_senorazo.sql y ProductoCatalogoBaseBootstrap.java. Solo migración nueva: no editar checksum de V28.

### Empresas, sucursales y usuarios
- [ ] **QA-013** CRUD empresas y permisos
- [ ] **QA-014** Crear, editar, activar, inactivar y eliminar sucursal
- [ ] **QA-015** Modal de sucursal con teclado abierto
- [ ] **QA-016** Cambio de sucursal en todos los módulos
- [ ] **QA-017** Gestión de usuarios y cupos por plan
- [ ] **QA-018** Roles personalizados, orden de menú y permisos
- [ ] **QA-072** Ajustes de gastos y pedidos externos después del cierre de caja
  - Configurar 2 sucursales A/B con distintos valores de ventas y caja, registrar gastos en A y cerrar el turno. Editar valor, descripción y categoría del gasto: el cierre sigue cerrado, se actualizan movimientos, total de gastos, cruce y **faltante/sobrante** de A sin modificar B ni ventas incluidas.
  - Agregar y anular una salida después del cierre y comprobar que se recalculan totales persistidos y resumen/PDF; el registro anulado conserva referencia para auditoría y deja de afectar las sumas.
  - Pagar pedido registrado con saldo parcial, después editar el pago: no debe exceder el saldo total disponible considerando su valor anterior; mantener vínculo de pago e inventario y no duplicar movimientos.
  - Registrar **PAGO_PEDIDO sin pedido seleccionado** aportando descripción, valor y medio de pago: el campo `pedi_id` debe ser NULL, no se escribe a `pedido_compra_pago`, no se altera inventario, no falla restricción `ck_salida_caja_referencia`; comprobar que permite volver a elegir 'Sin pedido asociado'.
  - Probar pagos externos en efectivo y Nequi/DaviPlata: los electrónicos deben aparecer en el registro pero no afectar la diferencia de efectivo.
  - Rechazar edición de gasto de otra sucursal, de movimiento anulado, cambio de tipo o cambio de pedido asociado. Confirmar que el cierre histórico pertenece a su sucursal.
  - Aplicar primero en PostgreSQL la migración **V32__permitir_pagos_pedido_externos_sin_pedido.sql** (Flyway o manual) antes de usar este cambio en producción. Pendientes `./gradlew test` y `flutter analyze`. No desplegar ni fusionar sin autorización.
- [ ] **QA-071** Roles y funciones configurables desde la puesta en marcha de empresas
  - **Nueva empresa:** al completar datos, sucursales, medios, catálogo y pedidos aparece **Roles y funciones** como etapa obligatoria antes de crear usuarios; probar guardar varios perfiles por empresa y asignarlos desde Usuarios.
  - **Plantillas editables:** Mesero, Caja, Cocina, Barra, Inventario, Movimientos y Supervisión muestran solamente opciones delegables. Cocina y Barra reciben inicialmente solo el módulo Comandas; pueden seleccionar su estación desde el filtro de comandas. Cada opción ofrece explicación y vista previa móvil/escritorio. Los nombres de plantillas no coinciden con roles globales reservados.
  - **QA de comandas por perfil:** crear rol personalizado de Cocina y otro de Barra; comprobar que ambos pueden ver comandas y gestionar la preparación según su menú asignado, sin acceso automático a ventas, cierre de caja, inventario ni administración. Renombrar el rol y comprobar que los permisos concedidos no desaparecen. Quitar Comandas y verificar que se revoca la gestión. Confirmar que el filtro Cocina/Barra funciona y no confundirlo con aislamiento obligatorio por estación en backend, que requeriría un permiso independiente.
  - **Opciones alternativas:** confirmar expresamente roles predefinidos con el botón correspondiente; verificar que solo afecta el estado de puesta en marcha de esa empresa, sin cambiar privilegios del sistema ni de otros tenants.
  - **Persistencia y seguridad:** tras guardar al menos un rol personalizado activo, la etapa se marca completa al actualizar el estado. Comprobar que usuarios sin permisos no administran roles ajenos, que roles inactivos no completan empresas nuevas, y que una empresa ya activada no se bloquea retroactivamente.
  - **Interfaz iPad:** comprobar modal de rol con teclado y vista previa, orden de opciones, vertical/horizontal, regreso a la guía, y confirmación de roles predefinidos.
  - **Pendiente de ejecución:** frontend rama `fix/ios-header-role-selector-overlap-20261017` y backend rama `feat/setup-roles-per-company-20261017`. Validar `flutter analyze` y `./gradlew test` antes de PR/merge.


### Mesas, ventas y caja
- [ ] **QA-019** CRUD de mesas según rol y mesas inactivas
- [ ] **QA-020** Abrir mesa, cuentas múltiples y cambio de nombres
- [ ] **QA-021** Agregar, mover y quitar productos entre cuentas
- [ ] **QA-022** Venta directa sin mesa
- [ ] **QA-023** Pagar con efectivo, tarjeta, Nequi, DaviPlata, PSE y pagos mixtos
- [ ] **QA-024** Propinas, cambio y edición de medios de pago
- [ ] **QA-025** Finalizar, cancelar y reabrir venta según reglas
- [ ] **QA-026** Historial con selección de fechas y búsqueda
  - **Celular / Web móvil / Ronda 2:** captura del usuario muestra cabecera comprimida y navegación de Historial mal seleccionada. Corregido en rama de trabajo, pendiente confirmar visualmente en iPhone (no aprobado todavía).
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
- [ ] **QA-070** Catálogo maestro global: acceso exclusivo administrador, CRUD y puesta en marcha
  - **Ronda funcional:** Administrador del aplicativo abre Soporte global > Catálogo maestro; crea un producto con nombre, código, categoría, marca, compra/venta e imagen; lo edita; filtra por estado/categoría; inactiva y reactiva. Debe verse o desaparecer de la selección de nueva empresa sin cambiar productos de empresas existentes.
  - **Ronda interfaz:** Web, celular, tablet y escritorio: comprobar diseño responsive, scroll de formulario y teclado, previsualización de fotos, confirmación de inactivación.
  - **Ronda integración y seguridad:** Gerente, Cajero, Inventario y Mesero no pueden abrir `/catalogo_maestro` ni consumir `/api/v1/admin/catalogo-maestro` (403). Verificar validaciones de código duplicado, imagen mayor de 2 MB, precio negativo y producto sin venta; no crear stock ni movimientos. El asistente importa únicamente seleccionados.
  - **Implementado en rama, pendiente ejecución:** backend `CatalogoMaestroProductoController`, `CatalogoMaestroProductoService` y DTO; frontend `master_catalog_page.dart` y repositorio.


### Distribución
- [ ] **QA-066** Sitio público, funciones y descargas
- [ ] **QA-067** Protección antibots y enlaces seguros
- [ ] **QA-068** Actualizaciones y descarga Windows/Linux/macOS
- [ ] **QA-069** Publicación y arranque Android/iOS


## Reglas
1. Ejecutar **un caso QA a la vez en tres frentes paralelos (Móvil, Escritorio y Web)**, con registros por dispositivo/SO. No aprobar por inspección de código ni por workflow exitoso.
2. Reproducir y corregir un fallo en la rama de trabajo, registrar commit, volver a ejecutar antes de pasar al siguiente caso.
3. Usar entorno y usuarios de prueba; no ejecutar cambios destructivos ni pagos reales en producción.
4. Las funciones dependientes de hardware, tienda o plataforma se marcan `NO APLICA` únicamente en el entorno donde de verdad no existan.
5. Registrar resultado por caso, plataforma y ronda (incluyendo subplataformas Android/iOS y Windows/macOS/Linux). Solo aprobar globalmente tras cubrir todas las combinaciones aplicables.

## Primera prueba del ciclo nuevo
**QA-001 / Web + Móvil + Escritorio / Ronda 1 — Inicio de sesión.** Seguir los cinco pasos del apartado «QA-001 — Inicio de sesión» en los tres frentes. Enviar resultados separados por SO/dispositivo, sin compartir contraseñas ni tokens.
