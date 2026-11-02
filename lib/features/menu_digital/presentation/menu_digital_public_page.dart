import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/menu_digital_api.dart';
import 'widgets/menu_digital_catalog.dart';

/// La ruta /carta/:slug es pública: no exige JWT ni suscripción del visitante.
class MenuDigitalPublicPage extends ConsumerStatefulWidget {
  const MenuDigitalPublicPage({super.key, required this.slug});
  final String slug;

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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de la carta copiado.')));
  }

  Future<void> _whatsapp() async {
    final link = (_menu?['enlaceCompartir'] ?? _menu?['url'] ?? '').toString();
    if (!link.startsWith('https://')) return;
    final uri = Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(
      'Conoce nuestra carta digital:\n' + link));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final data = _menu;
    if (_loading || data == null) {
      const bg = Color(0xFF081B27);
      return Scaffold(backgroundColor: bg,
        body: Center(child: ConstrainedBox(
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
        )));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Positioned.fill(child: MenuDigitalCatalog(menu: data)),
        Positioned(right: 16, bottom: 20, child: SafeArea(child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'menu_copy', tooltip: 'Copiar enlace del menú',
              onPressed: _share,
              child: const Icon(Icons.link_rounded)),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'menu_whatsapp',
              tooltip: 'Compartir el menú por WhatsApp',
              onPressed: _whatsapp,
              child: const Icon(Icons.share_rounded)),
          ]),
        )),
      ]),
    );
  }
}
