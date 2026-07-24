# Menú dinámico por rol

El frontend ahora construye el menú lateral y el dashboard de módulos desde la base de datos, no desde una lista quemada.

## Flujo implementado

1. El usuario inicia sesión en `/api/v1/auth/login`.
2. El backend devuelve el JWT y la lista de roles del usuario en `data.roles`.
3. El frontend guarda los roles en almacenamiento seguro.
4. Al entrar al layout principal, Flutter consulta:
   - `GET /api/v1/roles`
   - `GET /api/v1/opcionesmenu`
   - `GET /api/v1/menus`
5. Con los roles del login se resuelven los `roleId`.
6. Con los `roleId` se filtran las opciones de `OPCIONMENU`.
7. Con los `menuId` autorizados se filtran los registros de `MENUS`.
8. El valor `menuParametro` se usa para navegar a la ruta Flutter correspondiente.

## Archivos principales

- `lib/features/navigation/data/repositories/user_menu_repository.dart`
- `lib/features/navigation/presentation/providers/user_menu_provider.dart`
- `lib/features/navigation/data/models/user_menu_item.dart`
- `lib/core/widgets/app_scaffold.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/auth/presentation/providers/auth_provider.dart`

## Alias soportados

El frontend soporta diferencias entre el nombre REST y la ruta visual:

- `cuentasventa` -> `cuentas_venta`
- `detallecuentaventa` -> `detalle_cuenta_venta`
- `mediospago` -> `medios_pago`
- `opcionesmenu` -> `opciones_menu`
- `tiposproducto` -> `tipos_producto`
- `zonashorarias` -> `zonas_horarias`

## Nota

La UI filtra la navegación por rol para mejorar experiencia y claridad, pero la seguridad real debe seguir estando validada en el backend con JWT y permisos por endpoint.
