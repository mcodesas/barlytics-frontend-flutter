import 'package:flutter/material.dart';
import 'event_visual_kit.dart';

/// Visor para afiche, fotografías y mesas: siempre usa la paleta del evento.
/// La ruta de showDialog no hereda necesariamente el tema del cuerpo de la
/// landing, por eso capturamos la paleta antes de abrirla y la entregamos
/// directamente a este diálogo.
Future<void> showEventPhotoViewer(BuildContext context, {
  required List<Object?> images,
  required List<String> labels,
  int initialIndex = 0,
  EventPagePalette? eventPalette,
}) async {
  if (images.isEmpty || initialIndex < 0 || initialIndex >= images.length) return;
  if (eventPhoto(images[initialIndex]) == null) return;
  final palette = eventPalette ?? EventPagePalette.of(context);
  await showDialog<void>(
    context: context, useSafeArea: false,
    barrierColor:palette.heroShade.withOpacity(.88),
    builder: (_) => EventPaletteScope(
      palette:palette,
      child:_EventPhotoLightbox(
        images: images, labels: labels, initialIndex: initialIndex,
        palette:palette,
      ),
    ),
  );
}

class _EventPhotoLightbox extends StatefulWidget {
  const _EventPhotoLightbox({
    required this.images, required this.labels, required this.initialIndex,
    required this.palette,
  });
  final List<Object?> images;
  final List<String> labels;
  final int initialIndex;
  final EventPagePalette palette;
  @override State<_EventPhotoLightbox> createState() => _EventPhotoLightboxState();
}

class _EventPhotoLightboxState extends State<_EventPhotoLightbox> {
  late int current;
  final zoomController = TransformationController();

  @override void initState() { super.initState(); current = widget.initialIndex; }
  @override void dispose() { zoomController.dispose(); super.dispose(); }

  void move(int next) {
    if (next < 0 || next >= widget.images.length) return;
    zoomController.value = Matrix4.identity();
    setState(() => current = next);
  }

  @override Widget build(BuildContext context) {
    final p=widget.palette;
    final background=p.surface;
    final text=p.onSurface;
    final muted=p.muted;
    final iconColor=p.accentOnSurface;
    final thumbnailColor=p.accentOnSurface;
    final image = eventPhoto(widget.images[current]);
    final label = current < widget.labels.length
      ? widget.labels[current] : 'Fotografía ' + (current + 1).toString();
    final buttonStyle=IconButton.styleFrom(
      foregroundColor:p.accentOnSoft,
      disabledForegroundColor:muted.withOpacity(.6),
      backgroundColor:p.surfaceSoft,
    );

    return Theme(
      data:(background.computeLuminance()>.18
        ?ThemeData.light(useMaterial3:true)
        :ThemeData.dark(useMaterial3:true)).copyWith(
          colorScheme:(background.computeLuminance()>.18
             ?ColorScheme.light(
               primary:p.accent,onPrimary:p.onAccent,
               surface:background,onSurface:text)
             :ColorScheme.dark(
               primary:p.accent,onPrimary:p.onAccent,
               surface:background,onSurface:text)),
          textTheme:Theme.of(context).textTheme.apply(
             bodyColor:text,displayColor:text),
          iconButtonTheme:IconButtonThemeData(style:buttonStyle),
        ),
      child:Dialog.fullscreen(
        backgroundColor: background,
        child: SafeArea(child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration:BoxDecoration(
              color:p.surface,
              border:Border(bottom:BorderSide(color:p.border))),
            child: Row(children: [
              Icon(Icons.collections_outlined,color:iconColor),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:TextStyle(color:text,
                  fontSize:16,fontWeight:FontWeight.w800))),
              Text((current + 1).toString() + ' / ' +
                widget.images.length.toString(),
                style:TextStyle(color:muted)),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Restablecer zoom',
                style:buttonStyle,
                onPressed: () => zoomController.value = Matrix4.identity(),
                icon:Icon(Icons.center_focus_strong,color:p.accentOnSoft)),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Cerrar visor',
                style:buttonStyle,
                onPressed: () => Navigator.of(context).pop(),
                icon:Icon(Icons.close,color:p.accentOnSoft)),
            ]),
          ),
          Expanded(child: LayoutBuilder(builder: (context, bounds) => Stack(
            children: [
              Positioned.fill(child: image == null
                ?Center(child:Icon(Icons.broken_image_outlined,
                    color:muted,size:55))
                : InteractiveViewer(
                    transformationController: zoomController,
                    minScale: 0.7, maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(45),
                    child: SizedBox(
                      width: bounds.maxWidth, height: bounds.maxHeight,
                      child: Image(image: image, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child:Icon(Icons.broken_image_outlined,
                            color:muted,size:55))),
                    ),
                  )),
              if (widget.images.length > 1) ...[
                Positioned(left: 8, top: 0, bottom: 0,
                  child: Center(child: IconButton.filledTonal(
                    tooltip: 'Anterior',
                    style:buttonStyle,
                    onPressed: current == 0 ? null : () => move(current - 1),
                    icon: const Icon(Icons.chevron_left)))),
                Positioned(right: 8, top: 0, bottom: 0,
                  child: Center(child: IconButton.filledTonal(
                    tooltip: 'Siguiente',
                    style:buttonStyle,
                    onPressed: current == widget.images.length - 1
                      ? null : () => move(current + 1),
                    icon: const Icon(Icons.chevron_right)))),
              ],
            ],
          ))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Text('Amplía la foto con los dedos, el trackpad o la rueda del ratón.',
              textAlign: TextAlign.center,
              style:TextStyle(fontSize:12,color:muted))),
          if (widget.images.length > 1)
            SizedBox(height: 76, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => move(index),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: current == index?thumbnailColor:p.border,
                      width: current == index?2:1)),
                  child: EventArtwork(source: widget.images[index],
                    width: 77, height: 56, borderRadius: 6),
                ),
              ),
            )),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }
}
