import 'package:flutter/material.dart';

import 'menu_digital_palette.dart';

/// Vista decorativa de los estilos del menú digital.
/// El lienzo lógico es fijo y se escala al tamaño de cada tarjeta para evitar
/// RenderFlex overflow en pantallas estrechas o con fuentes del sistema grandes.
class MenuDigitalDesignThumbnail extends StatelessWidget {
  const MenuDigitalDesignThumbnail({
    super.key,
    required this.colors,
    required this.style,
  });

  final MenuDigitalColors colors;
  final String style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: 280,
            height: 156,
            child: _designThumbnail(colors, style),
          ),
        ),
      ),
    );
  }

  Widget _designThumbnail(MenuDigitalColors colors, String style) {
    final fg = colors.text;
    final ac = colors.accent;
    Widget line({double width = 40, double height = 5, Color? color}) =>
        Container(width: width, height: height, decoration: BoxDecoration(
          color: color ?? fg.withOpacity(.6),
          borderRadius: BorderRadius.circular(3)));
    Widget photo() => Container(
      decoration: BoxDecoration(color: colors.secondarySurface,
        borderRadius: BorderRadius.circular(6)),
      child: Center(child: Icon(Icons.image_outlined,
        color: fg.withOpacity(.65), size: 20)));
    Widget paper() => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: colors.card,
        borderRadius: BorderRadius.circular(7)),
      child: Column(children: [
        line(width: 52, height: 7, color: ac),
        const Spacer(),
        for (var i = 0; i < 3; i++) ...[
          Row(children: [
            Expanded(child: Container(height: 4,
              color: fg.withOpacity(.4))),
            const SizedBox(width: 6),
            line(width: 20, color: ac),
          ]),
          const SizedBox(height: 6),
        ],
        const Spacer(),
      ]),
    );
    switch (style) {
      case 'DOCUMENTO':
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 115),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFCF6),
              border: Border.all(color: const Color(0xFFE4DCD0)),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(.1), blurRadius: 4)]),
            child: Column(children: [
              const Text('CARTA', style: TextStyle(
                color: Color(0xFF293632), fontSize: 10,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 5),
              Container(height: 1, color: const Color(0xFF917B55)),
              const SizedBox(height: 7),
              for (var i = 0; i < 4; i++) ...[
                Row(children: [
                  Expanded(child: Container(height: 3,
                    color: const Color(0xFF716B62))),
                  const SizedBox(width: 9),
                  Container(width: 18, height: 3,
                    color: const Color(0xFF716B62)),
                ]),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              const Text('MENÚ', style: TextStyle(
                color: Color(0xFF746F63), fontSize: 7)),
            ]),
          ),
        ));
      case 'ELEGANTE':
        return Container(
          color: const Color(0xFF171C20),
          padding: const EdgeInsets.all(13),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond_outlined,
                color: Color(0xFFE3C48B), size: 17),
              const SizedBox(height: 6),
              const Text('ALTA COCINA', style: TextStyle(
                color: Color(0xFFE3C48B), letterSpacing: 2, fontSize: 8)),
              const SizedBox(height: 6),
              const Text('Nuestra selección', style: TextStyle(
                color: Color(0xFFF8F1E6), fontFamily: 'Georgia',
                fontSize: 14)),
              const SizedBox(height: 10),
              Container(height: 1, width: 70,
                color: const Color(0xFFE3C48B)),
              const SizedBox(height: 10),
              const Text('Plato de la casa', style: TextStyle(
                color: Color(0xFFF8F1E6), fontSize: 10)),
              const SizedBox(height: 4),
              const Text(r'$ 38.000', style: TextStyle(
                color: Color(0xFFE3C48B), fontSize: 9)),
            ]),
        );
      case 'TIENDA_WEB':
        return Row(children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: colors.card,
                borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Expanded(child: photo()),
                const SizedBox(height: 7),
                line(width: 67, height: 6, color: fg),
                const SizedBox(height: 5),
                line(width: 35, height: 7, color: ac),
                const SizedBox(height: 7),
                Container(height: 14,
                  decoration: BoxDecoration(color: ac,
                    borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text('VER DETALLES',
                    style: TextStyle(color: colors.onAccent,
                      fontSize: 6, fontWeight: FontWeight.w900)))),
              ]),
            )),
            if (i == 0) const SizedBox(width: 7),
          ],
        ]);
      case 'BISTRO':
        return Container(
          color: const Color(0xFFFAF6EE),
          padding: const EdgeInsets.all(11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bistro & café',
              style: TextStyle(color: Color(0xFF2E2923),
                fontFamily: 'Georgia', fontSize: 13,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < 2; i++) ...[
              Expanded(child: Row(children: [
                Container(width: 45, decoration: BoxDecoration(
                  color: const Color(0xFFD9C8AD),
                  borderRadius: BorderRadius.circular(5)),
                  child: const Center(child: Icon(Icons.restaurant_menu,
                    color: Color(0xFF85512E), size: 18))),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 5, width: 80,
                      color: const Color(0xFF2E2923)),
                    const SizedBox(height: 6),
                    Container(height: 4, width: 40,
                      color: const Color(0xFF85512E)),
                  ])),
              ])),
              if (i == 0) const SizedBox(height: 6),
            ],
          ]),
        );
      case 'NOCTURNO':
        return Container(
          color: const Color(0xFF101820),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NIGHT MENU', style: TextStyle(
              color: Color(0xFF71E4DA), fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 10),
            for (var i = 0; i < 2; i++) ...[
              Expanded(child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2830),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF407E7A))),
                child: Row(children: [
                  Container(width: 42, color: const Color(0xFF35494D),
                    child: const Icon(Icons.local_bar_rounded,
                      color: Color(0xFF71E4DA), size: 19)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 5, color: Colors.white),
                    const SizedBox(height: 7),
                    Container(height: 5, width: 35,
                      color: const Color(0xFF71E4DA)),
                  ])),
                ]),
              )),
              if (i == 0) const SizedBox(height: 7),
            ],
          ]),
        );
      case 'LIBRO':
        return Row(children: [
          Expanded(child: paper()),
          const SizedBox(width: 6),
          Expanded(child: paper()),
        ]);
      case 'EDITORIAL':
        return Container(
          padding: const EdgeInsets.all(12), color: colors.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            line(width: 110, height: 12, color: fg),
            const SizedBox(height: 8),
            Container(height: 1, color: ac),
            const Spacer(),
            for (var i = 0; i < 2; i++) ...[
              Row(children: [
                Expanded(child: Container(height: 5,
                  color: fg.withOpacity(.5))),
                const SizedBox(width: 12),
                line(width: 38, height: 7, color: ac),
              ]),
              const SizedBox(height: 8),
            ],
            const Spacer(),
          ]),
        );
      case 'GALERIA':
        return Row(children: [
          Expanded(flex: 3, child: photo()),
          const SizedBox(width: 7),
          Expanded(flex: 2, child: Column(children: [
            Expanded(child: photo()),
            const SizedBox(height: 7),
            Expanded(child: photo()),
          ])),
        ]);
      case 'MINIMALISTA':
        return Container(
          padding: const EdgeInsets.all(12), color: colors.card,
          child: Column(children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: Row(children: [
                Icon(Icons.circle, color: ac, size: 6),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 5,
                  color: fg.withOpacity(.55))),
                const SizedBox(width: 11),
                line(width: 35, height: 7, color: ac),
              ])),
          ]),
        );
      default:
        return Row(children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: colors.card,
                borderRadius: BorderRadius.circular(7)),
              child: Column(children: [
                Expanded(child: photo()),
                const SizedBox(height: 6),
                line(width: 64),
                const SizedBox(height: 5),
                line(width: 42, height: 8, color: ac),
              ]),
            )),
            if (i == 0) const SizedBox(width: 8),
          ],
        ]);
    }
  }

}
