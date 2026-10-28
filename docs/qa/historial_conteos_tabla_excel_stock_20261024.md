# QA — Historial de conteos: tarjetas, tabla, Excel y stock actual

**Rama en frontend y backend:** `fix/pedidos-eliminar-409-inicio-duplicado-20261022`

## Regla principal

El conteo físico histórico y el stock actual del sistema **no son la misma variable**.

- **Esperado al conteo:** existencia que quedó guardada cuando se registró el conteo.
- **Contado:** unidades informadas por la persona en aquella fecha.
- **Diferencia:** contado menos esperado.
- **Stock actual del sistema:** existencia de la última fotografía de inventario de origen distinto de `CONTEO_FISICO%`, para **la misma sucursal y producto**, incluyendo movimientos de venta/compras y otros movimientos operativos. Nunca usa el valor contado del registro histórico.
- Si no existe ninguna fotografía operativa sin conteos, la UI muestra **Sin movimientos**. No presenta cero como si fuera un stock verificado.

## Interfaz

1. Abrir **Inventario → Control administrativo**. Se conservan filtros por sucursal, fechas, usuario, producto y estado de jornadas.
2. Alternar **Tarjetas / Tabla** desde la barra de historial. En tabla, comprobar encabezados claros, nombres, valores con formato COP, diferencias destacadas y desplazamiento horizontal en celular.
3. En cada jornada, alternar **Todos los contados / Solo diferencias**. Con la vista de tabla seleccionada, ambos filtros siguen funcionando.
4. En ambas vistas, verificar **Stock actual del sistema** independiente, actualizado de acuerdo con los movimientos, no con el conteo de la jornada.
5. Al abrir una jornada con diferencias cero en todos los productos, los productos siguen visibles en Tarjetas y en Tabla.
6. Verificar vistas con pantalla estrecha, iPad, escritorio y web, textos sin desbordamientos, contraste en modo claro/oscuro y tamaños legibles.
7. Exportar **Excel de esta jornada** y **Descargar Excel** (periodo visible) usando `/api/v1/inventario/administracion/excel`.
8. El XLSX tiene hojas **Todos los conteos** y **Resumen**; incluye también productos con diferencia 0, precio y valor económico, más el stock actual separado.
9. El Excel trae formato numérico, columnas anchas, filtro automático, encabezados fijos y resúmenes sin alterar la base.
10. Si no hay stock operativo sin conteos, Excel indica **Sin movimiento operativo**, no un 0 inventado.
11. Cambiar el filtro de jornadas (por ejemplo, **Con diferencias**): se exportan todas las filas de las jornadas que cumplan, incluso los productos cuadrados de esas jornadas.
12. Probar dos sucursales con el mismo `prod_id`, verificar que no hay cruce de stock ni de conteos.

## Validación pendiente

- Ejecutar `./gradlew test` en backend, incluyendo `InventarioConteosExcelServiceTest` e `InventarioHistorialConteosTest`.
- Ejecutar `flutter analyze` y `flutter test` en el frontend.
- Validar descarga y apertura de XLSX real en Excel y LibreOffice desde web, Windows y móviles.
- Verificar que un conteo físico no provoque que el valor de **stock actual del sistema (sin conteos)** cambie, mientras que una entrada/salida de movimientos sí lo cambia.

**No hacer PR ni merge a main sin autorización.**
