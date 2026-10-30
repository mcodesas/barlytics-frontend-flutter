// ignore_for_file: deprecated_member_use
import 'dart:collection';
import 'dart:math' as math;
import 'dart:html' as html;

/// El último scope activo corresponde a la página pública visible.
/// Al salir del evento se recupera el fondo anterior o el de BarLytics.
final Map<Object, String> _activeThemes = LinkedHashMap<Object, String>.identity();
const _defaultTheme = '#061723';

void setEventBrowserTheme(Object owner, String hex) {
  _activeThemes[owner] = hex;
  _renderTheme();
}

void clearEventBrowserTheme(Object owner) {
  _activeThemes.remove(owner);
  _renderTheme();
}

void _renderTheme() {
  final hex = _activeThemes.isEmpty ? _defaultTheme : _activeThemes.values.last;
  final number = int.tryParse(hex.substring(1), radix: 16) ?? 0x061723;
  final r = ((number >> 16) & 255) / 255.0;
  final g = ((number >> 8) & 255) / 255.0;
  final b = (number & 255) / 255.0;
  double channel(double v) => v <= .04045 ? v / 12.92 :
    math.pow((v + .055) / 1.055, 2.4).toDouble();
  final luminance = .2126 * channel(r) + .7152 * channel(g) + .0722 * channel(b);
  final scheme = luminance > .38 ? 'light' : 'dark';

  // Se actualizan ambos meta theme-color (claro y oscuro).
  for (final meta in html.document.querySelectorAll('meta[name="theme-color"]')) {
    meta.setAttribute('content', hex);
  }
  html.document.querySelector('meta[name="msapplication-navbutton-color"]')
    ?.setAttribute('content', hex);
  html.document.querySelector('meta[name="color-scheme"]')
    ?.setAttribute('content', scheme);
  html.document.querySelector('meta[name="supported-color-schemes"]')
    ?.setAttribute('content', scheme);

  // Apple PWA únicamente admite estilos predefinidos, no valores hex.
  html.document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]')
    ?.setAttribute('content', scheme == 'light' ? 'default' : 'black-translucent');

  // index.html usa !important, así que igualamos esa prioridad.
  html.document.documentElement?.style
    .setProperty('background-color', hex, 'important');
  html.document.body?.style.setProperty('background-color', hex, 'important');
  html.document.documentElement?.style.setProperty('color-scheme', scheme);
  html.document.body?.style.setProperty('color-scheme', scheme);
}
