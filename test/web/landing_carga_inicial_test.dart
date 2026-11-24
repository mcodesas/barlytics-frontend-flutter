import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El splash tiene logo prioritario y marca visible sin esperar red', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('fetchpriority="high"'));
    expect(html, contains('loading="eager"'));
    expect(html, contains('barlytics-loader__fallback'));
    expect(html, contains('Gestión inteligente para tu negocio'));
    expect(html, contains('barlytics-loader__brand--loaded'));
    expect(html, contains('branding/barlytics-logo-light.png'));
  });

  test('La fuente externa no debe bloquear la primera pintura', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('rel="stylesheet" media="print"'));
    expect(html, contains("onload=\"this.media='all'\""));
  });

  test('No precarga los 18 videos de la demo Flutter al abrir inicio', () {
    final code = File('lib/features/public/presentation/widgets/public_product_demo.dart')
        .readAsStringSync();
    expect(code, isNot(contains('_preloadDemoVideos()')));
    expect(code, isNot(contains('_preloadControllers')));
    // El reproductor del módulo visible continúa operativo.
    expect(code, contains('VideoPlayerController.networkUrl'));
  });

  test('El sitio estático no precarga 36 videos sin interacción', () {
    final code = File('web/public-site/public.js').readAsStringSync();
    expect(code, isNot(contains('preloadDemoVideos()')));
    expect(code, isNot(contains('video.preload = \'auto\'')));
  });
}
