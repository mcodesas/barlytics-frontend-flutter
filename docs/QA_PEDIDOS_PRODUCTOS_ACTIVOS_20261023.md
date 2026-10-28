# QA · Productos eliminados / inactivos en nuevos pedidos

**Rama:** `fix/pedidos-eliminar-409-inicio-duplicado-20261022` en backend y frontend.

## Origen
En BarLytics los productos eliminados se conservan mediante `commerce.productos.prod_catalogo_activo = FALSE`, para mantener integridad de ventas, precios, inventarios y pedidos anteriores. La consulta compartida de `Ganancias` y `Próximo pedido` no transportaba ese estado y el módulo de compras ofrecía productos inactivos.

## Comportamiento corregido
1. `gananciasYProximoPedido` incluye la columna `catalogo_activo` en cada fila, sin eliminar los datos financieros históricos.
2. `Próximo pedido` filtra la lista visible, sugeridos, pedido manual, los borradores y el diagnóstico usando ese estado.
3. El Excel **Diagnóstico de inventario** excluye productos inactivos y no los suma en el resumen.
4. `POST /api/v1/pedidos-compra/confirmar` (incluido su uso desde confirmaciones múltiples) vuelve a consultar el producto por ID y sucursal y rechaza cualquier producto inactivo con error 422 antes de guardar el pedido.
5. El historial de pedidos existentes **NO** se filtra por actividad del catálogo: sigue permitiendo auditar compras anteriores.

## Pruebas manuales en TEST
1. Crear tres productos activos y uno sin costo. Elegir una sucursal. Eliminar o inactivar uno de los productos con costo.
2. Abrir **Inventario → Próximo pedido → Todos**. El eliminado no debe aparecer, aunque tenga inventario negativo, stock mínimo o precio configurado.
3. Abrir **Pedido manual**; buscar el nombre/código del producto eliminado. No debe aparecer.
4. Seleccionar un producto activo, marcarlo inactivo en otra sesión, e intentar confirmar desde la pantalla que seguía abierta. La API debe rechazar el intento sin crear un pedido parcial.
5. Verificar sugeridos, diagnóstico visual y Excel: solo productos activos, tanto en la lista como en los contadores y totales.
6. Volver a **Ganancias** y seleccionar un rango histórico anterior a la inactivación: la venta y el margen del producto deben seguir apareciendo.
7. Consultar **Historial de pedidos** con un pedido antiguo que contiene el producto eliminado: debe mostrarlo con las cantidades, importes y pagos originales.
8. Cambiar a otra sucursal con un producto del mismo nombre y validar que no se oculten ni se compren referencias de la sede equivocada.
9. Repetir los pasos 2–5 desde Chrome/Edge móvil, Safari en iPhone, Android y escritorio.

## QA de edición móvil relacionado
También verificar la pantalla **Modificar producto** desde la app iOS y desde Safari/Chrome en móvil: formulario visible encima de «Siguiente/Anterior», campos desplazables, navegación al pie y guardado funcional.

## Pruebas automatizadas añadidas

```bash
flutter test test/features/reportes/order_product_visibility_test.dart
flutter test test/features/productos/presentation/widgets/product_wizard_viewport_test.dart
./gradlew test --tests com.barlytics.modules.pedidoscompra.usecase.PedidoCompraProductoActivoTest
./gradlew test --tests com.barlytics.modules.reportes.dataproviders.jpa.ReporteDataProviderCatalogoActivoTest
./gradlew test --tests com.barlytics.modules.reportes.usecase.InventarioDiagnosticoExcelServiceTest
```

**Estado:** modificaciones guardadas en la rama. Las pruebas no han sido ejecutadas en este entorno, y no se generó PR ni merge.
