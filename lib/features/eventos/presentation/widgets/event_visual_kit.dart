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
/// Una paleta describe la experiencia completa, no solo el color del botón.
class EventPalettePreset {
  const EventPalettePreset(this.name,this.accent,this.background,this.text,this.description);
  final String name,accent,background,text,description;
}

const eventPalettePresets=<EventPalettePreset>[
  EventPalettePreset('Nocturno turquesa','#35D0C5','#102735','#F2FBFF','Moderno y nocturno'),
  EventPalettePreset('Champán clásico','#AC8246','#F3E7D3','#2A211C','Restaurante y celebración'),
  EventPalettePreset('Vino y marfil','#8A3D52','#F6EBDD','#2A1E1F','Clásico y romántico'),
  EventPalettePreset('Café reserva','#A87648','#EDE0D1','#2F241E','Cálido y artesanal'),
  EventPalettePreset('Oliva gourmet','#667E46','#F2F0E4','#263024','Natural y sobrio'),
  EventPalettePreset('Cobre nocturno','#E39A67','#1E1614','#F4E7D8','Gastronomía de noche'),
  EventPalettePreset('Ámbar lounge','#F0B15D','#241B16','#F8ECDD','Elegancia de bar'),
  EventPalettePreset('Rojo reserva','#CB7872','#211617','#F6E9E3','Íntimo y sofisticado'),
  EventPalettePreset('Verde botella','#83C597','#17211C','#EAF2EC','Elegante y fresco'),
  EventPalettePreset('Terracota suave','#B66B4F','#F3E1D5','#342721','Acogedor y orgánico'),
  EventPalettePreset('Azul petróleo','#357B80','#E8F0EF','#203133','Editorial y moderno'),
  EventPalettePreset('Lavanda boutique','#8D6AB7','#F0EAF7','#2C2238','Creativo y delicado'),
  EventPalettePreset('Rosa ópalo','#C36E8C','#F7E8ED','#342229','Romántico y sutil'),
  EventPalettePreset('Azul imperial','#8BACFF','#1A2947','#ECF0FF','Celebración nocturna'),
  EventPalettePreset('Esmeralda gala','#8DDBB5','#14362F','#F1FFF9','Distinción natural'),
  EventPalettePreset('Medianoche dorada','#F2CF88','#17191D','#F8F3E8','Formal y premium'),
  EventPalettePreset('Blanco minimalista','#345D73','#FAFAF7','#1D2930','Limpio y profesional'),
  EventPalettePreset('Ciruela elegante','#CFA7DB','#2D1F31','#F7EEF8','Boutique nocturno'),
  EventPalettePreset('Coral mediterráneo','#B75B43','#FFF1E1','#33241E','Luminoso y cálido'),
  EventPalettePreset('Carbón plata','#D3D6DB','#22262B','#F6F7F9','Urbano y sobrio'),
];

/// Colores derivados del fondo elegido: sin imponer azul de ninguna manera.
/// En fondos claros se generan tarjetas claras, en fondos oscuros, oscuras.
class EventPagePalette {
  EventPagePalette._({
    required this.accent,required this.onAccent,required this.canvas,
    required this.surface,required this.surfaceSoft,required this.border,
    required this.heroShade,required this.text,required this.muted,
    required this.menuPaper,required this.menuInk,required this.menuBorder,
  });
  final Color accent,onAccent,canvas,surface,surfaceSoft,border,heroShade,text,muted;
  final Color menuPaper,menuInk,menuBorder;

  static Color parse(String? hex,Color fallback){
    final value=(hex??'').trim();
    if(!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value))return fallback;
    return Color(int.parse('FF'+value.substring(1),radix:16));
  }

  static double contrast(Color a,Color b){
    final l1=a.computeLuminance()+.05,l2=b.computeLuminance()+.05;
    return l1>l2?l1/l2:l2/l1;
  }

  factory EventPagePalette.fromHex(String? accentHex,String? backgroundHex,
    [String? textHex,String? surfaceHex,String? borderHex,String? menuHex]){
    final base=parse(backgroundHex,EventColors.background);
    final foreground=parse(textHex,
      base.computeLuminance()>.38?const Color(0xFF211B18):EventColors.text);
    final accent=parse(accentHex,EventColors.primary);
    final light=base.computeLuminance()>.38;
    final surface= parse(surfaceHex,
      Color.lerp(base,Colors.white,light?.36:.11)!);
    final surfaceSoft=Color.lerp(surface,Colors.white,
      surface.computeLuminance()>.38?.24:.08)!;
    final border=parse(borderHex,Color.lerp(base,foreground,light?.28:.31)!);
    final muted=Color.lerp(foreground,surface,.31)!;
    final onAccent=contrast(accent,const Color(0xFF171717))>=
        contrast(accent,Colors.white)?const Color(0xFF171717):Colors.white;
    final page=parse(menuHex,
      Color.lerp(base,Colors.white,light?.17:.12)!);
    return EventPagePalette._(
      accent:accent,onAccent:onAccent,canvas:base,surface:surface,
      surfaceSoft:surfaceSoft,border:border,
      text:foreground,muted:muted,
      // El hero mantiene una velo del propio fondo seleccionado.
      heroShade:base,
      menuPaper:page,menuInk:foreground,
      menuBorder:Color.lerp(page,accent,.56)!,
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
          Text(title, style: TextStyle(
            fontWeight: FontWeight.w800, color: EventPagePalette.of(context).text, fontSize: 17)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: TextStyle(
              color: EventPagePalette.of(context).muted, fontSize: 12, height: 1.35)),
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
      color: EventPagePalette.of(context).surfaceSoft,
      alignment: Alignment.center,
      child: Icon(emptyIcon, color: EventPagePalette.of(context).muted, size: 34),
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
  Widget build(BuildContext context) {
    final palette=EventPagePalette.of(context);
    final activeColor=color==EventColors.primary?palette.accent:color;
    return Row(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: activeColor.withOpacity(.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: activeColor, size: 19),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          color: EventPagePalette.of(context).muted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(
          color: EventPagePalette.of(context).text, fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    )),
  ]);
  }
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
        Flexible(child:Text(label,style:TextStyle(
          color:palette.text,fontSize:12,fontWeight:FontWeight.w600))),
      ]),
    );
  }
}
