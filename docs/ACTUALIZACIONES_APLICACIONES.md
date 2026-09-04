# Actualizaciones de aplicaciones BarLytics

## Flujo de escritorio

Cada `push` a `main` generado después del merge de un Pull Request:

1. Ejecuta pruebas Flutter.
2. Compila Windows, Linux y macOS en release.
3. Genera:
   - `BarLytics-Windows-Setup.exe`
   - `barlytics-linux-amd64.deb`
   - `BarLytics-macOS.dmg`
4. Calcula SHA-256 de cada instalador.
5. Genera `/downloads/latest.json`.
6. Publica instaladores y manifiesto dentro del frontend de producción.

La versión funcional se toma de `pubspec.yaml` y el build de producción usa
`GITHUB_RUN_NUMBER`. De esta forma cada despliegue a `main` tiene un build
monótonamente creciente aunque no se cambie manualmente el `+build` de
`pubspec.yaml`.

## Comportamiento del cliente

Las aplicaciones instalables consultan al iniciar el parámetro público
`BARLYTICS_UPDATE_MANIFEST_URL`, cuyo valor por defecto es:

`https://www.barlytics.com.co/downloads/latest.json`

Si la versión/build publicada es superior a la instalada:

- Windows: muestra `Actualizar ahora`, descarga el EXE, valida SHA-256, inicia
  Inno Setup en modo silencioso, cierra BarLytics y lo vuelve a abrir al terminar.
- macOS: descarga el DMG, valida SHA-256 y lo abre. La sustitución final de la
  aplicación continúa bajo las reglas de macOS. Para actualización totalmente
  transparente se requerirá firma/notarización y un framework como Sparkle.
- Linux: descarga el DEB, valida SHA-256 y lo abre con el instalador del sistema.
  La instalación puede solicitar autorización administrativa.
- Android/iOS: abre la tienda configurada en los parámetros públicos. Las
  actualizaciones automáticas reales las administra Google Play/App Store según
  la configuración del dispositivo.

`Más tarde` pospone el aviso de esa versión durante 8 horas. Una actualización
marcada como obligatoria no permite posponerla.

## Activar actualizaciones móviles

Las URLs ya se administran en base de datos mediante:

- `BARLYTICS_DOWNLOAD_ANDROID_URL`
- `BARLYTICS_DOWNLOAD_IOS_URL`

Para evitar avisar a usuarios antes de que la nueva versión esté realmente en
la tienda, el manifiesto móvil está deshabilitado por defecto. Cuando el proceso
de publicación esté listo, crear estas Repository Variables en GitHub:

- `BARLYTICS_ANDROID_UPDATE_ENABLED=true`
- `BARLYTICS_IOS_UPDATE_ENABLED=true`

Actualmente el repositorio incluye Android, por lo que CI genera también un
`.aab`. El proyecto entregado todavía no contiene la carpeta `ios/`; la rama iOS
del actualizador queda implementada, pero no se puede generar/publicar un IPA
hasta incorporar la plataforma iOS, firma y credenciales de App Store Connect.

## Actualización obligatoria

Para una versión crítica se puede definir temporalmente:

- `BARLYTICS_UPDATE_MANDATORY=true`

El siguiente deploy generará `latest.json` con `mandatory: true`. Después del
release crítico conviene volver la variable a `false`.

## Pruebas locales

En `debug` el actualizador se deshabilita para no interrumpir el desarrollo.
Para probarlo explícitamente:

```bash
flutter run -d windows \
  --dart-define=ENV=prod \
  --dart-define=BARLYTICS_ENABLE_UPDATES=true \
  --dart-define=BARLYTICS_APP_VERSION=0.9.0 \
  --dart-define=BARLYTICS_APP_BUILD=1
```

La prueba usa el manifiesto público de producción, por lo que debe existir
`/downloads/latest.json`.
