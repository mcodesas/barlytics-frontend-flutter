# QA — Historial completo de conteos físicos (24/10/2026)

Rama: `fix/pedidos-eliminar-409-inicio-duplicado-20261022`.

## Objetivo

La pantalla **Inventario → Control administrativo** debe mostrar todos los productos efectivamente registrados en cada jornada de conteo, aun si `contado = esperado`. La conciliación es una operación aparte y únicamente trabaja con diferencias pendientes.

## Cambios visibles

- El encabezado de la jornada muestra el número de productos contados y cuántos coincidieron con el esperado; tocar la jornada abre el detalle.
- En el detalle, **Todos los contados** está seleccionado inicialmente.
- El filtro **Solo diferencias** permite limitar temporalmente el detalle sin ocultar registros del backend ni modificar la valoración global de la jornada.
- Cada producto presenta **Esperado**, **Contado**, **Diferencia**, **Costo unitario**, **Valor esperado**, **Valor contado**, **Impacto en valor**, faltante y sobrante.
- Si no hay diferencias, al seleccionar ese filtro se explica que los productos coincidieron; **Todos los contados** siempre permite regresar al listado completo.
- El backend utiliza `LEFT JOIN PRODUCTOS` para no perder la auditoría de un conteo físico si se retiró su producto del catálogo. Se muestra `Producto #ID` cuando ya no hay nombre.
- Los importes se calculan desde la respuesta histórica `/api/v1/inventario/administracion`, que toma el costo de compra aplicable a la fecha del conteo.

## Casos a validar

1. Producto A: esperado 20, contado 20 — debe aparecer con diferencia 0 y valoración completa.
2. Producto B: esperado 15, contado 12 — diferencia -3, faltante valorizado.
3. Producto C: esperado 10, contado 13 — diferencia +3, sobrante valorizado.
4. Ver **Todos los contados (3)**: deben mostrarse A, B y C, con su valor esperado y contado individual.
5. Ver **Solo diferencias (2)**: deben mostrarse B y C. Volver a **Todos los contados**: aparece A sin recargar el historial.
6. Jornada sin diferencias: listado completo disponible, filtro de diferencias muestra estado vacío explicativo.
7. Verificar que los KPIs del día incluyen el valor económico de todos los productos, no solo los faltantes.
8. Cambiar fecha, sucursal y hacer una búsqueda de producto: nunca mostrar datos de otra sucursal ni reemplazar conteos históricos con el stock actual.
9. Producto inactivo o eliminado: el registro del conteo sigue apareciendo si existe en INVENTARIO.
10. Revisar en teléfono, tableta, escritorio y web: no debe haber recortes en chips ni en valores monetarios.

**Pendiente:** ejecutar `flutter analyze`, `flutter test` y prueba funcional integrada contra PostgreSQL antes de crear PR o hacer merge.
