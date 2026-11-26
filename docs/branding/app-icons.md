# Iconos de aplicación BarLytics

Se conserva el arte original en `assets/branding/barlytics_app_icon_1024.png` y los logotipos de la interfaz. El símbolo se reduce un 20 % respecto al lienzo original y se centra en el fondo azul oscuro (#061723). Las esquinas externas se adaptan a cada plataforma; el icono web maskable usa un margen mayor para evitar recortes.

## Compilaciones locales
- Android, Windows, Linux, macOS y web: `python -m pip install Pillow==11.3.0` y `python scripts/branding/generate-app-icons.py --platform all` antes de compilar.
- iOS: en macOS, `bash scripts/ios/generate-app-icons.sh` antes de compilar. Fastlane ya lo ejecuta automáticamente y comprueba tamaños y ausencia de transparencia.

Los workflows de producción regeneran los recursos desde el original antes de compilar; no se redibuja ni se modifica el logo de marca. La generación verifica dimensiones y formatos PNG/ICO.
