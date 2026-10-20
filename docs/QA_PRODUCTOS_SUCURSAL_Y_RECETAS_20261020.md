# BarLytics — QA Productos: sucursal activa y edición de recetas

## Comportamiento corregido

- La única selección de sucursal para trabajar en Productos es el selector global del encabezado. Se eliminaron selector extra de sucursal activa, filtro de sucursal en la barra de filtros y filtro de sucursal en el modal móvil.
- Se eliminó **Todas las sucursales** de la pantalla. Al limpiar filtros se conserva la sucursal global.
- El `productosPagedProvider` no solicita productos hasta contar con sucursal activa; esa instancia exige `sucursalId`, y conserva paginación, búsqueda, marca, tipo y orden para esa sucursal.
- Las respuestas HTTP obsoletas se ignoran al cambiar sucursal o filtros. También se aplica filtro visual defensivo por `sucuId`.
- En tarjeta y tabla, **Modificar** navega al editor completo `/productos/{id}/editar`, cuyo bloque `Configuración para gastrobar` permite agregar y quitar ingredientes/adiciones y seleccionar la estación.
- El editor hidrata la receta usando la sucursal del producto cargado, no una sucursal obsoleta del almacenamiento local. Si no puede cargar `GET /api/v1/productos/{id}/gastro?sucursalId=...`, muestra mensaje y reintento; **bloquea guardar para evitar borrar relaciones por un fallo de API**.
- Las modificaciones de receta se guardan mediante el endpoint existente `PUT /api/v1/productos/{id}/gastro`; el backend valida que los componentes correspondan a la misma sucursal, usa transacción y reemplaza la receta enviada.

## Casos de prueba funcional (WEB, móvil y escritorio)

1. Acceder con usuario de dos sucursales. Productos debe tener **ningún selector adicional**: solo el selector global de la app.
2. Con sucursal A, verificar que `GET /api/v1/productos/page` incluye `sucursalId=A`. No deben mostrarse productos de sucursal B.
3. Cambiar a B desde la cabecera; debe recargar Productos con `sucursalId=B`. Si responde A después que B, no debe sobreescribir la pantalla.
4. Limpiar filtros, cambiar orden, buscar y paginar: todas las peticiones deben mantener el identificador de la sucursal activa.
5. Inicializar sesión sin sucursal elegida: no solicitar listado global, ni mostrar productos de sucursales ajenas.
6. En Tarjeta y Tabla pulsar **Modificar** de producto PREPARADO: debe abrir editor completo con relaciones existentes, incluyendo ingredientes, adiciones y cantidades.
7. Quitar un ingrediente, agregar uno nuevo de la misma sucursal, quitar y agregar una adición; guardar. Recargar edición y comprobar que la API y BD mantienen exactamente las relaciones seleccionadas.
8. Intentar asociar ingrediente de otra sucursal: el backend debe rechazarlo; el producto original debe conservarse.
9. Simular fallo/timeout de `GET /productos/{id}/gastro`: el editor muestra reintentar y no permite guardar hasta cargar la receta, sin eliminar relaciones.
10. Cambiar producto PREPARADO a NORMAL con el editor completo: guardar vacía sus relaciones solo cuando es una acción explícita del usuario.
11. Comprobar que `Seleccionar de otra sucursal` de la herramienta de migración **sigue existiendo**: es una acción distinta de la consulta del listado.
12. Verificar que los precios, histórico y movimientos continúan funcionando y que la pantalla no pierde filtros al recargar.

## Pruebas automáticas añadidas

`test/features/productos/productos_sucursal_activa_test.dart`: asegura filtrado por sucursal activa y lista vacía si no hay ninguna.

## Pendiente

No se ejecutaron `flutter analyze` ni `flutter test`, ni se probaron las APIs en TEST. Todos los cambios están únicamente en la rama `fix/catalogo-productos-permisos-roles-20261019` del frontend; sin PR ni merge.
