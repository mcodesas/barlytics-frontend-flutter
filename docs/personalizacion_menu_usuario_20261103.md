# Personalización privada de menú por usuario

**Rama:** `feat/menu-favoritos-orden-usuario-20261103`

## Uso

Desde cualquier menú autorizado abre **Personalizar mi menú**. La pantalla permite
arrastrar los módulos, usar flechas para cambiar posiciones, marcarlos con
estrellas y seleccionar dónde aparecerán tus favoritos: **Solo menú**, **Solo
inicio**, **En ambos**. En Inicio se muestran hasta seis accesos favoritos;
en el menú lateral/móvil aparecen antes de las categorías del catálogo.

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
