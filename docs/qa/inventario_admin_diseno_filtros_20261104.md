# QA — Inventario administrativo: diseño unificado y filtros por jornada/producto

Rama: `style/inventario-admin-diseno-unificado-20261104`
Ruta: `/inventario_admin`

## Ajuste visual

- Fondo de bar/ilustración mediante `TechBackground` y paleta configurada.
- Cabecera `TechGlassPanel` con `TechBrandMark`, título **Historial de conteos** y controles de sucursal, período y recarga.
- Tarjetas de indicadores económicos con mayor legibilidad y adaptación a móvil/tableta/escritorio.
- Panel de búsqueda y filtros con el estilo actual de la aplicación.
- Jornadas de conteo visibles antes de la bitácora de conciliaciones.
- Estado vacío integrado al diseño; no altera datos ni conciliaciones.

## Funcionalidad de consulta

1. Elegir la sucursal y un período que incluya las fechas históricas requeridas.
2. En **Fecha del conteo**, elegir una jornada concreta o **Todas las jornadas**.
3. En **Producto contado**, elegir un producto efectivamente contado en el período o jornada. Las opciones se limitan a los productos de la fecha si se eligió alguna.
4. El resultado filtra filas de productos, no solamente tarjetas de fecha. Muestra las cantidades **Esperado**, **Contado**, **Diferencia**, **Stock actual del sistema**, costos y estados correspondientes.
5. Se abre automáticamente la jornada al aplicar fecha o producto en los selectores globales.
6. Dentro de cada jornada expandida se puede escribir un nombre de producto o ID de conteo en **Buscar producto en esta jornada**; conserva el filtro **Todos / Solo diferencias**.
7. **Limpiar filtros** borra búsqueda, fecha, producto y filtro de estado; mantiene sucursal y rango de fechas.
8. Cambiar de sucursal o rango limpia las selecciones de fecha y producto para no mezclar información.
9. **Descargar Excel** con una fecha seleccionada exporta la jornada completa, no exclusivamente las filas de un producto seleccionado; el backend exporta el historial completo del día. **Excel de esta jornada** conserva el comportamiento original.

## Casos QA a ejecutar en Flutter

- Buscar una fecha con muchos productos y elegir uno: debe aparecer únicamente ese producto, con valores originales y sin mezclar otras fechas.
- Buscar un producto en múltiples fechas, luego limitar por día: desaparecen las demás jornadas.
- Alternar filtros de estados y **Solo diferencias** en el detalle; comprobar los totales.
- Consultar conteos sin diferencias y productos cuyo stock del sistema no está disponible.
- Seleccionar un producto, cambiar fecha y verificar que el producto se reinicia.
- Cambiar sucursal y rango de fechas sin conservar productos de la sucursal anterior.
- Comprobar casos vacíos, **Limpiar filtros**, vistas Tarjetas/Tabla y Excel.
- Revisar tamaños 320, 390, 768, 1024 y 1440 px; paletas clara/oscura, patrón activado/desactivado y scroll horizontal de la tabla.
- Ejecutar `flutter analyze lib/features/inventario/presentation` y
  `flutter test test/features/inventario/inventory_count_history_filter_test.dart`.

**Nota:** sólo hay comprobación estática hasta que estas pruebas se ejecuten con el SDK Flutter; no se ha creado PR ni fusionado a `main`.

## Descarga Excel: recuperación ante HTTP 500

- El frontend conserva la descarga oficial mediante `GET /api/v1/inventario/administracion/excel`.
- El cliente `ApiClient.getBytes` captura las fallas de red como `NetworkException(statusCode)`. Para códigos **500–599**, el módulo genera un archivo `.xlsx` en el dispositivo con los conteos previamente cargados para la sucursal autorizada.
- La recuperación no se activa ante 400, 401, 403 ni fallos de permisos.
- El archivo XLSX local contiene dos hojas (**Todos los conteos** y **Resumen**), columnas de esperado/contado/diferencia, stock operativo independiente, costos, estados, responsable y resumen económico.
- Todos los productos de una jornada visible se incluyen aunque la búsqueda por producto se aplique a la pantalla. No se recalculan inventarios ni se modifica la base.
- La implementación usa `archive: 4.0.9` (versión ya presente en `pubspec.lock`) como dependencia directa.
- El usuario recibe un mensaje diferenciado cuando el Excel se generó localmente a causa del error del servidor.

### Validación pendiente

- `flutter test test/features/inventario/inventory_history_xlsx_test.dart`
- `flutter analyze lib/features/inventario/presentation`
- Simular exportación exitosa, error 500 y error 403; abrir los archivos en Excel y verificar ambas hojas.
- Consultar el **stacktrace del backend** para corregir de raíz el HTTP 500. La captura de Dio por sí sola no identifica la excepción del servidor.
