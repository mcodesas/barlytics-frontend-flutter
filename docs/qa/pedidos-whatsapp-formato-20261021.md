# QA — Mensajes WhatsApp para pedidos de compra

**Rama:** feat/ganancias-desglose-gastos-20261020

## Verificaciones

1. Crear un pedido en **Inventario → Próximo pedido** y confirmarlo por proveedor.
2. Seleccionar **Enviar por WhatsApp**. Verificar encabezado, empresa comercial, sucursal, proveedor y fecha.
3. Confirmar que cada producto se presente como **cantidad + presentación — nombre**, antes de la descripción, unidades equivalentes y subtotal.
4. Usar compras por caja, paquete, botella y unidad: validar la cantidad confirmada en backend. La equivalencia en unidades aparece solo cuando es distinta del número de presentaciones.
5. Comprobar saltos de línea entre encabezado, introducción, productos, total, observaciones y despedida en WhatsApp Web, Android y iOS.
6. Verificar que las **observaciones sean las del pedido confirmado**, no texto editado después.
7. Probar dos proveedores: mensajes separados por destinatario, sin mezclar productos.
8. Probar multi-sucursal y varias empresas: el nombre comercial debe corresponder a la empresa de la sucursal activa.
9. Probar productos sin descripción, sin presentación y sin costo: mensaje legible sin texto null y sin precios ficticios.
10. Si algunos productos carecen de costo, el total debe indicar TOTAL ESTIMADO PARCIAL.
11. La URL de WhatsApp usa Uri.encodeComponent(message); revisar saltos de línea y caracteres especiales.
12. Abrir WhatsApp no debe confirmar, eliminar, recibir ni modificar nuevamente un pedido.

## Cantidades por presentación al seleccionar pedidos

1. En **Próximo pedido**, configurar un producto con compra por cantidad (por ejemplo, paquetes de 12). Verificar que tanto la lista como el resumen digan **2 paquetes x 12** en lugar de 2 unidades.
2. Desde **Pedido manual**, incrementar la cantidad a 3. Debe verse **3 paquetes x 12** y enviarse al backend como 3 presentaciones, equivalentes a 36 unidades de inventario.
3. Revisar productos con compra por caja x 24, paquete de 6 y unidad individual. Las cajas/paquetes deben respetar su presentación; los unitarios siguen diciendo unidades.
4. Confirmar el pedido, consultar historial y abrir WhatsApp. Los tres lugares deben mostrar la misma cantidad por presentación, sin multiplicarla de nuevo.
5. Probar datos anteriores cuya etiqueta de presentación sea `Unidad`, `Unidad x 12` o `Presentación` pero tengan `unidades_por_presentacion > 1`: mostrar paquetes correctamente.
6. Verificar selección y botones +/- en móvil, escritorio y web, sin desbordar las filas al mostrar la presentación completa.

## Comandos antes del PR

```bash
flutter test test/features/reportes/order_whatsapp_message_formatter_test.dart
flutter analyze lib/features/reportes/presentation/pages/reportes_page.dart lib/features/reportes/presentation/utils/order_whatsapp_message_formatter.dart
```

**Pendiente:** pruebas automatizadas y validación visual en dispositivos. No realizar merge o despliegue sin autorización.
