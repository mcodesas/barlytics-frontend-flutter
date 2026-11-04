# Actualizaciones de aplicaciones BarLytics

## Motivo de la corrección (2026-11-04)

El manifiesto `/downloads/latest.json` publicaba siempre el build fijo de
`pubspec.yaml` (`1.0.0+1`) para Windows, Linux y macOS, aunque el ejecutable
cambiara con cada merge. El comparador no encontraba ninguna versión nueva.
Además, Android e iOS figuraban explícitamente con `enabled: false`.

**Regla:** una actualización se anuncia solamente después de que el artefacto
esté disponible para el dispositivo. Un cambio sin merge ni publicación NO
debe generar aviso a usuarios finales.

## Cómo se versiona

- Una integración nueva a `main` crea un commit nuevo.
- `deploy/update/release-build.sh` calcula un build monótono a partir de la
  fecha UTC del commit. Usa base `2002000000` para quedar por encima de los
  antiguos códigos Android `2001000000+...`. Todos los jobs del mismo commit
  comparten idéntico build y manifest.
- En Windows, el recurso nativo usa un número `1..65000` compatible con
  VERSIONINFO; `BARLYTICS_APP_BUILD` conserva el build completo para la
  comprobación de actualizaciones.
- Linux publica versión DEB `1.0.0+<build>`, no una versión fija.
- macOS usa el mismo build para el DMG. Si la versión macOS es anterior, el
  manifiesto conserva su versión real y SHA-256; no finge que sea nueva.
- Android genera un AAB con el build del commit. El job de imagen web espera la
  publicación correcta en Google Play **Internal Testing** antes de marcar la
  versión Android como disponible.
- iOS continúa con el número de build cronológico de TestFlight.
  `ios-testflight.yml` espera el procesamiento de App Store Connect y
  posteriormente registra la versión en el manifiesto. Se conserva copia en
  `/opt/barlytics/downloads/ios/last-release.json` para evitar que otro
  despliegue web elimine el aviso iOS.

## Actualizaciones por plataforma

| Plataforma | Distribución y acción |
|---|---|
| Windows | Diálogo; descarga EXE, verifica SHA256 e inicia Inno Setup |
| Linux | Diálogo; descarga DEB, verifica SHA256 y abre el instalador |
| macOS | Diálogo; descarga DMG, verifica SHA256 y lo abre |
| Android | Diálogo tras publicación en Google Play Internal Testing; abre Google Play |
| iOS | Diálogo tras procesamiento de TestFlight; abre enlace de TestFlight configurado |

Para iOS puede definirse Repository Variable
`BARLYTICS_IOS_TESTFLIGHT_URL` con el enlace específico de la beta.
Sin esa variable se utiliza la ficha oficial de TestFlight:
`https://apps.apple.com/app/testflight/id899247664`.
Eso abre TestFlight, pero el usuario debe estar autorizado como tester.

En dispositivos ya en producción estable, el enlace y número de versión
deberán corresponder a la publicación **App Store/Google Play de producción**,
no a versiones de pruebas internas. Estas ramas publican actualmente en canales
de pruebas, no en tiendas públicas.

## Detección

Se consulta el manifiesto HTTPS al entrar en la app, cada 30 minutos y al
volver del segundo plano. La comparación es
`version/build_instalado < version/build_publicado`.
El aviso opcional permite posponer esa misma versión 8 horas; una build nueva
utiliza otra clave de posposición.
En Flutter Web no existe instalador nativo; los cambios web se reciben al
recargar el sitio y la gestión de caché corresponde al navegador.

En **debug** la detección está desactivada por defecto. Para probarla en local:

```powershell
flutter run -d windows --dart-define=ENV=prod --dart-define=BARLYTICS_ENABLE_UPDATES=true --dart-define=BARLYTICS_APP_VERSION=0.9.0 --dart-define=BARLYTICS_APP_BUILD=1
```

## Verificación de QA

- `flutter test test/core/update/app_update_model_test.dart`
- `flutter analyze lib/core/update`
- `python3 -m unittest discover -s deploy/update -p 'test_*.py'`
- Comprobar el `latest.json` publicado: Windows/Linux/Android con misma
  versión/build del commit; macOS con versión y checksum del DMG publicado e
  iOS con build procesada en TestFlight.
- Instalar una versión anterior en cada plataforma y confirmar que se presenta
  el aviso. Verificar **Más tarde**, actualización correcta, versión igual y
  error temporal de red.
- Confirmar que el botón de actualización abre el instalador o tienda que
  corresponde y que nunca se anuncia un archivo no publicado.

**La revisión de código no equivale a una prueba E2E en dispositivos reales.**
No hacer merge hasta verificar CI y tener la autorización del responsable.
