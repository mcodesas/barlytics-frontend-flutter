# Ajuste visual del panel de mesas

Se compactó la vista principal de mesas para evitar tarjetas grandes y espacios vacíos.

Cambios realizados en `lib/features/mesero/presentation/pages/mesero_page.dart`:

- El resumen superior ya no ocupa una tarjeta de ancho completo; ahora muestra solo indicadores compactos.
- Las tarjetas usan una altura fija de 142 px en móvil y 150 px en pantallas amplias.
- En escritorio se muestran automáticamente más mesas por fila mediante `SliverGridDelegateWithMaxCrossAxisExtent`.
- Se eliminaron los recuadros internos de “Cuentas” y “Pendiente”.
- La información se muestra en una sola línea inferior con iconos, separador y acción lateral.
- Se redujeron radios, sombras, espacios y tamaño del encabezado.
- Se mantienen las acciones de editar, eliminar/inactivar, abrir y continuar venta.

No se modificó el backend ni la lógica de ventas.
