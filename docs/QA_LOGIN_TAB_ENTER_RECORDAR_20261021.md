# QA · Login: Tab, Enter y recordar contraseña (21/10/2026)

**Rama**: `feat/ganancias-desglose-gastos-20261020`. Sin PR, merge ni despliegue.

## Teclado

1. Abrir login, escribir usuario, pulsar **Tab**: el foco debe pasar a **Contraseña** sin activar enlaces ni controles intermedios.
2. Desde el usuario, pulsar **Enter**: debe pasar a Contraseña.
3. Escribir contraseña y pulsar **Enter**: debe ejecutarse la misma validación y login que el botón **Entrar a BarLytics**, una sola vez.
4. Repetir con contraseña vacía, usuario vacío y credenciales incorrectas: mostrar validaciones, sin registrar una preferencia nueva.
5. Verificar **Shift+Tab** y navegación accesible, botón de mostrar/ocultar contraseña y dispositivos con teclado virtual.

## Recordar contraseña

1. Sin checkbox seleccionado, un login exitoso **no solicita explícitamente** al gestor guardar la contraseña y no conserva un identificador por esta nueva opción.
2. Con checkbox seleccionado, un login exitoso guarda el **identificador** en preferencias y solicita al gestor de contraseñas nativo o del navegador guardar las credenciales.
3. Al regresar al login se precarga el identificador recordado. El autocompletado de contraseña depende de que el gestor del dispositivo/navegador lo admita y de la decisión del usuario.
4. Desmarcar la opción borra inmediatamente la preferencia y el identificador. **No borra una contraseña que el usuario ya guardó en su gestor externo**; eso debe hacerse desde el gestor.
5. Comprobar que un intento fallido no solicite guardar contraseñas y que un acceso con Google o Apple no active el guardado del formulario usuario/clave.
6. Salir de la sesión y volver a abrir login: comprobar que la opción de recordar la cuenta permanezca cuando se activó, especialmente en macOS.
7. Verificar que **nunca** se almacene el texto de la contraseña en `SharedPreferences` / `localStorage`; solo `login_remember_password_enabled` y `login_remember_identifier`.
8. Probar Chrome, Edge, Safari, Android, iOS, Windows, macOS y Linux. Los gestores de contraseñas difieren según el sistema; si no ofrecen autofill, usuario y contraseña pueden ingresarse manualmente.
9. Comprobar que la persistencia de JWT existente siga funcionando y que el checkbox no fuerce logout ni modifique el flujo de Google.

## Pruebas disponibles

```bash
flutter test test/features/auth/data/remember_login_preferences_test.dart
flutter analyze lib/features/auth lib/core/storage/secure_storage_service_io.dart lib/core/constants/storage_keys.dart
```

**Estado:** Cambios publicados únicamente en la rama; pruebas manuales y compilación Flutter aún no ejecutadas.
