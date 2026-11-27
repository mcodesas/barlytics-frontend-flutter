import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Place the first window next to the actual assistant trigger. Prefer below
/// when it fits, otherwise the side with more usable space (mobile bottom
/// navigation naturally opens above). Keep the window within the viewport.
Rect assistantWindowBounds({
  required Size viewport,
  required double topInset,
  required double bottomInset,
  Rect? anchor,
  Offset? draggedPosition,
}) {
  final top=topInset.clamp(0.0,viewport.height).toDouble();
  final bottom=(viewport.height-bottomInset).clamp(top,viewport.height).toDouble();
  final width=(viewport.width-24).clamp(0.0,470.0).toDouble();
  final fullHeight=(bottom-top-8).clamp(0.0,650.0).toDouble();
  final maxX=math.max(0.0,viewport.width-width-12);
  final below=anchor==null?top:(anchor.bottom+8).clamp(top,bottom).toDouble();
  final above=anchor==null?bottom:(anchor.top-8).clamp(top,bottom).toDouble();
  final belowSpace=math.max(0.0,bottom-below);
  final aboveSpace=math.max(0.0,above-top);
  final useBelow=belowSpace>=fullHeight||belowSpace>=aboveSpace;
  final sideSpace=useBelow?belowSpace:aboveSpace;
  // When a trigger is near the middle of a small viewport, keep the normal
  // usable chat height rather than clipping its composer into a tiny strip.
  final height=anchor!=null&&sideSpace>=math.min(360.0,fullHeight)
      ?math.min(fullHeight,sideSpace):fullHeight;
  final desired=draggedPosition??(anchor==null
      ?Offset(maxX,top)
      :Offset(anchor.center.dx-width/2,useBelow?below:above-height));
  final x=desired.dx.clamp(0.0,maxX).toDouble();
  final y=desired.dy.clamp(top,math.max(top,bottom-height)).toDouble();
  return Rect.fromLTWH(x,y,width,height);
}
