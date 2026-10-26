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
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: background ?? EventColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? EventColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x18000000), blurRadius: 20, offset: Offset(0, 8)),
      ],
    ),
    child: child,
  );
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
          gradient: const LinearGradient(
            colors: [Color(0xFF20D6CF), Color(0xFF088B9F)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: number != null
          ? Text('$number', style: const TextStyle(
              color: EventColors.onPrimary, fontWeight: FontWeight.w900, fontSize: 17))
          : Icon(icon ?? Icons.auto_awesome, color: EventColors.onPrimary, size: 19),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: EventColors.surface.withOpacity(.85),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withOpacity(.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 7),
      Flexible(child: Text(label, style: const TextStyle(
        color: EventColors.text, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}
