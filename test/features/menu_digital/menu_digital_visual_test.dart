import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_catalog.dart';
import 'package:barlytics_frontend/features/menu_digital/presentation/widgets/menu_digital_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Las 32 paletas tienen colores HEX válidos y contraste legible', () {
    expect(menuDigitalPalettePresets.length, greaterThanOrEqualTo(32));
    expect(menuDigitalPalettePresets.map((p) => p.name).toSet().length,
        menuDigitalPalettePresets.length);
    final pattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    for (final preset in menuDigitalPalettePresets) {
      for (final hex in <String>[
        preset.primary, preset.background, preset.text, preset.card,
      ]) {
        expect(pattern.hasMatch(hex), isTrue, reason: preset.name);
      }
      final colors = MenuDigitalColors.fromMenu(<String, dynamic>{
        'primario': preset.primary,
        'fondo': preset.background,
        'texto': preset.text,
        'tarjeta': preset.card,
      });
      expect(MenuDigitalColors.contrast(colors.text, colors.canvas),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' fondo');
      expect(MenuDigitalColors.contrast(colors.text, colors.card),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' tarjeta');
      expect(MenuDigitalColors.contrast(colors.onAccent, colors.accent),
          greaterThanOrEqualTo(4.5), reason: preset.name + ' botón');
    }
  });

  test('Los controles públicos pueden usar los tonos configurados', () {
    final colors = MenuDigitalColors.fromMenu(<String, dynamic>{
      'primario': '#A87C3D', 'fondo': '#FFF9EF',
      'texto': '#302418', 'tarjeta': '#F2E5CB',
    });
    expect(colors.accent, const Color(0xFFA87C3D));
    expect(colors.canvas, const Color(0xFFFFF9EF));
    expect(colors.text, const Color(0xFF302418));
    expect(colors.card, const Color(0xFFF2E5CB));
  });

  testWidgets('Portada completa, logo y carrusel conservan las fotos enteras',
      (tester) async {
    tester.view.physicalSize = const Size(1040, 1450);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const picture = 'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91Jpz'
        'AAAAFklEQVR4nGM8WGnHwMDAxMDAwMDAAAASTQF8cCGfAgAAAABJRU5ErkJggg==';
    final data = <String, dynamic>{
      'titulo': 'Carta de prueba',
      'sucursal': 'Negocio con logo',
      'logo': picture,
      'portada': picture,
      'portadaModo': 'COMPLETA',
      'fondoImagen': picture,
      'galeria': <String>[picture, picture],
      'galeriaArriba': true,
      'estilo': 'LIBRO',
      'productos': [
        {'id': 1, 'nombre': 'Producto', 'tipo': 'BEBIDA', 'precio': 3000},
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: MenuDigitalCatalog(menu: data, preview: true),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Negocio con logo'), findsOneWidget);
    expect(find.text('Ver foto completa'), findsOneWidget);
    expect(find.text('Conoce nuestro lugar'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Siguiente foto de portada'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('Ver foto completa'));
    await tester.pumpAndSettle();
    expect(find.text('Fotografía 2 de 3'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('Conservar encabezado dividido clásico sigue siendo posible',
      (tester) async {
    const picture = 'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91Jpz'
        'AAAAFklEQVR4nGM8WGnHwMDAxMDAwMDAAAASTQF8cCGfAgAAAABJRU5ErkJggg==';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: MenuDigitalCatalog(menu: {
          'titulo': 'Nuestra carta',
          'sucursal': 'Sucursal con imagen',
          'logo': picture,
          'portada': picture,
          'portadaModo': 'DIVIDIDA',
          'estilo': 'TIENDA',
          'productos': const [],
        }, preview: true),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nuestra carta'), findsOneWidget);
    expect(find.text('Sucursal con imagen'), findsOneWidget);
    expect(find.text('Ver foto completa'), findsNothing);
  });

  testWidgets('Los cinco diseños muestran productos en la vista previa',
      (tester) async {
    final menu = <String, dynamic>{
      'titulo': 'Nuestra carta',
      'sucursal': 'Sucursal demo',
      'estilo': 'TIENDA',
      'productos': [
        {'id': 1, 'nombre': 'Producto demo', 'tipo': 'BEBIDA', 'precio': 1200},
      ],
    };
    Future<void> render() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: SingleChildScrollView(
          child: MenuDigitalCatalog(menu: menu, preview: true),
        ),
      )));
      await tester.pumpAndSettle();
    }
    for (final style in const <String>[
      'TIENDA', 'LIBRO', 'EDITORIAL', 'GALERIA', 'MINIMALISTA',
    ]) {
      menu['estilo'] = style;
      await render();
      expect(find.text('VISTA PREVIA · ' +
          (style == 'TIENDA' ? 'MODERNO' : style)), findsOneWidget);
      expect(find.text('Producto demo'), findsWidgets,
          reason: 'Falta el producto en $style');
    }
  });

  testWidgets('Todos los tipos de producto son accesibles en web angosta',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final tipos = <String>[
      'AGUARDIENTE', 'BEBIDA', 'WHISKY', 'CERVEZA', 'CIGARRILLO',
      'PASABOCAS', 'RON', 'COCTEL', 'VODKA', 'SIN ALCOHOL',
    ];
    final productos = <Map<String, dynamic>>[
      for (var i = 0; i < tipos.length; i++)
        <String, dynamic>{
          'id': i + 1,
          'tipo': tipos[i],
          'nombre': 'Producto ${tipos[i]}',
          'descripcion': 'Prueba de categoría',
          'precio': 1200,
        },
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: MenuDigitalCatalog(menu: <String, dynamic>{
        'titulo': 'Nuestra carta',
        'sucursal': 'Sucursal de prueba',
        'estilo': 'LIBRO',
        'productos': productos,
        'primario': '#A87C3D',
        'fondo': '#FFF9EF',
        'texto': '#302418',
        'tarjeta': '#F2E5CB',
      }),
    )));
    await tester.pumpAndSettle();

    // En libro cada tipo es una hoja: las diez categorías quedan visibles
    // sin desplazamiento horizontal, con su propio botón seleccionado.
    expect(find.byType(ChoiceChip), findsNWidgets(tipos.length));
    expect(find.text('Tipos de productos'), findsOneWidget);
    expect(find.text('SIN ALCOHOL'), findsOneWidget);
    await tester.ensureVisible(find.text('SIN ALCOHOL'));
    await tester.tap(find.text('SIN ALCOHOL'));
    await tester.pumpAndSettle();
    expect(find.text('Producto SIN ALCOHOL'), findsWidgets);
  });

  testWidgets('Pasar hoja también selecciona su categoría',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SizedBox(height: 820, child: MenuDigitalCatalog(menu: {
        'estilo': 'LIBRO',
        'titulo': 'Carta de ejemplo',
        'sucursal': 'Sucursal',
        'productos': [
          {'id': 1, 'nombre': 'Producto A', 'tipo': 'AGUARDIENTE', 'precio': 2000},
          {'id': 2, 'nombre': 'Producto B', 'tipo': 'BEBIDA', 'precio': 3000},
          {'id': 3, 'nombre': 'Producto C', 'tipo': 'WHISKY', 'precio': 4000},
        ],
      })),
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'AGUARDIENTE')).selected, isTrue);
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'BEBIDA')).selected, isTrue);
    expect(find.text('Producto B'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'WHISKY'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'WHISKY')).selected, isTrue);
    expect(find.text('Producto C'), findsWidgets);
  });

  testWidgets('Pulsar la imagen muestra la descripción y el precio',
      (tester) async {
    final product = <String, dynamic>{
      'id': 1,
      'nombre': 'Producto de prueba',
      'descripcion': 'Descripción especial de este producto',
      'tipo': 'CERVEZA',
      'precio': 5000,
      'imagen': 'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91Jpz'
          'AAAAFklEQVR4nGM8WGnHwMDAxMDAwMDAAAASTQF8cCGfAgAAAABJRU5ErkJggg==',
    };
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 460,
        height: 800,
        child: MenuDigitalCatalog(menu: <String, dynamic>{
          'titulo': 'Nuestra carta',
          'sucursal': 'Sucursal de prueba',
          'estilo': 'LIBRO',
          'productos': [product],
          'primario': '#A87C3D',
          'fondo': '#FFF9EF',
          'texto': '#302418',
          'tarjeta': '#F2E5CB',
        }),
      )),
    ));
    await tester.pumpAndSettle();
    final thumbnail = find.bySemanticsLabel(
        'Ampliar imagen y descripción de Producto de prueba');
    await tester.ensureVisible(thumbnail.first);
    await tester.tap(thumbnail.first);
    await tester.pumpAndSettle();
    expect(find.text('DETALLES DEL PRODUCTO'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Descripción especial de este producto'), findsWidgets);
    expect(find.textContaining('5.000'), findsWidgets);
    semantics.dispose();
  });
}
