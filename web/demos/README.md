# Demos reales de BarLytics

La landing pública ya no recrea manualmente las pantallas del sistema. Carga GIFs grabados directamente desde el aplicativo para que el visitante vea exactamente la interfaz real.

## Estructura

Coloca los GIFs con estos nombres:

### Escritorio
- `web/demos/desktop/inicio.gif`
- `web/demos/desktop/mesas.gif`
- `web/demos/desktop/venta-rapida.gif`
- `web/demos/desktop/cuenta.gif`
- `web/demos/desktop/cobro.gif`
- `web/demos/desktop/cierre-caja.gif`
- `web/demos/desktop/historial-ventas.gif`
- `web/demos/desktop/inventario.gif`
- `web/demos/desktop/productos.gif`
- `web/demos/desktop/precios.gif`
- `web/demos/desktop/movimientos.gif`
- `web/demos/desktop/pedidos.gif`
- `web/demos/desktop/reportes.gif`
- `web/demos/desktop/sucursales.gif`
- `web/demos/desktop/usuarios.gif`
- `web/demos/desktop/roles.gif`
- `web/demos/desktop/configuracion.gif`
- `web/demos/desktop/suscripcion.gif`

### Tablet
Los mismos nombres dentro de `web/demos/tablet/`.

### Celular
Los mismos nombres dentro de `web/demos/phone/`.

## Recomendación de grabación

- Duración: 6 a 15 segundos por módulo.
- Sin audio.
- Repetición continua.
- Evitar información real de clientes o empleados.
- Mantener el tema oficial de BarLytics.
- Escritorio: grabar en 1440x900 o 1280x800.
- Tablet: 1024x768 o proporción similar.
- Celular: 390x844 o proporción similar.
- Recortar el GIF para que empiece y termine de forma natural.

## Alternativa CDN

Si prefieres publicar las grabaciones en un CDN o servidor separado, compila con:

`--dart-define=BARLYTICS_DEMO_MEDIA_BASE_URL=https://tu-dominio.com/demos`

La estructura remota debe mantener las carpetas `desktop`, `tablet` y `phone`.

Si un GIF todavía no existe, la web muestra un placeholder elegante indicando el archivo que falta. No muestra una réplica falsa del aplicativo.
