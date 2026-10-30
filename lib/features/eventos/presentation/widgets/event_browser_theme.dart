import 'package:flutter/material.dart';
import 'event_browser_theme_bridge_stub.dart'
  if (dart.library.html) 'event_browser_theme_bridge_web.dart' as browser;

/// Color real del fondo de la paleta, sin depender del color corporativo.
String eventBrowserThemeHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Mantiene el color del navegador sincronizado con la página pública.
/// Restaura el tema anterior cuando se cierra una entrada o se sale del evento.
/// En web el navegador puede ignorar theme-color en su interfaz nativa.
class EventBrowserThemeScope extends StatefulWidget {
  const EventBrowserThemeScope({
    super.key,
    required this.background,
    required this.child,
  });

  final Color background;
  final Widget child;

  @override
  State<EventBrowserThemeScope> createState() => _EventBrowserThemeScopeState();
}

class _EventBrowserThemeScopeState extends State<EventBrowserThemeScope> {
  @override
  void initState() {
    super.initState();
    _applyTheme();
  }

  @override
  void didUpdateWidget(covariant EventBrowserThemeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.background != widget.background) _applyTheme();
  }

  void _applyTheme() =>
      browser.setEventBrowserTheme(this, eventBrowserThemeHex(widget.background));

  @override
  void dispose() {
    browser.clearEventBrowserTheme(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
