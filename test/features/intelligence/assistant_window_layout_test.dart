import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/assistant_window_layout.dart';

void main(){
  test('opens immediately below a top assistant menu, aligned to its center',(){
    final rect=assistantWindowBounds(viewport:const Size(1440,1000),topInset:8,bottomInset:94,
      anchor:const Rect.fromLTWH(880,16,100,52));
    expect(rect.top,76);
    expect(rect.center.dx,930);
    expect(rect.height,650);
  });
  test('bottom navigation opens above the trigger without covering it',(){
    const anchor=Rect.fromLTWH(160,720,72,70);
    final rect=assistantWindowBounds(viewport:const Size(392,800),topInset:28,bottomInset:94,anchor:anchor);
    expect(rect.bottom,lessThan(anchor.top));
    expect(rect.left,greaterThanOrEqualTo(0));
    expect(rect.right,lessThanOrEqualTo(392));
  });
  test('dragging overrides initial anchor; resizing clamps the window',(){
    final rect=assistantWindowBounds(viewport:const Size(1024,768),topInset:8,bottomInset:94,
      anchor:const Rect.fromLTWH(800,10,72,52),draggedPosition:const Offset(1500,-20));
    expect(rect.top,8);
    expect(rect.right,lessThanOrEqualTo(1024));
    expect(rect.bottom,lessThanOrEqualTo(674));
  });
  test('keyboard inset keeps composer above keyboard',(){
    final rect=assistantWindowBounds(viewport:const Size(392,800),topInset:28,bottomInset:340,
      anchor:const Rect.fromLTWH(160,720,72,70));
    expect(rect.bottom,lessThanOrEqualTo(460));
    expect(rect.height,greaterThan(0));
  });
  test('resizes in either direction without leaving the viewport',(){
    final small=assistantWindowBounds(viewport:const Size(1440,1000),topInset:8,bottomInset:94,
      draggedPosition:const Offset(500,100),requestedSize:const Size(350,430));
    expect(small.size,const Size(350,430));
    final large=assistantWindowBounds(viewport:const Size(1440,1000),topInset:8,bottomInset:94,
      draggedPosition:const Offset(500,100),requestedSize:const Size(900,800));
    expect(large.size,const Size(900,800));
    final mobile=assistantWindowBounds(viewport:const Size(392,800),topInset:28,bottomInset:94,
      draggedPosition:const Offset(500,500),requestedSize:const Size(2000,2000));
    expect(mobile.right,lessThanOrEqualTo(392));
    expect(mobile.bottom,lessThanOrEqualTo(706));
  });
}
