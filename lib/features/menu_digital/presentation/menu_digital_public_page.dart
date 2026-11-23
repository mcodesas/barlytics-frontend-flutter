import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/menu_digital_api.dart';
import 'widgets/menu_digital_catalog.dart';
import 'widgets/menu_digital_palette.dart';

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
  bool _reportBusy = false;

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

  Future<void> _reportContent() async {
    if (_reportBusy) return;
    String selected = 'INAPROPIADO';
    String details = '';
    final report = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: const Text('Reportar contenido de la carta'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Puedes reportar contenido ofensivo, engañoso o '
                    'inapropiado. Lo revisará el equipo de BarLytics.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Motivo'),
                    items: const [
                      DropdownMenuItem(value: 'INAPROPIADO',
                          child: Text('Contenido inapropiado')),
                      DropdownMenuItem(value: 'OFENSIVO',
                          child: Text('Contenido ofensivo')),
                      DropdownMenuItem(value: 'ENGANOSO',
                          child: Text('Contenido engañoso')),
                      DropdownMenuItem(value: 'OTRO',
                          child: Text('Otro motivo')),
                    ],
                    onChanged: (value) => refresh(() => selected = value ?? 'INAPROPIADO'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Describe brevemente el contenido que deseas reportar',
                    ),
                    onChanged: (text) => details = text,
                  ),
                  const Text(
                    'No incluyas información personal. '
                    'Tu reporte no se mostrará públicamente.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, <String, String>{
                'motivo': selected, 'detalles': details,
              }),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
    if (report == null || !mounted) return;
    setState(() => _reportBusy = true);
    try {
      await ref.read(menuDigitalApiProvider).reportarContenido(
        widget.slug,
        report['motivo'] ?? 'OTRO',
        report['detalles'] ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte recibido. Revisaremos el contenido.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el reporte: $error')),
      );
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
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
    final colors = MenuDigitalColors.fromMenu(data);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(children: [
        Positioned.fill(child: MenuDigitalCatalog(menu: data)),
        Positioned(right: 16, bottom: 20, child: SafeArea(child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'menu_report',
              tooltip: 'Reportar contenido inapropiado',
              backgroundColor: colors.card,
              foregroundColor: colors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
                side: BorderSide(color: colors.border)),
              onPressed: _reportBusy ? null : _reportContent,
              child: const Icon(Icons.flag_outlined)),
            const SizedBox(height: 10),
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
