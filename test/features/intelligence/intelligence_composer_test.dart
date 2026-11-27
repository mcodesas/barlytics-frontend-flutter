import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/presentation/intelligence_composer.dart';
void main(){
  testWidgets('Enter sends only when enabled; Shift Enter does not send',(tester) async {
    final controller=TextEditingController(),focus=FocusNode();
    var sends=0;
    Widget app(bool enterSends,bool enabled)=>MaterialApp(home:Scaffold(body:IntelligenceComposer(
      controller:controller,focusNode:focus,enabled:enabled,enterSends:enterSends,onSend:()=>sends++)));
    await tester.pumpWidget(app(true,true));
    await tester.enterText(find.byType(TextField),'Hola');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends,1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sends,1);
    await tester.pumpWidget(app(false,true));
    await tester.enterText(find.byType(TextField),'Otra pregunta');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends,1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();focus.dispose();
  });
}
