# QA — Historial de pagos y ventas después del cierre de caja
**Fecha:** 2026-11-02  
**Frontend:** `fix/dialogos-responsive-scroll-movil-20261030`  
**Backend consultado:** `mcodesas/barlytics-commerce-service`, rama `main` (solo lectura)

## Cambio del historial
- Cada registro de venta muestra **todos** los medios utilizados y el importe efectivamente pagado por cada uno. No se limita a los nombres de los dos primeros.
- El encabezado del historial suma por medio los pagos de las ventas visibles después de aplicar fecha, búsqueda y estado. Es un resumen de los registros cargados, no de todas las ventas históricas del negocio.
- La suma parte de `MeseroPagoModel.valor`. No suma `valorRecibido` ni `cambio` por segunda vez.
- Los métodos se agrupan por ID; en ausencia de ID, por nombre normalizado. Un mismo nombre con IDs diferentes conserva dos registros independientes.
- Cuando los totales de los pagos no coinciden con `totalPagado`, se muestra un aviso en vez de inventar medios de pago faltantes.
- Se vuelve a consultar el historial al entrar de nuevo a su pestaña; también el refresco manual consulta el historial.

## Verificación estática del cierre posterior
La implementación existente en el backend de `CierreCajaService`:
1. Conserva una lista de ventas **vinculadas a ese cierre**, sin incluir automáticamente ventas finalizadas después del arqueo.
2. Para cierres ya registrados, calcula `ventasPendientes` a partir de ventas FINALIZADAS de la misma sucursal y fecha que aún no pertenecen a ningún cierre.
3. `conciliarVentasPosteriores` valida sucursal, fecha, estado y duplicados, bloquea el registro de cierre para serializar cambios, registra auditoría y vincula solo las ventas seleccionadas.
4. Recalcula totales por medios de pago y diferencia, **sin modificar el dinero entregado original**.
5. Tiene pruebas JUnit: `CierreCajaVentasPosterioresTest` y `CierreCajaRecalculoPostCierreTest`, inspeccionadas pero no ejecutadas aquí.

## Ajuste de consulta en Flutter
- Volver a la pestaña Cierre de caja / Historial invalida el `Future` cargado anteriormente y vuelve a consultar al backend.
- Al deslizar para refrescar Cierre de caja se solicita el resumen de caja, no solo la lista de mesas.
- Con un cierre sin pendientes se muestra una explicación de qué ocurrirá si se registra otra venta finalizada ese día.
- Con pendientes se mantiene el listado y botón de **Conciliar ventas pendientes**, con confirmación de motivo.

## Matriz de pruebas pendientes en entorno controlado
| Caso | Acción | Esperado |
|---|---|---|
| HP-01 | Venta con $15.000 efectivo + $20.000 Nequi + $10.000 tarjeta | Historial muestra tres importes; total $45.000 |
| HP-02 | Venta repartida en dos cuentas, ambas con Nequi | Se suma Nequi una sola vez por tipo y se conserva detalle |
| HP-03 | Cambio autorizado de medio de pago histórico | El resumen refleja el nuevo medio tras regresar al historial |
| HP-04 | Consulta de diferentes fechas/sucursales | No se mezclan pagos o ventas |
| CC-01 | Cerrar día y posteriormente finalizar otra venta del mismo día | Aparece en ventas posteriores pendientes; el cierre no aumenta automáticamente |
| CC-02 | Regresar a Cierre de caja después de CC-01 | Se actualiza desde API, sin datos en caché |
| CC-03 | Conciliar la venta posterior con motivo | Actualiza ventas, medio y diferencia; valor entregado original intacto |
| CC-04 | Intentar conciliar la misma venta otra vez | Backend rechaza duplicación |
| CC-05 | Venta posterior de otra sucursal/día o no finalizada | No se añade al cierre ajeno |
| CC-06 | Venta nueva de fecha distinta | Aparece en el cierre de su propio día, no en el día anterior |

## Pruebas automatizadas agregadas en la rama frontend
- `test/features/mesero/historial_medios_pago_test.dart`
- `test/features/mesero/cierre_caja_ventas_posteriores_model_test.dart`

Comandos sugeridos:
```bash
flutter analyze
flutter test test/features/mesero/historial_medios_pago_test.dart
flutter test test/features/mesero/cierre_caja_ventas_posteriores_model_test.dart
```

Para verificar los tests JUnit **sin modificar el backend**:
```bash
./gradlew test --tests 'com.barlytics.modules.cierrecaja.usecase.CierreCajaVentasPosterioresTest' --tests 'com.barlytics.modules.cierrecaja.usecase.CierreCajaRecalculoPostCierreTest'
```

**Estado:** cambios y revisión de código guardados. Sin Flutter/Dart instalado localmente y sin ejecución de pruebas en una sesión real; no constituye aprobación QA de producción. Sin PR, sin merge y sin despliegue.
