import 'dart:convert';
import 'package:flutter/material.dart';

/// Paleta única del editor y de la experiencia pública de Eventos.
abstract final class EventColors {
  static const background = Color(0xFF061925);
  static const surface = Color(0xFF0C2939);
  static const surfaceLight = Color(0xFF12394A);
  static const border = Color(0xFF245264);
  static const primary = Color(0xFF23D8D1);
  static const onPrimary = Color(0xFF04232D);
  static const text = Color(0xFFF2FBFF);
  static const muted = Color(0xFFA9C2CE);
  static const gold = Color(0xFFFFCC8E);
  static const success = Color(0xFF58DCB1);
  static const warning = Color(0xFFFFB96B);
}

/// Combinaciones curadas: se pueden aplicar completas o mezclar sus colores.
class EventPalettePreset {
  const EventPalettePreset(this.name,this.accent,this.background,this.description);
  final String name,accent,background,description;
}

const eventPalettePresets=<EventPalettePreset>[
  EventPalettePreset('Nocturno turquesa','#35D0C5','#102735','Fresco y sofisticado'),
  EventPalettePreset('Champán elegante','#E6BE83','#29221E','Cálido y premium'),
  EventPalettePreset('Cobre & carbón','#EBA374','#292026','Gastronomía y noche'),
  EventPalettePreset('Esmeralda','#8DDBB5','#14362F','Natural y refinado'),
  EventPalettePreset('Rosa ópalo','#FFACCB','#362435','Moderno y delicado'),
  EventPalettePreset('Azul imperial','#8BACFF','#1A2947','Eventos nocturnos'),
  EventPalettePreset('Lavanda','#C2B0FF','#30253D','Creativo y especial'),
  EventPalettePreset('Coral','#FFAA8C','#362A2A','Cercano y vibrante'),
];

/// El fondo se armoniza con una base oscura legible. El usuario puede elegir
/// cualquier hexadecimal sin convertir las tarjetas en masas de color brillante.
class EventPagePalette {
  EventPagePalette._({
    required this.accent,required this.onAccent,required this.canvas,
    required this.surface,required this.surfaceSoft,required this.border,
    required this.heroShade,
  });

  final Color accent,onAccent,canvas,surface,surfaceSoft,border,heroShade;

  static Color parse(String? hex,Color fallback){
    final text=(hex??'').trim();
    if(!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(text))return fallback;
    return Color(int.parse('FF'+text.substring(1),radix:16));
  }

  factory EventPagePalette.fromHex(String? accentHex,String? backgroundHex){
    final rawAccent=parse(accentHex,EventColors.primary);
    final rawBase=parse(backgroundHex,EventColors.background);
    final hsl=HSLColor.fromColor(rawBase);
    final hue=hsl.hue;
    final normalized=HSLColor.fromAHSL(1,hue,.27,.11).toColor();
    const neutral=Color(0xFF07151F);
    final canvas=Color.lerp(neutral,normalized,.43)!;
    final surface=Color.lerp(const Color(0xFF102B3A),
      HSLColor.fromAHSL(1,hue,.22,.15).toColor(),.34)!;
    final surfaceSoft=Color.lerp(const Color(0xFF183A49),
      HSLColor.fromAHSL(1,hue,.20,.20).toColor(),.30)!;
    final border=Color.lerp(const Color(0xFF315260),
      HSLColor.fromAHSL(1,hue,.19,.30).toColor(),.27)!;
    // Aclarar colores muy oscuros para que funcionen sobre superficies oscuras.
    final safeAccent=rawAccent.computeLuminance()<.18
      ?Color.lerp(rawAccent,Colors.white,.40)!
      :rawAccent;
    final onAccent=safeAccent.computeLuminance()>.37
      ?const Color(0xFF0B1721):Colors.white;
    return EventPagePalette._(
      accent:safeAccent,onAccent:onAccent,canvas:canvas,
      surface:surface,surfaceSoft:surfaceSoft,border:border,
      heroShade:Color.lerp(canvas,const Color(0xFF000A12),.45)!,
    );
  }

