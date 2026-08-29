# Identidad visual oficial de BarLytics

La marca oficial de BarLytics usa el isotipo **B + copa + barras de analítica** en gradiente turquesa/cian y el lema **“Gestión inteligente para tu negocio”**.

## Regla de contraste

Los logos usados dentro de la interfaz tienen **fondo realmente transparente**. No se deben exportar con rectángulos azul oscuro, blanco o negro horneados dentro de la imagen.

- **Superficie oscura:** usar `barlytics_logo_light.png` (texto “Bar” claro).
- **Superficie clara:** usar `barlytics_logo_dark.png` (texto “Bar” azul oscuro).
- **Espacios compactos:** usar `barlytics_mark_trim.png`, que conserva el gradiente de la B y también es transparente.

Esta selección está centralizada en `lib/core/widgets/barlytics_brand.dart` para evitar que cada pantalla escoja una imagen diferente.

## Resolución maestra

- Lockups horizontales: **1920 px de ancho** y transparencia real.
- Isotipo maestro: **2048 x 2048 px** con transparencia real.
- Icono funcional: **1024 x 1024 px**, derivado del isotipo maestro.
- Los tamaños específicos de Android, macOS, Web/PWA y favicon se generan a partir de estas fuentes de alta resolución.

## Integración

- Flutter: `BarLyticsBrandLockup` selecciona automáticamente el logo claro u oscuro según la superficie.
- Login y sitio público: usan el lockup horizontal transparente.
- Menú lateral y espacios compactos: usan la B transparente sin cuadro de fondo dentro del PNG.
- Web: el loader inicial usa CSS para el fondo y coloca encima el PNG transparente; no usa una imagen de splash con fondo incrustado.
- Android: el splash usa un color de fondo nativo y el isotipo transparente centrado.
- Android, macOS, favicon y PWA: los iconos se derivan del isotipo de alta resolución.

No se debe volver a representar la marca mediante `Icons.local_bar`, `Icons.analytics` u otros iconos genéricos en lugares destinados a identidad corporativa.

## Regla del logotipo

El isotipo de la **B** (copa + analítica) funciona como la primera letra del nombre.
Por eso el lockup horizontal se construye como **[B gráfica] + arLytics**. Nunca se debe mostrar **[B gráfica] + BarLytics**, porque duplicaría la B visualmente.

- Fondos oscuros: `ar` claro y `Lytics` en gradiente cian/azul.
- Fondos claros: `ar` azul marino y `Lytics` en gradiente cian/azul.
- Navbar, login, hero, registro, activación y footer usan el lockup compacto sin lema.
- Splash y piezas corporativas pueden usar la versión completa con el lema “Gestión inteligente para tu negocio”.
- Iconos de app, favicon y menú colapsado usan solamente la B gráfica.
