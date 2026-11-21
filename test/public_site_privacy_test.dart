import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Las páginas de privacidad tienen rutas públicas indexables', () {
    final policy = source('web/privacidad/index.html');
    final options = source('web/opciones-de-privacidad/index.html');
    final sitemap = source('web/sitemap.xml');
    final robots = source('web/robots.txt');
    final nginx = source('deploy/nginx.conf');
    final publicJs = source('web/public-site/public.js');

    expect(policy, contains('<meta name="robots" content="index,follow'));
    expect(options, contains('<meta name="robots" content="index,follow'));
    expect(policy, contains('rel="canonical" href="https://barlytics.com.co/privacidad/"'));
    expect(options, contains('rel="canonical" href="https://barlytics.com.co/opciones-de-privacidad/"'));
    expect(options, contains('type="application/ld+json"'));
    expect(sitemap, contains('https://barlytics.com.co/privacidad/'));
    expect(sitemap, contains('https://barlytics.com.co/opciones-de-privacidad/'));
    expect(robots, contains('Sitemap: https://barlytics.com.co/sitemap.xml'));
    expect(nginx, contains('opciones-de-privacidad'));
    expect(publicJs, contains("'/opciones-de-privacidad/'"));
  });

  test('Todas las variantes del pie de página enlazan las páginas legales', () {
    final footer = source('web/public-site/footer.html');
    final alternateFooter = source('web/public-shell.js');
    final landingFooter =
        source('lib/features/public/presentation/pages/public_landing_page.dart');

    for (final route in ['/privacidad/', '/opciones-de-privacidad/', '/terminos/']) {
      expect(footer, contains(route));
      expect(alternateFooter, contains(route));
      expect(landingFooter, contains(route));
    }
  });

  test('Las opciones de privacidad ofrecen solicitudes claras y seguras', () {
    final options = source('web/opciones-de-privacidad/index.html');
    final policy = source('web/privacidad/index.html');

    for (final anchor in [
      'id="consultar"',
      'id="rectificar"',
      'id="eliminar"',
      'id="autorizacion"',
      'id="procedimiento"',
      'id="contacto"',
    ]) {
      expect(options, contains(anchor));
    }
    expect(options, contains('mailto:soporte@barlytics.com.co?subject='));
    expect(options, contains('No se eliminarán datos ni se modificarán autorizaciones con solo hacer clic.'));
    expect(policy, contains('href="/opciones-de-privacidad/"'));
  });
}
