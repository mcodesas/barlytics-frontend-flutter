import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../domain/voice_turn_detector.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/intelligence_api.dart';
import '../domain/pcm_wav.dart';

Future<void> showIntelligenceChat(BuildContext context) async {
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
    backgroundColor:Colors.transparent,constraints:const BoxConstraints(maxWidth:760),
    builder:(context)=>const IntelligenceChat());
}

class _Attachment {
  const _Attachment(this.kind,this.name,this.bytes);
  final String kind,name;
  final Uint8List bytes;
}

class IntelligenceChat extends ConsumerStatefulWidget {
  const IntelligenceChat({super.key});
  @override
  ConsumerState<IntelligenceChat> createState()=>_IntelligenceChatState();
}

class _IntelligenceChatState extends ConsumerState<IntelligenceChat> with WidgetsBindingObserver {
  final _text=TextEditingController(),_picker=ImagePicker(),_recorder=AudioRecorder();
  final List<({String role,String text})> _messages=[];
  final BytesBuilder _pcm=BytesBuilder(copy:false);
  final AudioPlayer _player=AudioPlayer();
  StreamSubscription<Uint8List>? _liveSubscription;
  Timer? _liveTimeout;
  VoiceTurnDetector? _detector;
  bool _live=false,_liveProcessing=false;
  int _liveEpoch=0;
  String _livePhase='';
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden||state==AppLifecycleState.detached){
      if(_live)unawaited(_endLive());
      if(_recording)unawaited(_discardRecording());
    }
  }
  Future<void> _discardRecording() async {
    _timer?.cancel();
    if(mounted)setState(()=>_recording=false);
    try{await _recorder.cancel();await _audioSubscription?.cancel();}catch(_){}
    _audioSubscription=null;_pcm.clear();
  }
  bool _liveActive(int e)=>mounted&&!_closed&&_live&&e==_liveEpoch;
  Future<void> _startLive() async {
    if(_busy||_recording||_live||_closed||_branch==null)return;
    setState((){_live=true;_livePhase='Activando micrófono…';_error='';});
    final e=++_liveEpoch;
    try{
      if(!await _recorder.hasPermission())throw StateError('Micrófono no autorizado');
      if(!_liveActive(e))return;
      _liveTimeout=Timer(const Duration(minutes:10),()=>unawaited(_endLive()));
      await _listenLive(e);
    }catch(_){await _liveFailure(e);}
  }
  Future<void> _listenLive(int e) async {
    if(!_liveActive(e))return;
    _liveProcessing=false;
    _detector=VoiceTurnDetector();
    final stream=await _recorder.startStream(const RecordConfig(
      encoder:AudioEncoder.pcm16bits,sampleRate:16000,numChannels:1));
    if(!_liveActive(e)){await _recorder.cancel();return;}
    setState(()=>_livePhase='Escuchando…');
    _liveSubscription=stream.listen((bytes){
      if(!_liveActive(e)||_liveProcessing)return;
      final turn=_detector?.add(bytes);
      if(turn!=null){_liveProcessing=true;unawaited(_processLive(e,turn));}
    },onError:(Object _)=>unawaited(_liveFailure(e)));
  }
  Future<void> _processLive(int e,Uint8List pcm) async {
    if(!_liveActive(e))return;
    try{
      setState(()=>_livePhase='Interpretando tu voz…');
      await _recorder.stop();
      await _liveSubscription?.cancel();_liveSubscription=null;_detector=null;
      if(!_liveActive(e))return;
      final service=ref.read(intelligenceApiProvider);
      final transcript=await service.media(_branch!,'audio','turno.wav',pcmWav(pcm));
      if(!_liveActive(e))return;
      final text=(transcript['text']?.toString()??'').trim();
      if(text.isEmpty){await _listenLive(e);return;}
      final input=text.characters.take(2000).toString();
      setState(()=>_livePhase='Pensando…');
      final reply=await service.chat(_branch!,_conversation,input);
      if(!_liveActive(e))return;
      final id=reply['conversationId'],answer=reply['answer'];
      if(id is! String||answer is! String)throw StateError('Respuesta inválida');
      setState((){_conversation=id;_messages.add((role:'user',text:input));
        _messages.add((role:'assistant',text:answer));_livePhase='Preparando respuesta de voz…';});
      final spoken=answer.characters.take(600).toString();
      if(spoken.trim().isNotEmpty){
        final wav=await service.speech(_branch!,spoken);
        if(!_liveActive(e))return;
        setState(()=>_livePhase='Respondiendo…');
        // Microphone is stopped during playback to avoid feedback.
        final done=_player.onPlayerComplete.first;
        await _player.play(BytesSource(wav,mimeType:'audio/wav'));
        if(!_liveActive(e)){await _player.stop();return;}
        await done.timeout(const Duration(minutes:2));
      }
      if(_liveActive(e))await _listenLive(e);
    }catch(_){await _liveFailure(e);}
  }
  Future<void> _liveFailure(int e) async {
    if(!_liveActive(e))return;
    await _endLive();
    if(mounted&&!_closed)setState(()=>_error='La sesión de voz terminó. Revisa el micrófono, el audio o la disponibilidad del asistente.');
  }
  Future<void> _endLive() async {
    if(!_live)return;
    _liveEpoch++;_liveTimeout?.cancel();_detector=null;
    if(mounted)setState((){_live=false;_livePhase='';_busy=true;});
    try{await _liveSubscription?.cancel();_liveSubscription=null;await _recorder.cancel();}catch(_){}
    try{await _player.stop();}catch(_){}
    if(mounted&&!_closed)setState(()=>_busy=false);
  }
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _timer;
  _Attachment? _attachment;
  String? _conversation;
  String _error='',_extracted='';
  int? _branch;
  bool _busy=false,_recording=false,_closed=false;
  int _epoch=0;
  bool get _cameraAvailable=>kIsWeb||defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_branch=ref.read(branchScopeProvider).activeBranchId;}
  bool _active(int epoch)=>mounted&&!_closed&&epoch==_epoch;
  Future<void> _run(Future<void> Function(int) action) async {
    if(_busy||_recording||_live||_closed)return;
    final e=_epoch;setState((){_busy=true;_error='';});
    try{await action(e);}catch(_){if(_active(e))setState(()=>_error='No se pudo completar la operación. Verifica permisos y disponibilidad del asistente.');}
    finally{if(_active(e))setState(()=>_busy=false);}
  }
  void _invalidate(){
    if(_closed)return;
    _closed=true;_epoch++;_liveEpoch++;_liveTimeout?.cancel();_timer?.cancel();
    unawaited(_audioSubscription?.cancel()??Future<void>.value());
    unawaited(_recorder.cancel().catchError((Object _){}));
    unawaited(_liveSubscription?.cancel()??Future<void>.value());
    unawaited(_player.stop().catchError((Object _){}));
    _pcm.clear();_attachment=null;_extracted='';_messages.clear();_text.clear();
    if(mounted)Navigator.of(context).pop();
  }
  Future<void> _select(String kind,{bool camera=false}) async=>_run((e) async {
    final extensions=kind=='video'?['mp4','mov','webm']:kind=='photo'?['png','jpg','jpeg']:kind=='audio'?['wav']:['pdf','xlsx','csv','txt','png','jpg','jpeg'];
    XFile? file;
    if(camera&&_cameraAvailable){
      file=kind=='video'?await _picker.pickVideo(source:ImageSource.camera,maxDuration:const Duration(seconds:30))
        :await _picker.pickImage(source:ImageSource.camera,maxWidth:2400,maxHeight:2400,imageQuality:82);
    }else{
      final selected=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:extensions,withData:false);
      if(selected==null||selected.xFiles.isEmpty)return;
      file=selected.xFiles.first;
    }
    if(file==null||!_active(e))return;
    final limit=(kind=='audio'?3:5)*1024*1024;
    if(await file.length()>limit){if(_active(e))setState(()=>_error='Archivo superior al límite de ${limit~/1024~/1024} MiB.');return;}
    final bytes=await file.readAsBytes();
    if(!_active(e))return;
    if(bytes.isEmpty||bytes.length>limit){setState(()=>_error='Archivo vacío o demasiado grande.');return;}
    setState((){_attachment=_Attachment(kind,file!.name,bytes);_extracted='';});
  });
  Future<void> _startAudio() async {
    if(_busy||_recording||_closed)return;
    final e=_epoch;setState((){_busy=true;_error='';});
    try{
      if(!await _recorder.hasPermission()){if(_active(e))setState(()=>_error='Permite acceso al micrófono.');return;}
      if(!_active(e))return;
      _pcm.clear();
      final stream=await _recorder.startStream(const RecordConfig(encoder:AudioEncoder.pcm16bits,sampleRate:16000,numChannels:1));
      if(!_active(e)){await _recorder.cancel();return;}
      _audioSubscription=stream.listen((bytes){
        final remaining=960000-_pcm.length;
        if(remaining>0)_pcm.add(bytes.length<=remaining?bytes:Uint8List.sublistView(bytes,0,remaining));
      },onError:(Object _){if(_active(e)){setState(()=>_error='Falló el micrófono.');unawaited(_stopAudio());}});
      setState(()=>_recording=true);
      _timer=Timer(const Duration(seconds:30),()=>unawaited(_stopAudio()));
    }catch(_){if(_active(e))setState(()=>_error='No se pudo iniciar el micrófono.');}
    finally{if(_active(e))setState(()=>_busy=false);}
  }
  Future<void> _stopAudio() async {
    if(!_recording||_busy||_closed)return;
    final e=_epoch;_timer?.cancel();setState((){_recording=false;_busy=true;});
    try{
      await _recorder.stop();await _audioSubscription?.cancel();_audioSubscription=null;
      final wav=pcmWav(_pcm.takeBytes());
      if(_active(e))setState((){_attachment=_Attachment('audio','grabacion.wav',wav);_extracted='';});
    }catch(_){if(_active(e))setState(()=>_error='Graba entre 0,25 y 30 segundos.');}
    finally{if(_active(e))setState(()=>_busy=false);}
  }
  Future<void> _analyze() async=>_run((e) async{
    final a=_attachment;
    if(a==null||_branch==null)return;
    if(a.kind=='video'){setState(()=>_error='El vídeo está seleccionado. El procesamiento de vídeo aún no está habilitado.');return;}
    final result=await ref.read(intelligenceApiProvider).media(_branch!,a.kind,a.name,a.bytes);
    if(_active(e))setState(()=>_extracted=result['text']?.toString()??'');
  });
  Future<void> _send() async=>_run((e) async{
    final text=_text.text.trim();
    if(text.isEmpty||text.length>2000||_branch==null)return;
    final reply=await ref.read(intelligenceApiProvider).chat(_branch!,_conversation,text);
    if(!_active(e))return;
    final id=reply['conversationId'],answer=reply['answer'];
    if(id is! String||answer is! String)throw StateError('Respuesta inválida');
    setState((){_conversation=id;_messages.add((role:'user',text:text));_messages.add((role:'assistant',text:answer));_text.clear();});
  });
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _closed=true;_epoch++;_liveEpoch++;_liveTimeout?.cancel();_timer?.cancel();
    unawaited(_liveSubscription?.cancel()??Future<void>.value());unawaited(_player.dispose());
    unawaited(_audioSubscription?.cancel()??Future<void>.value());
    unawaited(_recorder.dispose());_text.dispose();_pcm.clear();super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final palette=ref.watch(selectedAppPaletteProvider);
    final branch=ref.watch(branchScopeProvider).activeBranch;
    ref.listen(authControllerProvider,(prev,next){if(!next.authenticated||!next.subscriptionActive)_invalidate();});
    ref.listen(branchScopeProvider,(prev,next){if(next.activeBranchId!=_branch)_invalidate();});
    final locked=_busy||_recording||_live;
    return Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:Material(
      color:palette.surface,borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),clipBehavior:Clip.antiAlias,
      child:SizedBox(height:MediaQuery.sizeOf(context).height*.86,child:SafeArea(top:false,child:Column(children:[
        Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          CircleAvatar(backgroundColor:palette.primary,child:Icon(Icons.auto_awesome_rounded,color:palette.onPrimary)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Inteligencia BarLytics',style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.w800,fontSize:18)),
            Text(branch?.label()??'Sucursal no disponible',style:TextStyle(color:palette.textSecondary))])),
          IconButton(tooltip:'Nueva conversación',onPressed:locked?null:()=>setState((){_conversation=null;_messages.clear();_attachment=null;_extracted='';_text.clear();_error='';}),icon:const Icon(Icons.add_comment_outlined)),
          IconButton(tooltip:'Cerrar chat',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))])),
        if(_busy)const LinearProgressIndicator(),
        if(_live)Container(padding:const EdgeInsets.all(14),color:palette.primary.withOpacity(.10),child:Row(children:[
          CircleAvatar(radius:25,backgroundColor:palette.primary,child:Icon(Icons.graphic_eq,color:palette.onPrimary)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_livePhase,style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.bold)),
            const Text('Voz continua · micrófono activo solo al escuchar') ])),
          IconButton(tooltip:'Finalizar voz continua',onPressed:()=>unawaited(_endLive()),icon:Icon(Icons.call_end,color:palette.danger))
        ])),
        Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
          if(_messages.isEmpty)const Center(child:Padding(padding:EdgeInsets.symmetric(vertical:32),child:Text('¿En qué puedo ayudarte hoy?\nConsulta o adjunta un archivo para revisar su contenido.',textAlign:TextAlign.center))),
          for(final m in _messages)Align(alignment:m.role=='user'?Alignment.centerRight:Alignment.centerLeft,child:Container(
            margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),constraints:const BoxConstraints(maxWidth:540),
            decoration:BoxDecoration(color:m.role=='user'?palette.primary.withOpacity(.16):palette.background,borderRadius:BorderRadius.circular(16)),
            child:SelectableText(m.text,style:TextStyle(color:palette.textPrimary)))),
          if(_attachment!=null)Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.attach_file),Expanded(child:Text(_attachment!.name,maxLines:1,overflow:TextOverflow.ellipsis)),
              IconButton(tooltip:'Quitar adjunto',onPressed:locked?null:()=>setState((){_attachment=null;_extracted='';}),icon:const Icon(Icons.close))]),
            if(_attachment!.kind=='photo')ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.memory(_attachment!.bytes,height:120,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('Vista previa no disponible'))),
            if(_attachment!.kind=='video')const Text('Vídeo preparado localmente. Análisis de vídeo pendiente.'),
            if(_attachment!.kind!='video')OutlinedButton(onPressed:locked?null:_analyze,child:const Text('Extraer contenido')),
            if(_extracted.isNotEmpty)...[SelectableText(_extracted),TextButton(onPressed:locked?null:(){
              final combined=[_text.text.trim(),_extracted].where((x)=>x.isNotEmpty).join('\n\n');
              if(combined.length>2000){setState(()=>_error='Copia un fragmento de hasta 2000 caracteres para enviar.');return;}
              setState(()=>_text.text=combined);
            },child:const Text('Usar texto revisado en el chat'))]
          ]))),
          if(_error.isNotEmpty)Text(_error,style:TextStyle(color:palette.danger)),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(12,4,12,12),child:Column(children:[
          TextField(controller:_text,enabled:!locked,minLines:1,maxLines:4,maxLength:2000,decoration:const InputDecoration(hintText:'Escribe tu consulta…',border:OutlineInputBorder())),
          Wrap(alignment:WrapAlignment.center,crossAxisAlignment:WrapCrossAlignment.center,spacing:4,children:[
            IconButton(tooltip:_cameraAvailable?'Tomar foto':'Adjuntar foto',onPressed:locked?null:()=>_select('photo',camera:true),icon:const Icon(Icons.photo_camera_outlined)),
            IconButton(tooltip:'Adjuntar archivo',onPressed:locked?null:()=>_select('file'),icon:const Icon(Icons.attach_file_rounded)),
            IconButton(tooltip:_cameraAvailable?'Grabar vídeo':'Adjuntar vídeo',onPressed:locked?null:()=>_select('video',camera:true),icon:const Icon(Icons.videocam_outlined)),
            IconButton(tooltip:_recording?'Detener audio':'Grabar audio',onPressed:_busy||_live?null:_recording?_stopAudio:_startAudio,icon:Icon(_recording?Icons.stop_circle_rounded:Icons.mic_none_rounded,color:_recording?palette.danger:palette.textPrimary)),
            IconButton(tooltip:'Adjuntar WAV',onPressed:locked?null:()=>_select('audio'),icon:const Icon(Icons.audio_file_outlined)),
            IconButton(tooltip:'Conversar por voz continua',onPressed:locked||_branch==null?null:_startLive,icon:const Icon(Icons.graphic_eq_rounded)),
            FilledButton.icon(onPressed:locked||_branch==null?null:_send,icon:const Icon(Icons.send_rounded),label:const Text('Enviar'))
          ]),if(_recording)const Text('Grabando audio · máximo 30 segundos'),
          const Text('Revisa los adjuntos antes de enviarlos. No se ejecutan operaciones comerciales desde este chat.',textAlign:TextAlign.center,style:TextStyle(fontSize:10))
        ]))
      ])))));
  }
}
