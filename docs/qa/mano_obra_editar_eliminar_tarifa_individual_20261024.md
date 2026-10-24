# QA — Editar o eliminar un día concreto de mano de obra

Fecha: 24 de octubre de 2026

Rama backend/frontend: `fix/pedidos-eliminar-409-inicio-duplicado-20261022`.

## Problema corregido
Anteriormente la vista **Mano de obra → Tarifas e histórico** solamente ofrecía acciones para el cargo completo. No se podía editar ni retirar el precio de un día de la semana sin modificar otros registros.

## Implementación
- Cada fila de tarifa ahora tiene los botones **Editar únicamente esta tarifa** y **Eliminar únicamente esta tarifa**.
- El editor muestra costo y fecha de inicio. Para un día concreto permite editar la fecha; para período, inicio y fin; para una recurrencia conserva su día de semana.
- La actualización se identifica por `gafdId` y `gafcId` después de validar que el cargo corresponde a una sucursal autorizada.
- Recurrencia existente: si el usuario elige una fecha de inicio posterior, se cierra el tramo anterior un día antes y se crea uno nuevo solo para ese día semanal. El resto de días permanece intacto.
- Eliminar una recurrencia vigente: se finaliza desde hoy, conservando los meses anteriores. Si comienza hoy o después, se elimina el registro futuro.
- Tarifas históricas ya cerradas y tarifas de día único: pueden eliminarse con confirmación explícita, lo que puede cambiar los cálculos de reportes históricos.
- Un **PERIODO** se almacena como hasta siete filas en PostgreSQL, pero la interfaz lo presenta como una sola operación; editarlo o eliminarlo modifica **todo el período** como unidad lógica, nunca solo la primera fila.
- Listado visual: tarjetas con costo grande, estado **Vigente**, **Programada** o **Histórica**, fecha de vigencia y accesos por fila, adaptado a móvil.
- El panel del cargo distingue tarifas vigentes de tarifas programadas/históricas.

## Pruebas

1. Mesero L-V a 60 000 COP desde agosto: editar únicamente lunes a 70 000 desde octubre 24. El histórico de lunes hasta octubre 23 sigue a 60 000; de octubre 24 en adelante 70 000. Martes-viernes permanecen a 60 000.
2. Eliminar únicamente el martes: ya no se aplica desde hoy, pero sí en el pasado. Las demás tarifas siguen.
3. Editar tarifa `DIA` (por ejemplo 2026-10-20): cambia solo ese día, guarda fecha/valor y recalcula reportes de rango afectados.
4. Eliminar la tarifa puntual de ese día: desaparece y los reportes reflejan el cambio.
5. Editar `PERIODO` (tres días): actualiza todas sus filas internas y se visualiza como una sola tarjeta, sin duplicar importes por fecha.
6. Eliminar período que cruza hoy: respeta la parte histórica; período futuro se elimina completamente.
7. Editar una tarifa de otra sucursal: no permitido. Tampoco permitir cambiar una tarifa cuya ID no pertenece al cargo de la URL.
8. Reabrir la pantalla tras editar/eliminar: comprobar que persiste, que las tarifas pasadas se etiquetan como históricas, y que los reportes de ganancias se calculan por la fecha real.
9. Web, Android, iOS, Windows, macOS: comprobar iconos accesibles y sin overflow en pantallas estrechas.

## Validación técnica pendiente

`./gradlew test --tests com.barlytics.modules.gastofijo.api.GastoFijoTarifaIndividualTest`

`flutter analyze` y `flutter test`

No se ha ejecutado compilación en entorno local ni se ha generado PR/merge/despliegue. Pendiente ensayo integrado con PostgreSQL TEST.
