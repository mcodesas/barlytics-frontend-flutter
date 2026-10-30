# QA · Diálogos y formularios responsive (30/10/2026)

## Rama de corrección

`fix/dialogos-responsive-scroll-movil-20261030` (frontend, separada de `main`).

## Problema reproducible

En teléfonos, el diálogo **Gastos → Mano de obra** mostraba los cargos y el
formulario en un contenedor de altura fija. Los controles de días y tarifas
desbordaban por debajo de la pantalla y el diálogo no permitía desplazar
verticalmente el formulario completo. La captura mostraba opciones "Sáb" y
"Dom" fuera del área accesible del diálogo.

## Ajustes implementados

| Área | Medida |
| --- | --- |
| Gastos / Mano de obra | Sustituir diálogo rígido por `Dialog` dimensionado por viewport/safe area/teclado; encabezado fijo; un scroll continuo para cargos, recurrencias, días, importes, fechas e historial, sin `Expanded` en scroll no acotado |
| Gastos / Tarifas / Cargos | Diálogos de edición, creación, desactivación y confirmación desplazables |
| Pedidos / Proveedor y WhatsApp | Scroll global del formulario, búsqueda y lista de productos con altura acotada; acciones de Guardar/Cancelar siguen fuera del scroll |
| Caja / Selector de cuenta | Altura máxima y desplazamiento para la lista de cuentas de cobro |
| Reportes / Pedido manual | Ajustes cuando se abre teclado o se reduce la ventana, conservando buscador y acciones |
| Eventos / Edición, reservas y cobros | Límites de altura según teclado y zonas seguras, conservando el scroll interno ya existente |
| Eventos / Confirmaciones y colores | Desplazamiento para mensajes y paletas largas |
| Inventario, movimientos, productos y mesas | AlertDialog con desplazamiento cuando el contenido excede la altura visible |
| Mesero / Ventas y cierres | Desplazamiento en formularios de pago, confirmaciones y otros diálogos sin scroll interno |
| Administración / Roles, empresas, catálogos y suscripciones | Desplazamiento en diálogos y confirmaciones extensos |
| Core / Mensajes, actualizaciones, lookup y seguridad | Desplazamiento y conservación de acciones de confirmación |

Los diálogos con un `SingleChildScrollView` funcional ya existente se
mantuvieron sin envolverlos nuevamente; los bottom sheets inspeccionados en
ventas, pagos, inventario, mesas, comandas, sucursales y usuarios ya utilizan
`isScrollControlled: true` (varios tienen scroll interno).

## Pruebas incluidas

- `test/core/widgets/dialog_scroll_responsive_test.dart`: diálogos reales
  en ventanas móviles (320×540 y 360×690).
- `test/features/gastos_fijos/dialogos_movil_scroll_regression_test.dart`:
  guardas de regresión estructural para Mano de obra, proveedores, cuentas y eventos.

## Checklist manual antes de aprobar

- [ ] iPhone pequeño 320–375 px: abrir Mano de obra, crear un cargo, elegir
  Lunes–Viernes y luego cambiar entre Recurrente, Un día y Período;
  verificar que se llega a **Guardar tarifa** y **Tarifas e histórico** con un solo scroll.
- [ ] iPhone 390 px y 430 px, modo vertical: probar diálogo vacío y con al
  menos diez cargos y veinte tarifas; no debe haber controles cortados.
- [ ] Android pequeño y tablet: comparar vistas compacta y de dos columnas.
- [ ] Con teclado visible: introducir importe, nombre de cargo, buscar
  proveedor y buscar cuentas; botón guardar/cancelar y campo activo accesibles.
- [ ] Cambiar tamaño de letra del sistema a 125 % y 150 %.
- [ ] Verificar gestos y scroll en Safari, Brave, Chrome Android, app iOS,
  app Android y escritorio.
- [ ] Repetir flujos de productos, inventario, movimientos, eventos,
  roles, suscripción, mesas, cierres de caja, pedidos y pagos.
- [ ] Ejecutar `flutter analyze` y `flutter test` antes del merge.

**Estado:** cambios y pruebas preparados en rama. No se ha realizado validación
en dispositivos reales ni compilación local.
