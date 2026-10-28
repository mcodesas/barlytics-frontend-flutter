# QA — Edición y guardado de productos en iPhone (23-10-2026)

Rama: `fix/pedidos-eliminar-409-inicio-duplicado-20261022`. Sin PR, merge ni despliegue.

## Edición
1. Entrar a **Inventario > Productos**, buscar un producto fuera de la primera página y pulsar Modificar. Debe consultar `/api/v1/productos/{id}` en lugar de depender de `productosProvider.items`.
2. Cargar precios del producto/sucursal con el endpoint de historial. Comprobar que los valores aparecen correctamente incluso cuando el proveedor de precios global esté paginado o filtrado.
3. iPhone: Nombre, Descripción, Tipo, Marca, Compra, Venta, Inventario y Confirmación deben mostrarse encima de la navegación; los botones Siguiente/Anterior no deben aparecer solos en una pantalla vacía.
4. Probar iPhone con teclado visible y oculto, y scroll largo de ingredientes, sin perder los botones ni recortar el contenido.
5. Cambiar entre los cuatro pasos y comprobar que se mantienen los valores que el usuario editó.
6. Simular API de producto o historial sin acceso/error: mostrar explicación y Reintentar. No abrir editor con formulario vacío ni guardar valores incompletos.
7. Cambiar sucursal antes o durante la carga: no editar accidentalmente el producto de otra sede.

## Guardado
1. Editar descripción, marca o presentación y confirmar. PUT debe responder exitosamente; después se debe ejecutar GET `/api/v1/productos/{id}` y comparar ID, sucursal y campos principales.
2. Tras una verificación correcta, abrir diálogo Producto actualizado con nombre e ID; no navegar automáticamente a Inicio ni a otra pantalla.
3. Pulsar **Volver a productos**: navegar a `/productos`. Pulsar **Seguir editando**: permanecer en el formulario.
4. Simular fallo del PUT inicial: no mostrar éxito. Simular fallo del precio/receta/inventario después del PUT: advertir guardado parcial y no navegar.
5. Simular GET posterior con datos anteriores: no afirmar guardado correcto; ofrecer revisión del producto.
6. Guardar un producto nuevo: mismo resultado confirmado sin navegación automática. Probar el flujo guiado de puesta en marcha.
7. Revisar receta PREPARADO, ingredientes/adiciones, stock máximo sin límite, compra por paquete y precio de venta para asegurar que se mantengan al editar.

## Pruebas de regresión

```bash
flutter test test/features/productos/presentation/widgets/product_wizard_viewport_test.dart
flutter test test/features/productos/presentation/utils/product_save_verification_test.dart
flutter analyze lib/features/productos
flutter test
```

**Estado:** revisión de código y commits realizados. Aún no se ejecutó compilación Flutter ni pruebas reales en iOS.