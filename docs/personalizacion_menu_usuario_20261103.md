# Personalización privada de menú por usuario

**Rama:** `feat/menu-favoritos-orden-usuario-20261103`

## Uso

Desde cualquier menú autorizado abre **Personalizar mi menú**. La pantalla permite
arrastrar los módulos, usar flechas o **escribir directamente una posición**
(1 es el primer puesto) y confirmar con ✓ / Enter. También permite marcar
estrellas y seleccionar dónde aparecerán tus favoritos: **Solo menú**, **Solo
inicio**, **En ambos**. El botón flotante **Guardar mi menú** permanece visible
en toda la pantalla, incluso al final de listas largas.

En Inicio se muestran hasta seis accesos favoritos; en el menú lateral/móvil
aparecen antes de las categorías del catálogo. **En la barra inferior de
Gerente, Administrador, Cajero, Mesero, Inventario y roles personalizados**
los favoritos también tienen prioridad y respetan el número de posición.
**Inicio** permanece primero y **Más** permanece al final. Caben hasta tres
accesos personalizados entre ambos en la barra inferior del gerente; los
módulos restantes se encuentran en Más.

Los módulos siguen agrupados por las categorías definidas en `commerce.menus`.
El orden personal establece la prioridad de los grupos y, dentro de cada
grupo, de los módulos. El acceso a Inicio permanece fijo y no se oculta.

La opción **Restablecer** borra únicamente las preferencias propias y recupera
el orden original de los roles.

## Backend

Se agregó `V69__preferencias_menu_usuario.sql` con dos tablas:

- `commerce.usuario_menu_configuracion`: usuario, empresa, ubicación favorita
  y fecha de cambio.
- `commerce.usuario_menu_preferencia`: usuario, empresa, ID real de menú,
  orden entero y favorito.

El perfil desktop aplica también V69 cuando Flyway está deshabilitado.

La API autenticada en `/api/v1/me/menu-preferencias` expone:

- `GET`: trae solo preferencias de menús que actualmente tengan permisos.
- `PUT`: guarda una lista de `{menuId,orden,favorito}` y
  `mostrarFavoritos` (`MENU`, `INICIO`, `AMBOS`).
- `DELETE`: restablece las preferencias.

El backend resuelve **userId y empresa desde la sesión**, nunca desde el body,
y verifica cada `menuId` contra
`UserAccessService.findMenusByAuthenticatedUser()`. Las preferencias no
modifican `ROLES`, `USUARIOROL` ni `OPCIONMENU`, y no agregan módulos
sin permiso. El frontend aplica la personalización después de seleccionar
roles, de modo que cambiar de rol no revela accesos adicionales.

## QA y verificación antes del merge

1. Ejecutar `./gradlew test --tests "*MenuPersonalServiceTest"` en backend.
2. Ejecutar `flutter test test/features/navigation/menu_preferences_test.dart`.
3. Ejecutar `flutter analyze lib/features/navigation lib/features/home lib/core/widgets/app_scaffold.dart`.
4. Con roles distintos (Gerente, Cajero, Mesero, Inventario, rol
   personalizado), reordenar, guardar, refrescar navegador y abrir otro
   dispositivo: conservar preferencias del mismo usuario.
5. Comprobar que otra cuenta, aunque pertenezca a la misma sucursal, no
   cambia su orden.
6. Comprobar que favoritos no aparecen si se revoca el rol que los autorizaba.
7. Comprobar `MENU` / `INICIO` / `AMBOS`, escritorio ancho y móvil
   estrecho, y el menú contraído.
8. Probar restauración de las preferencias y el menú agrupado original.
9. Intentar guardar un menuId arbitrario o duplicado mediante HTTP:
   el backend debe responder HTTP 400.

**Los tests se han agregado, pero no se han ejecutado desde el entorno de
ChatGPT**. No crear PR ni desplegar sin autorización posterior.

## QA adicional: barra inferior y edición

10. Gerente: marcar Inventario y Reportes como favoritos; configurar posiciones
    1 y 2, guardar, ir a Inicio y verificar `Inicio | Inventario | Reportes |
    ... | Más` (prioridad de favoritos sobre grupos normales).
11. Marcando más de 3 favoritos, comprobar que los excedentes continúan
    disponibles en Más; no ocultar módulos autorizados.
12. Revisar perfiles Administrador, Cajero, Mesero, Inventario y roles propios
    en barra inferior, dispositivos de 320/390/768/1440 px.
13. Introducir posición 1 en un módulo lejano y pulsar ✓; comprobar movimiento,
    números recalculados y que no se duplican módulos.
14. Introducir posición 0, negativa, vacía o mayor que la lista: presentar
    advertencia sin perder el orden.
15. Desplazarse hasta cualquier punto de una lista larga: el botón flotante
    Guardar debe permanecer visible y habilitado.
