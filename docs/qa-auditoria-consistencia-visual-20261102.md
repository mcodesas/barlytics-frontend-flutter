# BarLytics · Auditoría transversal de consistencia visual

Fecha: 2026-11-02
Rama: `fix/dialogos-responsive-scroll-movil-20261030`
Alcance: frontend Flutter para Web, móvil y escritorio.

## Inventario y método

- Árbol de GitHub revisado: **694 archivos Dart**, **209 archivos bajo `features/*/presentation/{pages,widgets}`** y 48 archivos de pruebas Flutter existentes antes de este trabajo.
- Revisión estática por familias de interfaz y lectura de implementaciones representativas: navegación `AppScaffold`, diseño `AppTheme`/`AppPalette`, CRUD genérico y pantallas especiales de operación/administración.
- Se incorporó `tool/audit_visual_consistency.dart` para que el desarrollador ejecute una revisión completa y repetible de los archivos de presentación desde su copia local, con hallazgos de posibles diálogos sin scroll, modales afectados por el teclado, pantallas sin tema y alturas fijas.
- Esta auditoría **no equivale a QA visual manual de todas las pantallas**. No se pudo ejecutar Flutter ni simular dispositivos desde el entorno de edición. Los indicadores del auditor son heurísticos; pueden contener falsos positivos.

## Contrato visual existente que se debe conservar

1. **Tema:** `AppTheme.buildFromPalette` aplica colores, contraste, densidad, tipografía, superficies, botones, campos, diálogos y hojas inferiores desde `AppPalette`. Los colores de una vista privada no deben introducirse arbitrariamente.
2. **Navegación:** `AppScaffold` ofrece título, indicador de pantalla, selector de roles/sucursal y navegación sensible a `MENUS`/`OPCIONMENU`. La opción activa debe estar resaltada, expandida y accesible arriba.
3. **Estructura:** fondo de aplicación + encabezado/identidad del módulo + controles de acción y filtros + contenido en tarjetas/tablas responsivas + mensajes de estados vacío, carga y error.
4. **Móvil y teclado:** diálogos desplazables, formularios accesibles con el teclado abierto, sin alturas mínimas mayores que el espacio visible ni botones ocultos.
5. **Seguridad:** nunca renderizar operaciones o accesos funcionales para permisos no asignados; no mezclar sucursales.
6. **Excepciones de diseño intencionales:** landing pública y reservas de eventos se diseñan según el branding público y paleta del evento. Login, alta y activación pueden usar un layout distinto, pero siguen heredando `ThemeData` global.

## Revisión por grupos

| Área | Revisión de código | Observaciones |
|---|---|---|
| Catálogos CRUD (ciudades, países, regiones, monedas, marcas, tipos, menús, opciones, cuentas, pagos, medios y otros) | Estructura compartida | `DynamicCrudListPage`, `DynamicCrudFormPage` y `DynamicCrudDetailPage` ya consultan la paleta, fondo, estados y diseño responsive. Evitar duplicar cambios en sus clases wrapper. |
| Ventas, productos, inventario, comandas y mesas | Implementaciones grandes inspeccionadas | Cuentan con `AppPalette` y `AppPageBackground`; requieren QA funcional y con teclado en móvil por la cantidad de flujos propios. |
| Reportes, gastos fijos, pedidos y roles personalizados | Implementaciones y diálogos inspeccionados | Emplean tema. `ReportesPage` incluye dos diálogos con límites de altura/scroll interno que deben revisarse manualmente en pantallas compactas. |
| Usuarios, sucursales y empresas | Formularios y listados inspeccionados | Usan paleta centralizada; hojas inferiores con selección y campos deben cubrirse en QA móvil. |
| Gerencia e Inicio | Navegación y panel revisados | Módulos nuevos pasaron a tarjetas/paneles con tema activo; `AppScaffold` ahora prioriza la opción activa sin reescribir el orden de BD. |
| Deportes | Corregido | Pantalla completa + tarjeta resumida en Inicio, tarjetas por partido/noticia, filtros adaptables y fuente gratuita acreditada. |
| Tesorería | Corregido | Resumen financiero, tarjetas por medio, historial de movimientos, conciliaciones y diálogos con paleta. |
| Soporte, suscripciones, configuración del negocio y perfil | Vistas representativas revisadas | Usan `AppPalette` o heredan `ThemeData`; confirmar navegación y comportamiento final con usuario real. |
| Páginas públicas/eventos | Componentes de apariencia y comportamiento revisados | Conservan intencionalmente estilos específicos del evento o marketing, en vez de imponer la apariencia del panel interno. |

## Cambios realizados en la rama

- `lib/features/deportes/presentation/widgets/sports_agenda_widget.dart` y `pages/agenda_deportiva_page.dart`: normalización visual y responsive.
- `lib/features/tesoreria/presentation/pages/tesoreria_page.dart`: normalización de tarjetas, textos financieros, estados y diálogos.
- `lib/features/home/presentation/pages/manager_home_page.dart`: resumen deportivo compacto.
- `lib/core/widgets/app_scaffold.dart`: navegación activa resaltada y grupo activo primero, también en el menú de orden personalizado.
- `lib/app/theme/module_visuals.dart`: iconografía de Tesorería y Deportes.
- `lib/core/widgets/confirmation_dialog.dart`: confirmaciones globales dependientes del tema, con scroll.
- `test/app/theme/visual_consistency_test.dart`: protección del contrato de tema y confirmación en viewport de 320 px.
- `tool/audit_visual_consistency.dart`: auditoría de código de todas las interfaces de la copia local.

## QA obligatorio pendiente

1. Compilación: `flutter pub get && flutter analyze && flutter test`.
2. Auditoría de archivos: `dart run tool/audit_visual_consistency.dart`; clasificar cada aviso y corregir los confirmados.
3. Capturas y recorridos en **320, 390, 768, 1024 y 1440 px**, con zoom o escala de texto y teléfono en vertical/horizontal.
4. Repetir en tema **claro, oscuro y paletas personalizadas**, verificando contraste de iconos, títulos, formularios, gráficos, tarjetas y diálogos.
5. Probar formularios con teclado abierto, scroll, botones Guardar/Cancelar, selección de múltiples filas, modales y validación de errores.
6. Probar navegación con roles **Gerente, Cajero, Mesero, Inventario, roles personalizados y Administrador**, en cada sucursal autorizada, sin relogin.
7. Recorrer ventas, mesas, venta directa, cierre de caja, productos, precios, inventario, movimientos, pedidos, reportes, tesorería, deportes, eventos, reservas, usuarios, roles y suscripciones.
8. Comprobar fuentes externas y estados vacíos/errores de red en Deportes. Comprobar saldos, apertura y conciliación en Tesorería contra base de pruebas.
9. Pruebas reales en Android, iPhone/iPad, web y escritorio. Sin QA E2E aprobado no se debe declarar el repositorio libre de bugs.

**Estado:** ajustes estáticos confirmados en GitHub; pruebas automatizadas y visuales no ejecutadas. Sin PR, merge ni despliegue.
