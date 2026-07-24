# Ocultar identificadores técnicos en UI

Se ajustó la interfaz para que los IDs técnicos no se impriman en listados, tarjetas móviles, detalles ni formularios.

Regla aplicada:

- Los IDs se conservan internamente para navegar, editar, eliminar y enviar relaciones al backend.
- El ID principal de cada registro no se muestra como columna ni como chip.
- Los campos terminados en `Id` sin ayuda de búsqueda se ocultan de la UI.
- Los campos relacionales con ayuda sí se muestran, pero solo con nombre/descripción, nunca con `#id`.
- Si una ayuda no puede resolverse, se muestra `-` u `Opción seleccionada`, no el número técnico.

Archivos principales:

- `lib/core/crud/crud_field_ordering.dart`
- `lib/core/crud/crud_lookup_resolver.dart`
- `lib/core/widgets/dynamic_crud_list_page.dart`
- `lib/core/widgets/dynamic_crud_detail_page.dart`
- `lib/core/widgets/dynamic_crud_form_page.dart`
- `lib/core/widgets/lookup_dropdown.dart`