  static EventPagePalette of(BuildContext context){
    return context.dependOnInheritedWidgetOfExactType<EventPaletteScope>()
      ?.palette ?? EventPagePalette.fromHex(null,null);
  }
}

/// La tematización afecta solo a la página pública; el editor conserva
/// sus propios colores para que los controles administrativos sean legibles.
class EventPaletteScope extends InheritedWidget {
  const EventPaletteScope({super.key,required this.palette,required super.child});
  final EventPagePalette palette;
  @override bool updateShouldNotify(EventPaletteScope oldWidget) =>
    oldWidget.palette != palette;
}

ImageProvider? eventPhoto(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  try {
    if (value.startsWith('data:image/') && value.contains(',')) {
      return MemoryImage(base64Decode(value.substring(value.indexOf(',') + 1)));
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'https') return NetworkImage(value);
  } catch (_) {
    return null;
  }
  return null;
}

class EventPanel extends StatelessWidget {
  const EventPanel({
    super.key, required this.child,
    this.padding = const EdgeInsets.all(19),
    this.background, this.borderColor, this.radius = 19,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette=EventPagePalette.of(context);
    return Container(
      padding:padding,
      decoration:BoxDecoration(
        color:background??palette.surface,
        borderRadius:BorderRadius.circular(radius),
        border:Border.all(color:borderColor??palette.border.withOpacity(.75)),
        boxShadow:const [
          BoxShadow(color:Color(0x38000000),blurRadius:25,offset:Offset(0,10)),
        ],
      ),
      child:child,
    );
  }
}

class EventSectionHeading extends StatelessWidget {
  const EventSectionHeading({
    super.key, required this.title, this.subtitle, this.number, this.icon,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final int? number;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 37, height: 37,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:EventPagePalette.of(context).accent.withOpacity(.15),
          border:Border.all(color:EventPagePalette.of(context).accent.withOpacity(.20)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: number != null
          ? Text('$number', style: TextStyle(
              color: EventPagePalette.of(context).accent, fontWeight: FontWeight.w900, fontSize: 17))
          : Icon(icon ?? Icons.auto_awesome, color: EventPagePalette.of(context).accent, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontWeight: FontWeight.w800, color: EventColors.text, fontSize: 17)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: const TextStyle(
              color: EventColors.muted, fontSize: 12, height: 1.35)),
          ],
        ],
      )),
      if (trailing != null) trailing!,
    ],
  );
}

class EventArtwork extends StatelessWidget {
  const EventArtwork({
    super.key, this.source, this.height = 155, this.width,
    this.borderRadius = 13, this.emptyIcon = Icons.photo_camera_back_outlined,
    this.fit = BoxFit.cover,
  });
  final Object? source;
  final double height;
  final double? width;
  final double borderRadius;
  final IconData emptyIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final provider = eventPhoto(source);
    final placeholder = Container(
      color: EventColors.surfaceLight,
      alignment: Alignment.center,
      child: Icon(emptyIcon, color: EventColors.muted, size: 34),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: provider == null
          ? placeholder
          : Image(image: provider, fit: fit, width: width, height: height,
              errorBuilder: (_, __, ___) => placeholder),
      ),
    );
  }
}

class EventMetric extends StatelessWidget {
  const EventMetric({
    super.key, required this.icon, required this.label, required this.value,
    this.color = EventColors.primary,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 19),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          color: EventColors.muted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(
          color: EventColors.text, fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    )),
  ]);
}

class EventPill extends StatelessWidget {
  const EventPill({
    super.key, required this.icon, required this.label,
    this.color = EventColors.primary,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context){
    final palette=EventPagePalette.of(context);
    final accent=color==EventColors.primary?palette.accent:color;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
      decoration:BoxDecoration(
        color:palette.surface.withOpacity(.90),
        borderRadius:BorderRadius.circular(30),
        border:Border.all(color:accent.withOpacity(.36)),
      ),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,color:accent,size:15),
        const SizedBox(width:7),
        Flexible(child:Text(label,style:const TextStyle(
          color:EventColors.text,fontSize:12,fontWeight:FontWeight.w600))),
      ]),
    );
  }
}
