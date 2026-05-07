# Ajuste de tablas responsive y scroll

Se ajustaron los listados dinámicos para evitar que las columnas queden ocultas cuando la ventana es pequeña.

## Cambios realizados

- En móvil se usan tarjetas y el scroll vertical lo controla la pantalla principal.
- En tablet y web se usa tabla con scroll horizontal visible.
- Las tablas ya no limitan las columnas a las primeras 8; ahora muestran todos los campos configurados del módulo.
- Cada columna calcula un ancho mínimo según su tipo de dato.
- Los campos de ayuda/búsqueda se muestran como etiquetas visuales.
- La pantalla usa `SliverToBoxAdapter` para evitar conflictos de scroll con widgets internos.

## Regla mantenida

Las funcionalidades siguen siendo las mismas en móvil, tablet y web. Solo cambia la forma de visualizar los datos según el tamaño de pantalla.
