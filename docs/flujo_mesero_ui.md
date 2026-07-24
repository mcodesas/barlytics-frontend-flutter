# UI de usuario tipo mesero

## Alcance implementado

Se agregó una experiencia visual específica para usuarios con rol `MESERO`:

- El usuario mesero no usa menú vertical funcional.
- La navegación principal se hace desde una **barra de navegación inferior**.
- La barra lateral/drawer queda limitada a **Mi perfil** y **Cerrar sesión**.
- Al iniciar sesión con rol `MESERO`, el sistema redirige automáticamente a `/mesero`.

## Rutas nuevas

| Ruta | Pantalla |
|---|---|
| `/mesero` | Operación de mesas: abrir venta, dividir cuentas y agregar productos. |
| `/mesero/productos` | Catálogo de productos con precio vigente para la sucursal del mesero. |
| `/mesero/resumen` | Resumen de total pendiente por mesa. |

## Flujo visual

1. El mesero ve únicamente mesas de su sucursal.
2. Selecciona una mesa.
3. Decide si divide la venta en cuentas.
4. Se crea o consulta la venta activa.
5. Selecciona una cuenta.
6. Agrega productos a la cuenta seleccionada.
7. La pantalla actualiza totales de cuenta, venta y resumen de mesas.

## Integración con backend

La UI consume los endpoints nuevos:

- `GET /api/v1/mesero/mesas`
- `GET /api/v1/mesero/productos`
- `POST /api/v1/mesero/ventas/abrir`
- `GET /api/v1/mesero/ventas/{ventaId}`
- `POST /api/v1/mesero/cuentas/{cuentaId}/productos`
