# Ajuste empresa: wizard transaccional y edición por pasos

## Creación

La pantalla de creación de empresa ahora funciona como un wizard interno de tres pasos:

1. Datos de empresa.
2. Sucursales.
3. Resumen y confirmación.

Durante la creación no se envía información al backend hasta presionar **Finalizar y registrar** en el resumen. Si el usuario cancela o abandona antes de finalizar, no se crea empresa ni sucursales.

## Validaciones

- El correo electrónico valida formato correcto.
- Sitio web es opcional.
- Logo es opcional.
- Si se informa sitio web, debe ser una URL con `http://` o `https://`.

## Sucursales

Las sucursales se agregan en borrador durante creación y usan ayudas de búsqueda para:

- Ciudad.
- Zona horaria.
- Moneda.
- País teléfono.

## Modificación

La edición usa los mismos pasos visuales. En edición:

- El paso de empresa se guarda al continuar.
- Las sucursales se crean, modifican o eliminan inmediatamente.
- El resumen muestra el consolidado antes de finalizar.
