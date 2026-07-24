# Corrección: campo principal primero en tablas, tarjetas, detalles y formularios

Se corrigió el comportamiento para que los módulos no usen relaciones o IDs técnicos como dato principal.

## Regla aplicada

Cada módulo define un campo principal de negocio. Ese campo siempre aparece primero en:

- Tarjetas móviles.
- Tablas de tablet/web.
- Pantallas de detalle.
- Formularios de creación/edición.

Ejemplos:

- Ciudades: `ciudNombre` aparece primero.
- Empresas: `empreNombreComercial` aparece primero.
- Países: `paisNombre` aparece primero.
- Regiones: `regiNombre` aparece primero.
- Productos: `prodNombre` aparece primero.
- Sucursales: `sucuNombre` aparece primero.
- Roles: `roleNombre` aparece primero.
- Menús: `menuNombre` aparece primero.
- Zonas horarias: `zohoNombre` aparece primero.

## Archivos modificados

- `lib/core/crud/crud_field_ordering.dart`
- `lib/core/widgets/dynamic_crud_list_page.dart`
- `lib/core/widgets/dynamic_crud_detail_page.dart`
- `lib/core/widgets/dynamic_crud_form_page.dart`

## Nota

El resto de campos conserva el orden original después del campo principal. Esto evita perder información técnica, pero mejora la lectura para el usuario final.