16. Seleccionar `Solo inicio` y verificar que la barra inferior conserva
    los accesos normales y los favoritos aparecen únicamente en Inicio.
17. Abrir Personalizar mi menú desde Más cuando no cabe en la barra y
    después regresar a la pantalla anterior.

## Ajuste del modal «Más opciones» y agenda compacta de Inicio

- La búsqueda se ejecuta sobre las opciones autorizadas, incluido el texto
  descriptivo y el grupo de cada módulo.
- Se muestra un bloque **Mis favoritos** al inicio del modal cuando la
  preferencia del usuario está en `MENU` o `AMBOS`. Se ordena por su posición
  personalizada y admite abrirlos directamente. Si está en `INICIO`, el
  modal mantiene el comportamiento original.
- Los favoritos también pueden aparecer aquí aunque sean accesos de la barra
  inferior. Dentro del modal **no se repiten** en los grupos normales.
- Aplicado en «Más opciones» de Gerente/Operativo, «Más funciones» de roles
  personalizados, «Más opciones de inventario» y «Todas las herramientas» del
  Administrador. Se mantienen las categorías y los demás accesos.
- El buscador muestra primero los favoritos que coincidan y después el resto.
  Nunca se incorporan módulos que el usuario/rol no tenga autorizados.

En Inicio, **Partidos de hoy** ahora ocupa una tarjeta reducida con fecha,
contador, actualizar, acceso a agenda, y hasta cinco partidos en carrusel
horizontal de fichas compactas. Se mantiene la agenda completa en su ruta y
el enlace de procedencia de los datos. No se cambia el backend deportivo.

### QA de regresión adicional

18. Con tres favoritos en Reportes, Inventario y Ventas, comprobar que el
    modal «Más» muestra los tres primero, en su orden, y no los repite en sus
    categorías.
19. Abrir los favoritos tanto desde la barra inferior como desde Más.
20. Buscar un favorito por nombre/descripción y confirmar que aparece antes
    del resto; buscar un módulo no favorito y confirmar que sigue visible.
21. En «Solo inicio», verificar que no se priorizan favoritos en Más.
22. Revisar los modales de Gerente, Cajero/Mesero, Inventario, Administrador
    y roles personalizados en móvil y escritorio.
23. En Inicio comprobar que el componente Partidos de hoy ya no crece en
    vertical por cada encuentro, soporta títulos largos, sin partidos, errores
    de red y navegación hacia Agenda deportiva.
24. Ejecutar `flutter test test/features/navigation/bottom_menu_priority_test.dart`
    y `flutter test test/features/deportes/sports_today_bogota_test.dart`.

## Corrección de posición numérica (2026-11-04)

- Al ingresar un número válido, la lista aplica el nuevo orden automáticamente tras una breve pausa de escritura (650 ms), sin depender exclusivamente de ✓ o Enter.
- Para números de dos dígitos, el cambio se aplica cuando termina de escribir, evitando mover primero a la posición del primer dígito.
- Al solicitar la posición 1, el listado desplaza la vista hasta el encabezado del orden para hacer visible el módulo reubicado.
- Si se presiona **Guardar mi menú** antes de terminar la pausa o sin pulsar ✓, se aplica la posición pendiente antes de enviar la lista al backend.
- El movimiento se resuelve por ID de menú, en lugar de índices capturados por el widget, y se validan posiciones de 1 al total de módulos.
- Cobertura añadida: `test/features/navigation/menu_position_field_test.dart` y casos en `bottom_menu_priority_test.dart`.

Validación pendiente en entorno Flutter: `flutter test test/features/navigation/menu_position_field_test.dart test/features/navigation/bottom_menu_priority_test.dart` y `flutter analyze lib/features/navigation`.


## Consistencia visual de Personalizar mi menú (2026-11-04)

- La pantalla ahora utiliza `TechBackground`, el mismo fondo ilustrado de bar con patrón, luces y degradados que el resto de módulos; respeta `selectedAppPaletteProvider` y la preferencia `showBackgroundPattern`.
- El `Scaffold` permanece transparente para no tapar la ilustración.
- Cabecera y resumen de favoritos usan `TechGlassPanel` y `TechBrandMark`, componentes existentes del diseño de BarLytics.
- El panel de orden y cada módulo usan `palette.panelDecoration` y bordes temáticos; se preserva la distinción de favoritos.
- Se conserva el botón flotante **Guardar mi menú**, el reordenamiento por número, arrastre y flechas, el listado de favoritos y el filtro de visibilidad.
- QA visual pendiente de ejecución con Flutter: probar 320/390/768/1440 px; paletas oscuras y claras; estilo de superficie Plano, Suave y Cristal; patrón de fondo activado y desactivado; lista larga, teclado numérico móvil, botón flotante y guardado.
