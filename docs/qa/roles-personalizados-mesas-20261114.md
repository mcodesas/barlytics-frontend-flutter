# QA – Mesas con rol personalizado

Fecha: 2026-11-14
Ramas: `feat/menu-digital-diseno-orden-20261114` en frontend y backend.

## Incidencia diagnosticada

Había dos restricciones que impedían operar con roles personalizados:

1. En el POS (`/mesero` y `/administrar_mesas`) las acciones crear/editar
   consultaban solo rol CAJERO o permiso `administrar_mesas`, sin considerar
   la opción del menú `mesas`. En backend, `POST/PUT /api/v1/mesero/mesas`
   tenían la misma condición en `@PreAuthorize`.
2. La vista `/mesas` cargaba las mesas en paralelo con dos endpoints de
   **Reportes** usando un mismo `Future.wait`. Un 403 por no tener el
   permiso de Reportes fallaba toda la carga e impedía interactuar con
   las mesas, aunque el rol sí tuviera permiso de Mesas.

## Contrato de permisos corregido

| Perfil activo | Listar | Crear | Editar descripción y número | Cambiar estado | Eliminar/inactivar |
| --- | --- | --- | --- | --- | --- |
| Personalizado con `mesas` | Sí | Sí | Sí, mesa activa | No en POS | No en POS |
| Personalizado con `administrar_mesas` | Sí | Sí | Sí | Sí | Sí |
| Cajero | Sí | Sí | Sí | Sí | Sí |
| Sin permiso de Mesas | Sin acciones autorizadas | No en POS | No en POS | No en POS | No en POS |

La operación siempre debe respetar la empresa y sucursal elegida. En
`MeseroService.findOperador` se reemplazó la validación de `usuario.sucuId`
obligatorio por la validación de sucursal activa de
`SucursalAccessService.selectedSucursalId()`, que comprueba realmente
las asignaciones vigentes y admite usuarios multisedes.

En el POS la edición de mesa inactiva y los cambios de estado continúan
requiriendo permiso elevado; la creación básica solo permite estado
`DISPONIBLE`. La eliminación conserva la autorización anterior.

## Casos manuales para ejecutar en QA

1. Configurar un rol personalizado con permiso **Mesas** y sin **Reportes**,
   **Administrar mesas** ni **Cajero**; asignar usuario y sucursal activa.
2. Entrar por `/mesas`: las mesas deben cargar aunque los endpoints de
   reportes devuelvan 403; crear mesa con número y descripción; cambiar su
   descripción y comprobar persistencia tras actualizar.
3. Entrar por `/mesero` (si el rol tiene acceso a esa ruta): debe aparecer
   **Agregar mesa** o botón flotante; crear y editar mesa activa.
4. Confirmar que el rol de solo Mesas no ve **Eliminar** ni selector de
   estado en el POS y que un `DELETE /api/v1/mesero/mesas/{id}`
   responde 403.
5. Comprobar que `POST` de mesa con estado `INACTIVA` u `OCUPADA`
   se rechaza cuando el permiso es únicamente `mesas`.
6. Iniciar sesión como cajero y administrador: crear/editar y
   eliminar/inactivar mantienen su funcionamiento anterior.
7. Intentar escribir en otra sucursal sin asignación enviando un
   `X-Sucursal-Id` ajeno: la API debe denegarlo.
8. Revocar la opción Mesas y repetir las operaciones POS: no se muestran
   las acciones y la API restringida no autoriza la escritura.

## Automatización agregada

- Flutter: `test/features/mesero/mesas_permission_policy_test.dart`
  cubre solo Mesas, solo Administración, sin permiso y cajero.
- Backend:
  `MeseroControllerMesasPermissionsTest` comprueba expresiones
  de seguridad sobre crear, editar y eliminar.

En el entorno de esta edición no se pudo ejecutar la suite Flutter/Java,
ni autenticarse con un rol de prueba. Se requieren tests y QA de integración
antes del merge. No hay PR ni despliegue.
