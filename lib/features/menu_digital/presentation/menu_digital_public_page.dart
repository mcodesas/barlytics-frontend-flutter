import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/menu_digital_api.dart';
import 'widgets/menu_digital_catalog.dart';
import 'widgets/menu_digital_palette.dart';

/// La ruta /carta/:slug es pública: no exige JWT ni suscripción del visitante.
class MenuDigitalPublicPage extends ConsumerStatefulWidget {
  const MenuDigitalPublicPage({
    super.key,
    required this.slug,
    this.internalPreview = false,
  });
  final String slug;
  /// True únicamente al entrar desde «Ver como cliente» en BarLytics.
  /// La carta compartida mediante enlace/QR mantiene su aspecto público.
  final bool internalPreview;

  @override
  ConsumerState<MenuDigitalPublicPage> createState() => _MenuDigitalPublicPageState();
}

class _MenuDigitalPublicPageState extends ConsumerState<MenuDigitalPublicPage> {
  Map<String, dynamic>? _menu;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(menuDigitalApiProvider).publico(widget.slug);
      if (!mounted) return;
      setState(() { _loading = false; _menu = result; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Esta carta no está disponible. Puede que aún no esté publicada.';
      });
    }
  }

  Future<void> _share() async {
    final link = (_menu?['enlaceCompartir'] ?? _menu?['url'] ?? '').toString();
    if (!link.startsWith('https://')) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      final colors = MenuDigitalColors.fromMenu(_menu ?? {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: colors.accent,
        content: Text('Enlace de la carta copiado.',
          style: TextStyle(color: colors.onAccent)),
      ));
    }
  }

  Future<void> _whatsapp() async {
    final link = (_menu?['enlaceCompartir'] ?? _menu?['url'] ?? '').toString();
    if (!link.startsWith('https://')) return;
    final uri = Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(
      'Conoce nuestra carta digital:\n' + link));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _backToAdministration() {
    // En móvil y escritorio, push() conserva la página anterior.
    // En caso de recargar la vista web o abrir su enlace interno directamente,
    // GoRouter puede perder el historial: regresar al editor explícitamente.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/menu_digital');
    }
  }

  Widget _backButton() => Positioned(
    top: 0,
    left: 0,
    child: SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: const Color(0xF2122934),
        borderRadius: BorderRadius.circular(16),
        elevation: 5,
        child: TextButton.icon(
          onPressed: _backToAdministration,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
          label: const Text('Volver a BarLytics',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = _menu;
    if (_loading || data == null) {
      const bg = Color(0xFF081B27);
      return Scaffold(backgroundColor: bg,
        body: Stack(children: [
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(padding: const EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_error == null ? Icons.menu_book_rounded : Icons.sentiment_dissatisfied_outlined,
                  color: const Color(0xFF20C8C4), size: 51),
                const SizedBox(height: 18),
                Text(_error ?? 'Preparando nuestra carta...',
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (_error == null)
                  const CircularProgressIndicator(color: Color(0xFF20C8C4))
                else
                  OutlinedButton.icon(onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar')),
              ]),
            ),
          )),
          if (widget.internalPreview) _backButton(),
        ]));
    }
    final colors = MenuDigitalColors.fromMenu(data);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(children: [
        Positioned.fill(child: MenuDigitalCatalog(menu: data)),
        // Visible sobre todos los diseños de carta, incluidos libro/tienda,
        // sin contaminar el enlace público enviado a los clientes.
        if (widget.internalPreview) _backButton(),
        Positioned(right: 16, bottom: 20, child: SafeArea(child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'menu_copy',
              tooltip: 'Copiar enlace del menú',
              backgroundColor: colors.card,
              foregroundColor: colors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
                side: BorderSide(color: colors.border)),
              onPressed: _share,
              child: const Icon(Icons.link_rounded)),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'menu_whatsapp',
              tooltip: 'Compartir el menú por WhatsApp',
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
              onPressed: _whatsapp,
              child: const Icon(Icons.share_rounded)),
          ]),
        )),
      ]),
    );
  }
}
