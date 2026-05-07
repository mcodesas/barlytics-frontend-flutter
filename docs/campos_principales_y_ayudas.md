# Corrección de campos principales y ayudas de búsqueda

## Problema corregido

En los listados móviles y algunas tablas, el primer campo de negocio visible podía ser una llave foránea como `regiId`, `paisId`, `emprId` o `sucuId`. Por eso, en ciudades se veía como principal la región (`Cundinamarca - CUN`) y la ciudad quedaba como dato secundario.

## Ajuste aplicado

El frontend ahora calcula el campo principal del registro priorizando campos humanos:

1. Nombre.
2. Número.
3. Código.
4. Email/correo.
5. Estado.
6. Descripción.

Las llaves foráneas y campos `*Id` no se usan como título principal de tarjetas o detalles.

Ejemplo en ciudades:

- Antes: `Cundinamarca - CUN (#1)`
- Ahora: `Fusagasugá`

La región queda como dato secundario o columna relacionada.

## Formularios

Se agregaron ayudas de búsqueda para los campos relacionales que aún quedaban como ID manual:

- `tiidId` -> Tipo de identificación.
- `tiusId` -> Tipo de usuario.
- `timoId` -> Tipo de movimiento.

Estos campos quedan preparados para consultar:

- `/api/v1/tiposidentificacion`
- `/api/v1/tiposusuario`
- `/api/v1/tiposmovimiento`

Si alguno de esos endpoints todavía no existe en el backend, la pantalla mostrará el campo como ayuda pero no podrá cargar opciones hasta que el backend exponga el catálogo correspondiente.
