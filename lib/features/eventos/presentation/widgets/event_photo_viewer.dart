import 'package:flutter/material.dart';
import 'event_visual_kit.dart';

/// Visor para afiche, fotografías del establecimiento y mesas.
Future<void> showEventPhotoViewer(BuildContext context, {
  required List<Object?> images,
  required List<String> labels,
  int initialIndex = 0,
}) async {
  if (images.isEmpty || initialIndex < 0 || initialIndex >= images.length) return;
  if (eventPhoto(images[initialIndex]) == null) return;
  await showDialog<void>(
    context: context, useSafeArea: false, barrierColor: Colors.black87,
    builder: (_) => _EventPhotoLightbox(
      images: images, labels: labels, initialIndex: initialIndex),
  );
}

class _EventPhotoLightbox extends StatefulWidget {
  const _EventPhotoLightbox({
    required this.images, required this.labels, required this.initialIndex,
  });
  final List<Object?> images;
  final List<String> labels;
  final int initialIndex;
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
    final image = eventPhoto(widget.images[current]);
    final label = current < widget.labels.length
      ? widget.labels[current] : 'Fotografía ' + (current + 1).toString();
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF03141D),
      child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(children: [
            const Icon(Icons.collections_outlined, color: EventColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: EventColors.text,
                fontSize: 16, fontWeight: FontWeight.w800))),
            Text((current + 1).toString() + ' / ' +
              widget.images.length.toString(),
              style: const TextStyle(color: EventColors.muted)),
            const SizedBox(width: 10),
            IconButton(tooltip: 'Restablecer zoom',
              onPressed: () => zoomController.value = Matrix4.identity(),
              icon: const Icon(Icons.center_focus_strong,
                color: EventColors.text)),
            IconButton(tooltip: 'Cerrar visor',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: EventColors.text)),
          ]),
        ),
        Expanded(child: LayoutBuilder(builder: (context, bounds) => Stack(
          children: [
            Positioned.fill(child: image == null
              ? const Center(child: Icon(Icons.broken_image_outlined,
                  color: EventColors.muted, size: 55))
              : InteractiveViewer(
                  transformationController: zoomController,
                  minScale: 0.7, maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(45),
                  child: SizedBox(
                    width: bounds.maxWidth, height: bounds.maxHeight,
                    child: Image(image: image, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                          color: EventColors.muted, size: 55))),
                  ),
                )),
            if (widget.images.length > 1) ...[
              Positioned(left: 8, top: 0, bottom: 0,
                child: Center(child: IconButton.filledTonal(
                  tooltip: 'Anterior',
                  onPressed: current == 0 ? null : () => move(current - 1),
                  icon: const Icon(Icons.chevron_left)))),
              Positioned(right: 8, top: 0, bottom: 0,
                child: Center(child: IconButton.filledTonal(
                  tooltip: 'Siguiente',
                  onPressed: current == widget.images.length - 1
                    ? null : () => move(current + 1),
                  icon: const Icon(Icons.chevron_right)))),
            ],
          ],
        ))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text('Amplía la foto con los dedos, el trackpad o la rueda del ratón.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: EventColors.muted))),
        if (widget.images.length > 1)
          SizedBox(height: 68, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => move(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: current == index
                      ? EventColors.primary : EventColors.border,
                    width: current == index ? 2 : 1)),
                child: EventArtwork(source: widget.images[index],
                  width: 77, height: 56, borderRadius: 6),
              ),
            ),
          )),
        const SizedBox(height: 8),
      ])),
    );
  }
}
