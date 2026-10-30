import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('La portada HTML muestra el logo de sucursal, no el SaaS, al cargar un evento', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('class="barlytics-loader__event-logo"'));
    expect(html, contains('class="barlytics-loader__event-venue"'));
    expect(html, contains('src="event-loader.js"'));
    expect(html, contains("barlytics-event-ready"));
    expect(html, contains("barlytics-event-brand-ready"));
    // El splash de BarLytics continúa para login y otras pantallas.
    expect(html, contains('class="barlytics-loader__logo"'));
    expect(html, contains("window.addEventListener('flutter-first-frame'"));
  });

  test('La portada de eventos obtiene los colores y el logo del API publicado', () {
    final js = File('web/event-loader.js').readAsStringSync();
    expect(js, contains("/api/v1/eventos/public/"));
    expect(js, contains('data.colorFondo'));
    expect(js, contains('data.colorPrimario'));
    expect(js, contains('data.fotoSucursal'));
    expect(js, contains('data.logo'));
    expect(js, contains('data.sucursal'));
    expect(js, contains('data.titulo'));
    expect(js, contains("loader.classList.add('barlytics-loader--event')"));
    expect(js, contains("dispatchEvent(new Event('barlytics-event-brand-ready'))"));
    // Las entradas QR privadas no se confunden con la ruta de un evento.
    expect(js, contains('const match = /^\\/evento\\/'));
  });
}
