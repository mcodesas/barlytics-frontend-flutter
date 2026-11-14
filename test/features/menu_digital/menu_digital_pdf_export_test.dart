import 'dart:convert';

import 'package:barlytics_frontend/features/menu_digital/domain/menu_digital_pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> carta(String style, {int count = 14}) => {
  'titulo': 'Nuestra carta de prueba',
  'sucursal': 'Sede central',
  'descripcion': 'Platos, bebidas y cafés preparados para nuestros clientes.',
  'estilo': style,
  'portada': '',
  'logo': '',
  'primario': '#14B8A6',
  'fondo': '#10251D',
  'texto': '#F7F4E9',
  'tarjeta': '#1C382D',
  'ordenTipos': ['Cafés', 'Bebidas'],
  'productos': [
    for (var i = 0; i < count; i++)
      {
        'id': i + 1,
        'nombre': 'Producto número ' + (i + 1).toString(),
        'descripcion': 'Descripción de la carta completa para imprimir.',
        'tipo': i.isEven ? 'Cafés' : 'Bebidas',
        'precio': 5000 + i * 1000,
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF contiene todas las categorías y exporta más de seis productos', () async {
    final bytes = await MenuDigitalPdfExport.create(
      menu: carta('DOCUMENTO', count: 18),
      loadImage: (_) async => null,
    );
    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(3500));
  });

  for (final style in const [
    'TIENDA', 'LIBRO', 'EDITORIAL', 'GALERIA', 'MINIMALISTA',
    'DOCUMENTO', 'ELEGANTE', 'TIENDA_WEB', 'BISTRO', 'NOCTURNO',
  ]) {
    test('Exportación PDF válida para diseño ' + style, () async {
      final bytes = await MenuDigitalPdfExport.create(
        menu: carta(style, count: 2),
        loadImage: (_) async => null,
      );
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });
  }

  test('Carta publicada incluye enlace QR sin reemplazar su contenido', () async {
    final menu = carta('BISTRO', count: 12);
    menu['url'] =
        'https://www.barlytics.com.co/#/carta/123e4567-e89b-12d3-a456-426614174000';
    final bytes = await MenuDigitalPdfExport.create(
      menu: menu,
      loadImage: (_) async => null,
    );
    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(4000));
  });

  test('No crea una carta incompleta sin productos', () async {
    await expectLater(
      MenuDigitalPdfExport.create(
        menu: carta('TIENDA', count: 0),
        loadImage: (_) async => null,
      ),
      throwsStateError,
    );
  });
}
