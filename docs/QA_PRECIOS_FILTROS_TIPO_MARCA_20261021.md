# QA · Precios: filtros Tipo / Marca

Rama: `feat/ganancias-desglose-gastos-20261020`. Sin PR, merge ni despliegue hasta autorización.

## Alcance

- Listar **todos**, **con precio**, **sin precio** y **modificados** por estado.
- Agregar filtros **Tipo de producto** y **Marca**, cargados de los mismos catálogos que Productos.
- Combinar ambos filtros con búsqueda por nombre/código, estado de precio y sucursal activa.
- Mantener selección mientras cambia de tabla a tarjetas, de página y mientras actualiza o guarda un precio.
- El filtro debe actuar en el **backend**: `GET /api/v1/productos/page?sucursalId=...&tipoId=...&marcaId=...&priceStatus=...&q=...`. No limitar a las primeras 12 filas.
- En vista **Modificados**, aplicar filtros locales sobre borradores pendientes, sin perder ni guardar automáticamente valores editados.
- **Limpiar filtros** debe restablecer búsqueda, tipo, marca y estado; no debe cambiar la sucursal ni descartar ediciones.
- Los cambios de sucursal deben impedir ver o guardar borradores de otra sede.
- Comprobar modo móvil, escritorio y web sin desbordes visuales.

## Casos manuales

1. Tipo = bebidas, Marca = una marca existente → solo referencias de esa intersección en toda la paginación.
2. Tipo distinto sin productos de esa marca → vacío claro, opción de limpiar.
3. Tipo = Todos, Marca específica y búsqueda por código → combinación correcta.
4. Tipo/Marca + Con precio / Sin precio → totales globales correctos.
5. Modificar precio en una tarjeta, seleccionar Tipo/Marca y abrir Modificados → borrador filtrado; cambiar a tabla, modificar otro precio; los cambios anteriores siguen pendientes.
6. Limpiar filtros sin guardar → precio editado sigue en Modificados.
7. Cambiar sucursal con borradores → confirmar descarte antes de cambiar desde la pantalla de precios.
8. Cambiar sucursal desde el encabezado global → no debe mostrarse ni guardarse un borrador de la sede anterior.
9. Regresar a la página anterior/siguiente con filtros → no mezclar productos.
10. Abrir Precios sin sucursal seleccionada → no exponer productos de otras sedes.

## Pruebas sugeridas

```bash
flutter test test/features/precios/precios_filter_utils_test.dart
flutter analyze lib/features/precios
```

**Nota:** Los cambios se han registrado en GitHub pero estas pruebas automatizadas no se han ejecutado en este entorno.
