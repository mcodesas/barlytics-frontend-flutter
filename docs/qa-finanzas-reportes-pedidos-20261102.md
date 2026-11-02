# BarLytics — seguimiento técnico y QA de gerencia, reportes y pedidos
Fecha: 2026-11-02  
Ramas: `fix/dialogos-responsive-scroll-movil-20261030` (frontend y backend).

> Este archivo distingue implementación en código de pruebas efectivamente ejecutadas.
> No sustituye Flutter analyze/test, Gradle test, ni pruebas funcionales con BD.

## Implementado en las ramas

- [x] Navegación: título visible de módulos y selección por la ruta específica; sin duplicación Mesero/Administrar mesas cuando ambos accesos están presentes.
- [x] QR por sucursal: seleccionar sucursal activa, guardar y validar mediante consulta posterior al servidor.
- [x] Pedidos pendientes: editar productos y unidades, añadir/quitar referencias, reenviar WhatsApp e imprimir PDF. Editar requiere desplegar frontend y backend de la misma rama.
- [x] Backend pedidos: bloqueo transaccional, validación de rol autorizado, solo estado CONFIRMADO, nunca reducir total debajo de pagos registrados, preservar precio y factor históricos.
- [x] Backend inventario: al recibir entrada, compensar saldo negativo anterior sin rechazar entradas parciales; salidas manuales siguen bloqueadas ante inventario insuficiente.
- [x] Regresión JUnit añadida para entrada de +3 con stock previo -5, saldo esperado -2.
- [x] Regresión JUnit añadida para edición de pedido recibido, pedido pagado y conservación de precio histórico.
- [x] Reportes: desglose de referencias y unidades para cada día con ventas finalizadas.
- [x] Reporte adicional de flujo monetario por medio: recaudo finalizado menos salidas ACTIVAS, con registro separado de salidas sin medio asignado.
- [x] Panel gerente: ingresos, costo de venta, utilidad, gastos por concepto, recaudo y flujo monetario por medio.

## Pendiente; NO marcar como implementado ni validado

- [ ] Libro auxiliar de dinero independiente de cierre (entradas externas, retiros, traslados entre medios, conciliación de cuentas y auditoría).
- [ ] Saldo **disponible esperado** por cuenta: saldo inicial + ingresos - egresos ± traslados, con conciliación bancaria y de efectivo. El flujo del periodo NO es saldo bancario.
- [ ] Asignar medio de pago a todos los tipos de egresos históricos. Algunos gastos de turno existentes carecen de MEPA_ID y deben mantenerse como «sin medio asignado» hasta regularización.
- [ ] Agenda de noticias y partidos: selección por región, deportes de interés, derechos de contenido y proveedor de datos confiable/licenciado; sin presentar partidos ficticios.
- [ ] Revisión funcional individual de *todos* los reportes, con gráficos comparativos, participación, análisis temporal, filtros y exportación consistente.
- [ ] Ejecutar `flutter analyze`, `flutter test` y `./gradlew test`; no disponibles desde el entorno de edición actual.
- [ ] Ejecutar QA E2E real en web, Android, iOS y escritorio, con sesión y base de pruebas.
- [ ] Validar conciliación de venta después del cierre y actualización exacta de arqueos y medios de pago en una BD de pruebas.

## Matriz obligatoria para QA

| Escenario | Validación esperada |
|---|---|
| Venta simple con dos unidades | Un movimiento de SALIDA, stock anterior -2 |
| Venta con varias cuentas y producto repetido | Consolidación por producto; no se duplica descuento |
| Venta preparada con receta y extras | Salen ingredientes/adiciones correspondientes, no el producto terminado dos veces |
| Finalizar la misma venta por duplicado | Segundo intento no altera stock ni pagos |
| Venta sin existencias | Venta POS puede registrar saldo negativo con auditoría |
| Recibir pedido con stock -5 y 3 unidades | Queda -2 sin error |
| Recibir pedido con stock -5 y 8 unidades | Queda +3 |
| Recibir dos veces el mismo pedido | Una sola entrada de inventario |
| Salida manual con stock insuficiente | Transacción rechazada |
| Editar pedido CONFIRMADO | Cambios conservados; stock no se modifica hasta recepción |
| Editar pedido RECIBIDO | API 422 y sin cambios |
| Reducir pedido por debajo de abonos | API 422 y sin cambios |
| QR guardado en sucursal A, abrir B y volver a A | QR de A se conserva; no se confunde con el de B |
| Medio de pago en reporte | Total ingresado por ventas, egresos realmente registrados, flujo neto; salidas sin medio separadas |
| Reporte ventas por día | Cada producto, unidades y ventas coincide con cuentas de ventas FINALIZADAS |
| Venta posterior a cierre de caja | Conciliación separada sin sobrescribir arqueo original |
| Responsive móvil | No overflow ni diálogos inaccesibles por scroll o teclado |

## Comandos de validación

Frontend (desde la raíz del repositorio): `flutter pub get && dart format --output=none --set-exit-if-changed lib && flutter analyze && flutter test`.

Backend (desde la raíz): `./gradlew test` (Windows: `gradlew.bat test`).

Ninguna de estas suites se ha ejecutado en el entorno de edición. No hay despliegue, PR ni merge a `main`.

## Recomendaciones arquitectónicas para etapa financiera

1. Separar resultado operativo (ganancia bruta/neta) de tesorería (saldos reales): son hechos contables distintos.
2. Registrar movimiento de dinero con sucursal, origen/destino, medio, importe, categoría, hora, tercero, soporte, usuario y reversión auditable; no permitir borrado físico.
3. Proteger contra duplicaciones usando idempotencia por operación y cierre transaccional.
4. Manejar transferencias entre medios como partida doble; el total agregado no debe cambiar al transferir.
5. Permitir arqueo y saldo inicial por medio y sucursal; diferenciar efectivo en caja, dinero digital y banco.
6. Conciliar pagos de facturas y compras con cuentas por pagar sin descontar dos veces los gastos de resultados.
