import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntelligenceComposer extends StatelessWidget {
  const IntelligenceComposer({super.key,required this.controller,required this.focusNode,
    required this.enabled,required this.enterSends,required this.onSend,this.allowEmpty=false});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled,enterSends,allowEmpty;
  final VoidCallback onSend;

  void submit(){
    final v=controller.value;
    if(enabled&&(allowEmpty||v.text.trim().isNotEmpty)&&v.text.length<=2000&&
       !(v.composing.isValid&&!v.composing.isCollapsed))onSend();
  }

  @override
  Widget build(BuildContext context)=>CallbackShortcuts(
    bindings:enabled&&enterSends?{
      const SingleActivator(LogicalKeyboardKey.enter,includeRepeats:false):submit,
      const SingleActivator(LogicalKeyboardKey.numpadEnter,includeRepeats:false):submit,
    }:const {},
    child:TextField(controller:controller,focusNode:focusNode,enabled:enabled,
      minLines:1,maxLines:4,maxLength:2000,
      textInputAction:enterSends?TextInputAction.send:TextInputAction.newline,
      onSubmitted:enterSends?(_)=>submit():null,
      decoration:const InputDecoration(hintText:'Escribe tu consulta…',border:OutlineInputBorder())),
  );
}
