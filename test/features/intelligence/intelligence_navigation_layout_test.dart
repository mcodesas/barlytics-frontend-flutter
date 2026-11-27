import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/presentation/intelligence_navigation.dart';

void main(){
  const a=Key('a'),b=Key('b'),c=Key('c'),center=Key('center'),d=Key('d'),e=Key('e');
  Widget tile(Key key)=>SizedBox(key:key,height:44,child:const Center(child:Icon(Icons.home)));
  Widget bar(double width)=>MaterialApp(home:Scaffold(body:Center(child:SizedBox(width:width,child:Row(children:[
    Expanded(child:IntelligenceNavigationHalf(children:[tile(a),tile(b),tile(c)])),
    const SizedBox(key:center,width:72,height:60),
    Expanded(child:IntelligenceNavigationHalf(children:[tile(d),tile(e)])),
  ])))));
  testWidgets('Wide bar fills both halves and keeps assistant centered',(tester) async {
    await tester.pumpWidget(bar(720));
    final x= tester.getCenter(find.byKey(center)).dx;
    expect(x,closeTo(tester.view.physicalSize.width/tester.view.devicePixelRatio/2,1));
    final left=tester.getRect(find.byKey(a)),middle=tester.getRect(find.byKey(b)),last=tester.getRect(find.byKey(c));
    final right=tester.getRect(find.byKey(d)),end=tester.getRect(find.byKey(e));
    expect(left.width,closeTo(108,1));expect(left.right,closeTo(middle.left,1));
    expect(last.right,closeTo(x-36,1));expect(right.left,closeTo(x+36,1));
    expect(right.width,closeTo(162,1));expect(right.right,closeTo(end.left,1));
    expect(find.byType(SingleChildScrollView),findsNothing);
  });
  testWidgets('Compact bar scrolls instead of overflowing and keeps center',(tester) async {
    await tester.pumpWidget(bar(320));
    expect(find.byType(SingleChildScrollView),findsOneWidget);
    expect(tester.getSize(find.byKey(a)).width,58);
    expect(tester.takeException(),isNull);
  });
}
