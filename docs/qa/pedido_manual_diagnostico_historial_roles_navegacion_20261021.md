# QA — Próximo pedido, diagnóstico, proveedores y menú

**Rama:** feat/ganancias-desglose-gastos-20261020. No fusionar ni desplegar antes de validar.

## Pedido manual
1. Entrar a Inventario > Próximo pedido con stock suficiente y pulsar Pedido manual: debe abrir un diálogo buscable.
2. Seleccionar productos, subir y bajar cantidades; agregar la selección al borrador sin confirmar automáticamente.
3. Cancelar el diálogo no debe modificar las cantidades existentes.
4. Verificar que productos sin costo de compra no puedan confirmarse, con indicación clara para configurar Precios.
5. Una vez agregado un borrador, confirmar pedido por proveedor y verificar cantidades y sucursal.

## WhatsApp por proveedor
1. Asociar un producto a un proveedor (productoIds) sin marcarlo predeterminado: al confirmar el pedido se selecciona ese proveedor, NO el WhatsApp general.
2. Con dos proveedores vinculados al mismo producto y sin predeterminado, exigir selección manual; bloquear Continuar hasta resolverlo.
3. Producto sin asociación: se permite WhatsApp general.
4. Desconectar temporalmente el endpoint de proveedores: la confirmación debe detenerse y no asumir que todo va al general.
5. Confirmar pedido con destino específico sin WhatsApp válido: al pulsar enviar, mostrar error en lugar de usar el número general.
6. Probar otra sucursal: nunca reutilizar los proveedores de la sucursal anterior.
7. Comprobar múltiples pedidos por proveedor y que el WhatsApp preparado contenga solo los productos de ese destino.

## Diagnóstico de inventario
1. Expandir Diagnóstico y alternar filtros Pedir ahora, Todos, Sin configurar y Sobrestock.
2. Escritorio: verificar tabla de 7 columnas y scroll horizontal, con estado, cantidades y costo visibles.
3. Móvil: comprobar tarjetas responsivas, textos legibles y ausencia de overflow.
4. Pulsar Excel: descargar XLSX válido con dos hojas, Diagnostico y Resumen; columnas filtrables y títulos.
5. Abrir el archivo en Microsoft Excel y LibreOffice Calc, comprobar números y cantidades, estado, costo y el alcance de la sucursal.
6. Comparar cada fila de Excel con el reporte que devuelve la API, incluidos productos sin inventario crítico.
7. Al cambiar sucursal o rango seleccionado, exportar de nuevo y comprobar que el archivo refleje esos parámetros.

## Historial de pedidos
1. Comprobar tipografía de 12–17 puntos, totales, abonos, saldo y estado de recepción.
2. Expandir un pedido y revisar paneles Productos y Pagos, observaciones y WhatsApp.
3. Probar varios pedidos en móvil, iPad, web y escritorio, sin superposición de importes ni tarjetas.
4. Confirmar que los pagos y saldos coincidan con el backend y no se recalculen incorrectamente en Flutter.

## Usuarios y navegación
1. Ir a Usuarios > Roles, guardar cambios y confirmar que regresa a /usuarios tras respuesta exitosa.
2. Simular error en la API de guardar roles: debe seguir abierto el editor para corregir o reintentar.
3. Validar rol normal y personalizado: Inicio aparece primero y nunca bajo Más > Otros.
4. Comprobar menú lateral, drawer móvil y navegación inferior sin duplicar Inicio.
5. Aplicar migración V39__inicio_como_menu_principal.sql en TEST: revisar menús home/inicio, roles y opciones sin cambios de permisos.

## Ejecución pendiente

```bash
flutter analyze
flutter test test/features/reportes/manual_purchase_order_dialog_test.dart
flutter test test/features/reportes/order_destination_resolver_test.dart
flutter test test/features/reportes/order_inventory_diagnostic_table_test.dart
flutter test test/features/reportes/order_history_card_test.dart
flutter test test/features/navigation/inicio_menu_mapping_test.dart
./gradlew clean test bootJar --no-daemon
```

**Nota:** los commits están en rama; la compilación, las pruebas automatizadas y el QA de dispositivos siguen pendientes.