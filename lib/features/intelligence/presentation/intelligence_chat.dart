import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/intelligence_attachment.dart';
import '../../../core/errors/app_exception.dart';
import 'intelligence_composer.dart';
import 'intelligence_export_card.dart';
import 'intelligence_alerts_card.dart';
import 'intelligence_forecast_card.dart';
import 'intelligence_catalog_sync_card.dart';
import 'intelligence_purchase_review.dart';
import '../../navigation/presentation/providers/menu_preferences_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../../../app/router/app_router.dart';
import '../../navigation/presentation/providers/user_menu_provider.dart';
import '../domain/assistant_navigation.dart';
import '../domain/assistant_screen_context.dart';
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

/// The window belongs to the app shell, not to any individual route.
final intelligenceWindowProvider=StateProvider<bool>((ref)=>false);
final _windowKey=GlobalKey<_IntelligenceWindowState>();

Future<void> showIntelligenceChat(BuildContext context) async {
  final container=ProviderScope.containerOf(context,listen:false);
  final menu=await container.read(userMenuProvider.future);
  if(!menu.any((item)=>item.keyName=='intelligence'))return;
  container.read(intelligenceWindowProvider.notifier).state=true;
  _windowKey.currentState?.restore();
}

class IntelligenceWindowHost extends ConsumerWidget {
  const IntelligenceWindowHost({super.key,required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context,WidgetRef ref){
    final auth=ref.watch(authControllerProvider);
    final branch=ref.watch(branchScopeProvider).activeBranchId;
    final open=ref.watch(intelligenceWindowProvider);
    final authorized=ref.watch(userMenuProvider).valueOrNull?.any((item)=>item.keyName=='intelligence')??false;
    ref.listen(authControllerProvider,(old,next){
      if(!next.authenticated||!next.subscriptionActive||next.restoringSession){
        ref.read(intelligenceWindowProvider.notifier).state=false;
      }
    });
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)ref.read(intelligenceWindowProvider.notifier).state=false;});
    ref.listen(branchScopeProvider,(old,next){
      if(old?.activeBranchId!=next.activeBranchId){
        ref.read(intelligenceWindowProvider.notifier).state=false;
      }
    });
    return Stack(fit:StackFit.expand,children:[
      child,
      if(open&&authorized&&auth.authenticated&&auth.subscriptionActive&&!auth.restoringSession&&branch!=null)
        _IntelligenceLayer(onClose:()=>ref.read(intelligenceWindowProvider.notifier).state=false),
    ]);
  }
}
/// Own overlay for tooltips and menus, independent of Navigator route order.
class _IntelligenceLayer extends StatefulWidget {
  const _IntelligenceLayer({required this.onClose});
  final VoidCallback onClose;
  @override
  State<_IntelligenceLayer> createState()=>_IntelligenceLayerState();
}
class _IntelligenceLayerState extends State<_IntelligenceLayer>{
  late final OverlayEntry entry;
  @override
  void initState(){
    super.initState();
    entry=OverlayEntry(builder:(_)=>_IntelligenceWindow(key:_windowKey,onClose:()=>widget.onClose()));
  }
  @override
  Widget build(BuildContext context)=>Overlay(initialEntries:[entry]);
}

class _IntelligenceWindow extends ConsumerStatefulWidget {
  const _IntelligenceWindow({super.key,required this.onClose});
  final VoidCallback onClose;
  @override
  ConsumerState<_IntelligenceWindow> createState()=>_IntelligenceWindowState();
}
class _IntelligenceWindowState extends ConsumerState<_IntelligenceWindow>{
  bool minimized=false;
  Offset? position;
  void restore(){if(mounted)setState(()=>minimized=false);}
  @override
  Widget build(BuildContext context){
    final palette=ref.watch(selectedAppPaletteProvider);
    final media=MediaQuery.of(context);
    return LayoutBuilder(builder:(context,c){
      final w=c.maxWidth,h=c.maxHeight;
      // Leave the entire navigation bar exposed; keyboard inset takes precedence.
      final bottom=(media.viewInsets.bottom>0?media.viewInsets.bottom:media.padding.bottom+82)+12;
      final top=(media.padding.top+8).clamp(0.0,h).toDouble();
      final width=(w-24).clamp(0.0,470.0).toDouble();
      final height=(h-top-bottom-8).clamp(0.0,650.0).toDouble();
      final maxX=(w-width-12).clamp(0.0,w).toDouble();
      final maxY=(h-bottom-height).clamp(top,h).toDouble();
      final desired=position??Offset((w-width)/2,(top+maxY)/2);
      final actual=Offset(desired.dx.clamp(0.0,maxX).toDouble(),desired.dy.clamp(top,maxY).toDouble());
      return Stack(children:[
        Positioned(left:actual.dx,top:actual.dy,width:width,height:height,
          child:Visibility(visible:!minimized,maintainState:true,child:Material(
            elevation:18,shadowColor:palette.cardShadow,color:palette.surface,
            borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,
            child:IntelligenceChat(onClose:widget.onClose,onMinimize:()=>setState(()=>minimized=true),
              onDrag:(delta)=>setState(()=>position=actual+delta))))),
        if(minimized)Positioned(right:16,bottom:bottom,child:FloatingActionButton.extended(
          heroTag:null,onPressed:restore,backgroundColor:palette.primary,foregroundColor:palette.onPrimary,
          icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Asistente'))),
      ]);
    });
  }
}

class _Attachment {
  const _Attachment(this.kind,this.name,this.bytes);
  final String kind,name;
  final Uint8List bytes;
}

class IntelligenceChat extends ConsumerStatefulWidget {
  const IntelligenceChat({super.key,required this.onClose,required this.onMinimize,required this.onDrag});
  final VoidCallback onClose,onMinimize;
  final ValueChanged<Offset> onDrag;
  @override
  ConsumerState<IntelligenceChat> createState()=>_IntelligenceChatState();
}

class _IntelligenceChatState extends ConsumerState<IntelligenceChat> with WidgetsBindingObserver {
  final _text=TextEditingController(),_picker=ImagePicker(),_recorder=AudioRecorder();
  final List<({String role,String text})> _messages=[];
  final _scroll=ScrollController();
  final _composerFocus=FocusNode();
  bool _sending=false,_enterSends=true,_showHistory=false,_cancelRequested=false;
  String _partialAnswer='';
  final List<Map<String,dynamic>> _history=[];
  int? _historyOffset,_messageOffset;
  Future<void> _loadHistory({bool more=false}) async=>_run((e) async{
    final offset=more?_historyOffset:0;
    if(offset==null||_branch==null)return;
    final r=await ref.read(intelligenceApiProvider).history(_branch!,offset:offset);
    if(!_active(e))return;
    final rows=(r['items'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    setState((){
      if(!more)_history.clear();
      _history.addAll(rows.where((x)=>!_history.any((y)=>y['id']==x['id'])));
      _historyOffset=r['nextOffset'] as int?;
      _showHistory=true;
    });
  });
  Future<void> _openHistory(String id,{bool more=false}) async=>_run((e) async{
    if(_pendingAction!=null)return;
    final offset=more?_messageOffset:0;
    if(offset==null||_branch==null)return;
    final r=await ref.read(intelligenceApiProvider).history(_branch!,conversation:id,offset:offset);
    if(!_active(e))return;
    final rows=(r['items'] as List).reversed.map((x)=>(role:x['role'] as String,text:x['content'] as String)).toList();
    setState((){
      if(!more){_messages.clear();_exportPlan=null;_showAlerts=false;_forecastPlan=null;_showCatalogSync=false;_text.clear();_attachment=null;_pendingAction=null;_extracted='';_documentWarnings=[];_partialAnswer='';}
      _messages.insertAll(0,rows);_conversation=id;_messageOffset=r['nextOffset'] as int?;_showHistory=false;
    });
    if(!more)_scrollToEnd();
  });
  Widget _historyView(AppPalette palette,bool locked)=>ListView(padding:const EdgeInsets.all(12),children:[
    Row(children:[IconButton(tooltip:'Volver al chat',onPressed:locked?null:()=>setState(()=>_showHistory=false),icon:const Icon(Icons.arrow_back)),
      const Expanded(child:Text('Conversaciones anteriores',style:TextStyle(fontWeight:FontWeight.w700))),
      IconButton(tooltip:'Actualizar historial',onPressed:locked?null:()=>_loadHistory(),icon:const Icon(Icons.refresh))]),
    if(_history.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Aún no hay conversaciones guardadas.')),
    for(final row in _history)Card(color:palette.background,elevation:0,child:ListTile(
      leading:Icon(Icons.chat_bubble_outline,color:palette.secondary),
      title:Text(row['title']?.toString()??'Conversación',maxLines:2,overflow:TextOverflow.ellipsis),
      subtitle:Text((row['updatedAt']?.toString()??'').split('.').first,maxLines:1),
      trailing:const Icon(Icons.chevron_right),onTap:locked?null:()=>_openHistory(row['id'] as String))),
    if(_historyOffset!=null)TextButton(onPressed:locked?null:()=>_loadHistory(more:true),child:const Text('Ver más conversaciones')),
    if(_error.isNotEmpty)Text(_error,style:TextStyle(color:palette.danger)),
  ]);
  void _scrollToEnd(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted&&_scroll.hasClients)_scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }
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
        _messages.add((role:'assistant',text:answer));if(_messageOffset!=null)_messageOffset=_messageOffset!+2;_livePhase='Preparando respuesta de voz…';});
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
  List<String> _documentWarnings=[];
  Map<String,dynamic>? _pendingAction;
  Map<String,dynamic>? _exportPlan;
  bool _showAlerts=false;
  bool _showCatalogSync=false;
  Map<String,dynamic>? _forecastPlan;
  bool _actionSubmitting=false;
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
    _pcm.clear();_attachment=null;_pendingAction=null;_extracted='';_documentWarnings=[];_messages.clear();_exportPlan=null;_showAlerts=false;_forecastPlan=null;_showCatalogSync=false;_text.clear();
    if(mounted)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)widget.onClose();});
  }
  Future<void> _select(String kind,{bool camera=false}) async=>_run((e) async {
    final extensions=kind=='video'?['mp4','mov','webm']:kind=='photo'?['png','jpg','jpeg']:kind=='audio'?['wav']:['pdf','xlsx','csv','txt','png','jpg','jpeg'];
    final limit=(kind=='audio'?3:5)*1024*1024;
    try{
      String name;
      Uint8List bytes;
      if(camera&&_cameraAvailable){
        final file=kind=='video'?await _picker.pickVideo(source:ImageSource.camera,maxDuration:const Duration(seconds:30))
          :await _picker.pickImage(source:ImageSource.camera,maxWidth:2400,maxHeight:2400,imageQuality:82);
        if(file==null||!_active(e))return;
        name=file.name;
        if(await file.length()>limit)throw AttachmentReadException.tooLarge(limit);
        if(!_active(e))return;
        bytes=await file.readAsBytes();
      }else{
        // Browser file selections are not filesystem paths. Request the bytes
        // explicitly and avoid xFiles/path on the web. Native platforms retain
        // their ordinary path-based picker without eagerly loading large files.
        final selected=await FilePicker.platform.pickFiles(
          type:FileType.custom,allowedExtensions:extensions,withData:kIsWeb,
          allowMultiple:false);
        if(selected==null||selected.files.isEmpty||!_active(e))return;
        final picked=selected.files.first;
        name=picked.name;
        bytes=await readIntelligenceAttachment(picked,web:kIsWeb,limit:limit);
      }
      if(!_active(e))return;
      final validated=validateIntelligenceAttachment(kind,name,bytes,limit);
      setState((){_attachment=_Attachment(validated.kind,validated.name,bytes);_extracted='';_documentWarnings=[];});
      _scrollToEnd();
    }on AttachmentReadException catch(error){
      if(_active(e))setState(()=>_error=error.message);
    }on PlatformException catch(error){
      if(_active(e))setState(()=>_error=error.code.toLowerCase().contains('permission')||error.code.toLowerCase().contains('access')
        ?'No se concedió acceso al archivo o a la cámara. Revisa los permisos del dispositivo.'
        :'No fue posible abrir el selector de archivos. Intenta elegir una imagen PNG o JPEG.');
    }catch(_){
      if(_active(e))setState(()=>_error='No fue posible leer el archivo seleccionado. Intenta con otra imagen o archivo.');
    }
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
      if(_active(e))setState((){_attachment=_Attachment('audio','grabacion.wav',wav);_extracted='';_documentWarnings=[];});
    }catch(_){if(_active(e))setState(()=>_error='Graba entre 0,25 y 30 segundos.');}
    finally{if(_active(e))setState(()=>_busy=false);}
  }
  Future<void> _analyze() async=>_run((e) async{
    final a=_attachment;
    if(a==null||_branch==null)return;
    try{
      final result=await ref.read(intelligenceApiProvider).media(_branch!,a.kind,a.name,a.bytes);
      if(_active(e))setState((){_extracted=result['text']?.toString()??'';_documentWarnings=(result['warnings'] as List?)?.whereType<String>().toList()??[];});
    }catch(error){
      if(!_active(e))return;
      final status=error is AppException?error.statusCode:null;
      setState(()=>_error=switch(status){
        400||422=>'No se pudo interpretar el archivo. Comprueba que no esté dañado.',
        401=>'La sesión venció. Inicia sesión nuevamente.',
        403=>'No tienes permiso para analizar adjuntos en esta sucursal.',
        413=>'El archivo supera el límite admitido por el servidor.',
        415=>'El servidor no admite este formato de archivo.',
        429=>'El asistente está ocupado. Tu archivo sigue adjunto; puedes reintentar.',
        502||503||504=>'El análisis no está disponible o tardó demasiado. Tu archivo sigue adjunto.',
        _=>'No se pudo analizar el archivo. Tu adjunto se conserva para reintentar.'
      });
    }
  });
  Future<void> _reviewProductImport() async {
    final branch=_branch,e=_epoch;
    if(branch==null||_busy||_pendingAction!=null||_closed)return;
    final controller=TextEditingController(text:_extracted.length<=16000?_extracted:'');
    bool checked=false;
    String? reviewed;
    try{
      reviewed=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(ctx,localSetState)=>AlertDialog(
        title:const Text('Importar catálogo Excel/CSV'),
        content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Encabezado: producto;descripcion;marca_id;tipo_id;costo;precio. Máximo 25 productos normales, con marca y tipo existentes. Usa pesos enteros sin separadores.'),
          const Text('Los productos existentes se identifican por nombre exacto, marca y tipo. No cambia el stock, fotos ni recetas. Los precios nuevos conservan el historial.'),
          const SizedBox(height:8),
          TextField(controller:controller,maxLength:16000,minLines:4,maxLines:10,onChanged:(_)=>localSetState(()=>checked=false),
            decoration:const InputDecoration(labelText:'Catálogo revisado')),
          CheckboxListTile(contentPadding:EdgeInsets.zero,value:checked,onChanged:(v)=>localSetState(()=>checked=v==true),
            title:const Text('Revisé todos los productos, descripciones, identificadores y precios.')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.of(dialogContext).pop(),child:const Text('Cancelar')),
          FilledButton(onPressed:checked?()=>Navigator.of(dialogContext).pop(controller.text.trim()):null,child:const Text('Preparar borrador'))],
      )));
    }finally{controller.dispose();}
    if(reviewed==null||reviewed.isEmpty||!_active(e))return;
    final csv=reviewed;
    await _run((epoch) async{
      final draft=await ref.read(intelligenceApiProvider).prepareProductImport(branch,csv);
      if(!_active(epoch))return;
      if(draft['draftId'] is! String||draft['productImport'] is! Map)throw const FormatException('Borrador inválido');
      setState(()=>_pendingAction=draft);_scrollToEnd();
    });
  }
  Future<void> _reviewCountCsv() async {
    final branch=_branch,e=_epoch;
    if(branch==null||_busy||_pendingAction!=null||_closed)return;
    final initial=_extracted.trim();
    final controller=TextEditingController(text:initial.length<=8000?initial:'');
    bool checked=false;
    String? reviewed;
    try{
      reviewed=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(ctx,localSetState)=>AlertDialog(
        title:const Text('Importar conteo físico Excel/CSV'),
        content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Encabezado: producto;cantidad o producto_id;cantidad. Hasta 25 productos únicos, cantidades enteras desde cero. Usa nombres exactos de productos normales.'),
          const Text('Solo registra conteos de hoy. No sincroniza ni modifica el stock; si ya se contó un producto hoy, se rechazará la operación.'),
          const SizedBox(height:8),
          TextField(controller:controller,maxLength:8000,minLines:4,maxLines:10,
            onChanged:(_)=>localSetState(()=>checked=false),decoration:const InputDecoration(labelText:'CSV revisado',hintText:'producto;cantidad\\nPoker;12\\nCorona;0')),
          CheckboxListTile(contentPadding:EdgeInsets.zero,value:checked,onChanged:(v)=>localSetState(()=>checked=v==true),
            title:const Text('Revisé todos los nombres y cantidades del conteo actual.')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.of(dialogContext).pop(),child:const Text('Cancelar')),
          FilledButton(onPressed:checked?()=>Navigator.of(dialogContext).pop(controller.text.trim()):null,child:const Text('Preparar borrador'))],
      )));
    }finally{controller.dispose();}
    if(reviewed==null||reviewed.isEmpty||!_active(e))return;
    final csv=reviewed;
    await _run((epoch) async{
      final draft=await ref.read(intelligenceApiProvider).prepareCountCsv(branch,csv);
      if(!_active(epoch))return;
      if(draft['draftId'] is! String)throw const FormatException('Borrador inválido');
      setState(()=>_pendingAction=draft);_scrollToEnd();
    });
  }
  Future<void> _reviewPurchase() async {
    final branch=_branch,e=_epoch;
    if(branch==null||_extracted.isEmpty||_busy||_pendingAction!=null||_closed)return;
    await showDialog<void>(context:context,barrierDismissible:false,builder:(dialogContext)=>Dialog(
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[const Expanded(child:Padding(padding:EdgeInsets.all(12),child:Text('Revisión del documento'))),
          IconButton(onPressed:()=>Navigator.of(dialogContext).pop(),icon:const Icon(Icons.close))]),
        Flexible(child:SingleChildScrollView(child:IntelligencePurchaseReview(branch:branch,source:_extracted,onPrepare:(plan) async{
          if(!_active(e)||!dialogContext.mounted||_pendingAction!=null||_busy)throw StateError('Revisión no disponible');
          setState(()=>_busy=true);
          try{
            final draft=await ref.read(intelligenceApiProvider).prepareAction(branch,plan);
            if(!_active(e)||!dialogContext.mounted)throw StateError('Revisión cerrada');
            if(draft['draftId'] is! String||draft['documentPurchase'] is! Map)throw const FormatException('Borrador inválido');
            setState(()=>_pendingAction=draft);
            Navigator.of(dialogContext).pop();
            _scrollToEnd();
          }finally{if(_active(e))setState(()=>_busy=false);}
        }))),
      ])),
    ));
  }
  Future<void> _resolveAction(bool confirm) async {
    final pending=_pendingAction;
    final branch=_branch;
    if(pending==null||branch==null||_busy||_actionSubmitting)return;
    final id=pending['draftId'];
    if(id is! String)return;
    await _run((e) async {
      setState(()=>_actionSubmitting=true);
      try{
        final api=ref.read(intelligenceApiProvider);
        final result=confirm?await api.confirmAction(branch,id):await api.cancelAction(branch,id);
        if(!_active(e))return;
        final expected=confirm?'APPLIED':'CANCELLED';
        if(result['draftId']!=id||result['status']!=expected)throw const FormatException('Resultado no confirmado');
        if(confirm&&(pending['action']=='menu.personal_favorito'||pending['action']=='menu.personal_ubicacion'))ref.invalidate(menuPreferencesProvider);
        setState((){
          _pendingAction=null;
          if(confirm&&(pending['hasImage']==true||pending['documentPurchase'] is Map||pending['productImport'] is Map)){_attachment=null;_extracted='';_documentWarnings=[];}
          _messages.add((role:'assistant',text:confirm?(result['orderId']!=null?'Pedido ${result['orderId']} creado y confirmado por BarLytics. No se registró recepción ni pago.':'Acción ejecutada y confirmada por BarLytics.'):'Acción cancelada sin modificar los datos.'));
        });
        _scrollToEnd();
      }catch(error){
        if(!_active(e))return;
        final status=error is AppException?error.statusCode:null;
        setState((){
          _error=status==409?'El borrador venció, ya se cerró o los datos cambiaron. Revisa el estado en BarLytics.':
          'No se confirmó el resultado. No se reintentará automáticamente. Puedes consultar el estado o volver a confirmar el mismo borrador.';
        });
      }finally{if(_active(e))setState(()=>_actionSubmitting=false);}
    });
  }
  Future<void> _checkActionStatus() async {
    final branch=_branch,pending=_pendingAction;
    if(branch==null||pending==null||_busy||_actionSubmitting||_closed)return;
    final id=pending['draftId'];
    if(id is! String)return;
    await _run((e) async{
      final result=await ref.read(intelligenceApiProvider).actionStatus(branch,id);
      if(!_active(e)||_pendingAction?['draftId']!=id)return;
      if(result['draftId']!=id)throw const FormatException('Resultado no confirmado');
      final status=result['status'];
      if(!const {'PENDING','APPLIED','CANCELLED','EXPIRED'}.contains(status))throw const FormatException('Estado inválido');
      setState((){
        if(status!='PENDING'){
          _pendingAction=null;
          if(status=='APPLIED'&&(pending['hasImage']==true||pending['documentPurchase'] is Map||pending['productImport'] is Map)){
            _attachment=null;_extracted='';_documentWarnings=[];
          }
        }
        _error='';
        _messages.add((role:'assistant',text:status=='APPLIED'?'BarLytics confirma que la operación ya fue aplicada. No se ejecutó de nuevo.':
          status=='CANCELLED'?'BarLytics confirma que el borrador fue cancelado.':
          status=='EXPIRED'?'El borrador venció sin ejecutarse. Prepara una nueva acción.':
          'La operación sigue pendiente; todavía no ha sido aplicada.'));
      });
      if(status=='APPLIED'&&(pending['action']=='menu.personal_favorito'||pending['action']=='menu.personal_ubicacion'))ref.invalidate(menuPreferencesProvider);
      _scrollToEnd();
    });
  }
  Widget _actionCard(bool locked){
    final p=_pendingAction!;
    final changes=p['changes'];
    final replenishment=p['replenishment'];
    final purchase=p['documentPurchase'];
    final catalog=p['productImport'];
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(p['steps'] is List?'Confirmar todas las operaciones':'Confirmar operación',style:const TextStyle(fontWeight:FontWeight.bold)),
      ConstrainedBox(constraints:const BoxConstraints(maxHeight:240),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(p['effect'].toString()),
        Text('Registro: ${p['target']}'),
        if(changes is Map)for(final entry in changes.entries)SelectableText('${entry.key}: ${entry.value}'),
        if(catalog is Map)...[
          Text('Crear: ${catalog['creates']} · Actualizar: ${catalog['updates']} · Sin cambios: ${catalog['unchanged']}'),
          if(catalog['products'] is List)for(final row in catalog['products'])if(row is Map)...[
            const Divider(),
            Text('${row['name']} · ${row['action']}',style:const TextStyle(fontWeight:FontWeight.w600)),
            Text('${row['brand']} / ${row['type']}'),
            if(row['previousDescription']!=null&&row['previousDescription']!=row['description'])Text("Descripción anterior: ${row['previousDescription']}"),
            Text('${row['description']}'),
            Text("Costo: ${row['previousCost']??'—'} → ${row['cost']}"),
            Text("Venta: ${row['previousSale']??'—'} → ${row['sale']}"),
          ],
          const Text('Se aplicará en una transacción. No modifica existencias.'),
        ],
        if(purchase is Map)...[
          Text('Proveedor: ${purchase['supplier']}'),
          Text('Referencia: ${purchase['reference']}'),
          if(purchase['lines'] is List)for(final line in purchase['lines'])if(line is Map)...[
            const Divider(),
            Text('${line['product']} — ${line['units']} ${line['baseUnit']}'),
            Text('${line['packs']} × ${line['presentation']} de ${line['unitsPerPack']} · costo por presentación ${line['costPerPack']}'),
            Text('Subtotal estimado: ${line['subtotal']}'),
          ],
          Text('Total estimado: ${purchase['total']}',style:const TextStyle(fontWeight:FontWeight.bold)),
          const Text('Usa el costo registrado en BarLytics. No contabiliza una factura, no recibe existencias ni registra pagos.'),
        ],
        if(replenishment is Map)...[
          Text('Costo estimado total: ${replenishment['totalEstimado']}',style:const TextStyle(fontWeight:FontWeight.w600)),
          if(replenishment['orders'] is List)for(final order in replenishment['orders'])
            if(order is Map)...[
              const Divider(),
              Text('${order['proveedor']} · ${order['totalEstimado']}',style:const TextStyle(fontWeight:FontWeight.w600)),
              if(order['productos'] is List)for(final product in order['productos'])
                if(product is Map)Text('${product['producto']} — ${product['unidades']} unidades · ${product['subtotalEstimado']}'),
            ],
          if(replenishment['excluded'] is List&&(replenishment['excluded'] as List).isNotEmpty)...[
            const Divider(),const Text('Productos excluidos',style:TextStyle(fontWeight:FontWeight.w600)),
            for(final item in replenishment['excluded'])if(item is Map)Text('${item['producto']}: ${item['motivo']}'),
          ],
          const Text('El servidor volverá a comprobar la reposición al confirmar. No se enviarán pedidos por WhatsApp ni se recibirá inventario.'),
        ],
        if(replenishment is! Map&&p['steps'] is List)for(final entry in (p['steps'] as List).asMap().entries)
          if(entry.value is Map) ...[
            const Divider(),
            Text('${entry.key+1}. ${entry.value['effect']}',style:const TextStyle(fontWeight:FontWeight.w600)),
            Text('Registro: ${entry.value['target']}'),
            if(entry.value['changes'] is Map)for(final field in (entry.value['changes'] as Map).entries)
              SelectableText('${field.key}: ${field.value}'),
          ],
        if(p['steps'] is List)const Text('Se aplicarán juntas o se revertirán si alguna falla.'),
        if(p['hasImage']==true)const Text('Se asociará únicamente la imagen adjunta al destino indicado.'),
        const Text('El borrador vence en 10 minutos.'),
      ]))),
      Wrap(spacing:8,children:[
        OutlinedButton(onPressed:locked||_actionSubmitting?null:()=>_resolveAction(false),child:const Text('Cancelar')),
        OutlinedButton(onPressed:locked||_actionSubmitting?null:_checkActionStatus,child:const Text('Consultar estado')),
        FilledButton(onPressed:locked||_actionSubmitting?null:()=>_resolveAction(true),child:const Text('Confirmar y ejecutar')),
      ])
    ])));
  }
  Future<void> _send() => _sendMessage();
  Future<void> _sendMessage({int? retryIndex}) async {
    if(retryIndex!=null&&(retryIndex!=_messages.length-1||retryIndex<0||_messages[retryIndex].role!='failed'))return;
    final text=retryIndex==null?_text.text.trim():_messages[retryIndex].text;
    if(_busy||_recording||_live||_closed||_branch==null||text.isEmpty||text.length>2000)return;
    if(_pendingAction!=null){setState(()=>_error='Confirma o cancela primero la acción pendiente.');return;}
    await _run((e) async {
      final index=retryIndex??_messages.length;
      setState((){
        _sending=true;_cancelRequested=false;_partialAnswer='';_exportPlan=null;_showAlerts=false;_forecastPlan=null;_showCatalogSync=false;
        if(retryIndex==null){
          _messages.add((role:'user',text:text));
          _text.clear();
        }else{
          _messages[index]=(role:'user',text:text);
        }
      });
      _scrollToEnd();
      try{
        final router=ref.read(appRouterProvider);
        final destination=AssistantNavigation.requestedDestination(text);
        if(destination!=null){
          // Refresh actual menu permissions at the time of navigation.
          ref.invalidate(userMenuProvider);
          final allowed=await ref.read(userMenuProvider.future);
          if(!_active(e))return;
          final item=AssistantNavigation.resolve(destination,allowed);
          if(item!=null){
            router.go(item.path);
            setState(()=>_messages.add((role:'assistant',text:'Abriendo ${item.title} desde tu menú autorizado.')));
            return;
          }
          // No coincidencia literal: Intelligence puede resolver la intención mediante el catálogo.
        }
        final allowed=await ref.read(userMenuProvider.future);
        if(!_active(e))return;
        final normalized=AssistantNavigation.normalize(text);
        if(const {'regresa','regresar','vuelve','volver','regresa al menu anterior','vuelve al menu anterior','atras'}.contains(normalized)){
          if(router.canPop()){router.pop();setState(()=>_messages.add((role:'assistant',text:'Volví a la pantalla anterior.')));}
          else{setState(()=>_messages.add((role:'assistant',text:'No hay una pantalla anterior disponible.')));}
          return;
        }
        final routeModule=AssistantNavigation.context(router.routerDelegate.currentConfiguration.uri.path,allowed);
        final module=ref.read(assistantScreenContextProvider).resolve(routeModule,_branch!);
        final reply=await ref.read(intelligenceApiProvider).chatProgressive(_branch!,_conversation,text,
          currentModule:module.isEmpty?null:module,
          menuCatalog:allowed.take(100).map((item)=><String,String>{'key':item.keyName,'title':item.title.length>100?item.title.substring(0,100):item.title}).toList(),
          isActive:()=>_active(e),shouldCancel:()=>_cancelRequested,
          onPartial:(value){if(_active(e)){setState(()=>_partialAnswer=value);_scrollToEnd();}});
        if(!_active(e))return;
        final id=reply['conversationId'],answer=reply['answer'];
        if(id is! String||answer is! String)throw StateError('Respuesta inválida');
        var finalAnswer=answer;
        if(reply['catalogSyncPanel']==true&&!_cancelRequested)setState(()=>_showCatalogSync=true);
        if(reply['alerts']==true&&!_cancelRequested)setState(()=>_showAlerts=true);
        final forecast=reply['forecast'];
        if(forecast is Map&&!_cancelRequested)setState(()=>_forecastPlan=Map<String,dynamic>.from(forecast));
        final export=reply['export'];
        if(export is Map&&!_cancelRequested)setState(()=>_exportPlan=Map<String,dynamic>.from(export));
        final action=reply['action'];
        if(action is Map&&!_cancelRequested){
          final plan=Map<String,dynamic>.from(action);
          final attachment=_attachment;
          final needsImage=const {'producto.imagen','sucursal.imagen','medio_pago.imagen_qr'}.contains(plan['action']);
          if(needsImage&&(attachment==null||attachment.kind!='photo')){
            finalAnswer='Adjunta la imagen JPEG o PNG correspondiente y vuelve a solicitar la operación.';
          }else{
            final draft=await ref.read(intelligenceApiProvider).prepareAction(_branch!,plan,image:needsImage?attachment!.bytes:null);
            if(!_active(e)||_cancelRequested)return;
            if(draft['draftId'] is! String||draft['effect'] is! String||draft['target'] is! String)throw const FormatException('Borrador inválido');
            setState(()=>_pendingAction=draft);
            finalAnswer=draft['steps'] is List?'Revisa todas las operaciones del lote antes de confirmar. No se han modificado datos.':'Revisa la acción preparada en BarLytics. No se han modificado datos todavía.';
          }
        }
        final navigation=reply['navigation'];
        if(navigation is String){
          ref.invalidate(userMenuProvider);
          final refreshed=await ref.read(userMenuProvider.future);
          if(!_active(e)||_cancelRequested)return;
          final item=AssistantNavigation.resolveKey(navigation,refreshed);
          if(item==null){finalAnswer='La opción solicitada no está disponible en tu menú actual.';}
          else{router.go(item.path);finalAnswer='Abriendo ${item.title} desde tu menú autorizado.';}
        }
        setState((){_conversation=id;_partialAnswer='';_messages.add((role:'assistant',text:finalAnswer));if(_messageOffset!=null)_messageOffset=_messageOffset!+2;});
      }catch(error){
        if(!_active(e))return;
        setState((){
          // Keep the failed message visible; retry is explicit, never automatic.
          _messages[index]=(role:'failed',text:text);
          final status=error is AppException?error.statusCode:null;
          _error=switch(status){
            400||422=>'No se pudo procesar la consulta. Revisa los datos.',
            401=>'Sesión vencida. Inicia sesión nuevamente.',
            403=>'No tienes acceso al asistente en esta sucursal.',
            404=>'La conversación o el servicio no está disponible. Puedes iniciar una nueva conversación.',
            429=>'El asistente está ocupado. Intenta nuevamente.',
            502||503||504=>'El asistente no está disponible o tardó demasiado. Intenta nuevamente.',
            _=>'No se confirmó una respuesta del servidor. Tu mensaje permanece en el chat.'
          };
          if(error is AppException&&error.code=='CHAT_CANCELLED')_error='Generación cancelada. La respuesta parcial no fue guardada.';
          if(status!=null)_error+=' (HTTP $status)';
        });
      }finally{
        if(_active(e)){
          setState(()=>_sending=false);
          _scrollToEnd();
        }
      }
    });
    if(mounted&&!_closed&&!_busy&&!_live&&!_recording&&
       (kIsWeb||{TargetPlatform.windows,TargetPlatform.macOS,TargetPlatform.linux}.contains(defaultTargetPlatform))){
      WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&!_closed&&!_busy)_composerFocus.requestFocus();});
    }
  }
  Widget _messageBubble(int index,AppPalette palette,bool locked){
    final m=_messages[index],failed=m.role=='failed',isUser=m.role!='assistant';
    return Align(alignment:isUser?Alignment.centerRight:Alignment.centerLeft,child:Container(
      margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),
      constraints:const BoxConstraints(maxWidth:540),
      decoration:BoxDecoration(color:isUser?palette.primary.withOpacity(.16):palette.background,borderRadius:BorderRadius.circular(16)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        SelectableText(m.text,style:TextStyle(color:palette.textPrimary)),
        if(failed)...[
          const SizedBox(height:6),
          Text('Respuesta no confirmada',style:TextStyle(color:palette.danger,fontSize:11)),
          if(index==_messages.length-1)TextButton.icon(
            onPressed:locked?null:()=>_sendMessage(retryIndex:index),
            icon:const Icon(Icons.refresh,size:16),label:const Text('Reintentar')),
        ],
      ]),
    ));
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _closed=true;_epoch++;_liveEpoch++;_liveTimeout?.cancel();_timer?.cancel();
    unawaited(_liveSubscription?.cancel()??Future<void>.value());unawaited(_player.dispose());
    unawaited(_audioSubscription?.cancel()??Future<void>.value());
    unawaited(_recorder.dispose());_scroll.dispose();_composerFocus.dispose();_text.dispose();_pcm.clear();super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final palette=ref.watch(selectedAppPaletteProvider);
    final branch=ref.watch(branchScopeProvider).activeBranch;
    ref.listen(authControllerProvider,(prev,next){if(!next.authenticated||!next.subscriptionActive)_invalidate();});
    ref.listen(branchScopeProvider,(prev,next){if(next.activeBranchId!=_branch)_invalidate();});
    ref.listen(selectedRolesProvider,(prev,next){if(prev!=next)_invalidate();});
    final locked=_busy||_recording||_live;
    return Material(color:palette.surface,child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),child:Row(children:[
          CircleAvatar(backgroundColor:palette.primary,child:Icon(Icons.auto_awesome_rounded,color:palette.onPrimary)),
          const SizedBox(width:8),Expanded(child:GestureDetector(
            behavior:HitTestBehavior.opaque,onPanUpdate:(d)=>widget.onDrag(d.delta),
            child:MouseRegion(cursor:SystemMouseCursors.move,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Inteligencia BarLytics',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.w800,fontSize:15)),
              Row(children:[
                Icon(Icons.drag_indicator_rounded,size:13,color:palette.textSecondary),
                Expanded(child:Text(branch?.label()??'Sucursal no disponible',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:palette.textSecondary,fontSize:11))),
              ]),
              Text('Arrastra para mover',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:palette.textSecondary,fontSize:10)),
            ])))),
          IconButton(tooltip:'Historial de conversaciones',onPressed:locked||_pendingAction!=null?null:()=>_loadHistory(),icon:const Icon(Icons.history_rounded,size:20)),
          IconButton(tooltip:'Nueva conversación',onPressed:locked||_pendingAction!=null?null:()=>setState((){_conversation=null;_messages.clear();_exportPlan=null;_showAlerts=false;_forecastPlan=null;_showCatalogSync=false;_messageOffset=null;_showHistory=false;_partialAnswer='';_attachment=null;_pendingAction=null;_extracted='';_documentWarnings=[];_text.clear();_error='';}),icon:const Icon(Icons.add_comment_rounded,size:20)),
          IconButton(tooltip:'Minimizar chat',onPressed:_recording||_live?null:(){_composerFocus.unfocus();widget.onMinimize();},icon:const Icon(Icons.minimize_rounded,size:20)),
          IconButton(tooltip:'Cerrar chat',onPressed:_invalidate,icon:const Icon(Icons.close,size:20))])),
        if(_busy)const LinearProgressIndicator(),
        if(_live)Container(padding:const EdgeInsets.all(14),color:palette.primary.withOpacity(.10),child:Row(children:[
          CircleAvatar(radius:25,backgroundColor:palette.primary,child:Icon(Icons.graphic_eq,color:palette.onPrimary)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_livePhase,style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.bold)),
            const Text('Voz continua · micrófono activo solo al escuchar') ])),
          IconButton(tooltip:'Finalizar voz continua',onPressed:()=>unawaited(_endLive()),icon:Icon(Icons.call_end,color:palette.danger))
        ])),
        Expanded(child:_showHistory?_historyView(palette,locked):ListView(controller:_scroll,padding:const EdgeInsets.all(12),children:[
          if(_messageOffset!=null&&_conversation!=null)TextButton(onPressed:locked?null:()=>_openHistory(_conversation!,more:true),child:const Text('Cargar mensajes anteriores')),
          if(_messages.isEmpty)const Center(child:Padding(padding:EdgeInsets.symmetric(vertical:32),child:Text('¿En qué puedo ayudarte hoy?\nConsulta o adjunta un archivo para revisar su contenido.',textAlign:TextAlign.center))),
          for(var i=0;i<_messages.length;i++) _messageBubble(i,palette,locked),
          if(_partialAnswer.isNotEmpty)Align(alignment:Alignment.centerLeft,child:Container(
            margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),
            constraints:const BoxConstraints(maxWidth:540),decoration:BoxDecoration(color:palette.background,borderRadius:BorderRadius.circular(16)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              SelectableText(_partialAnswer,style:TextStyle(color:palette.textPrimary)),
              if(!_sending)Text('Respuesta parcial no confirmada',style:TextStyle(color:palette.warning,fontSize:11)),
            ]))),
          if(_sending)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(children:[
            const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)),const SizedBox(width:10),
            Expanded(child:Text(_cancelRequested?'Solicitando cancelación…':_partialAnswer.isEmpty?'Intelligence está preparando la respuesta…':'Generando respuesta…')),
          ])),
          if(_pendingAction!=null)_actionCard(locked),
          if(_showCatalogSync&&_branch!=null)ConstrainedBox(constraints:const BoxConstraints(maxHeight:420),child:SingleChildScrollView(child:IntelligenceCatalogSyncCard(branch:_branch!,initiallyExpanded:true))),
          if(_forecastPlan!=null&&_branch!=null)ConstrainedBox(constraints:const BoxConstraints(maxHeight:420),child:SingleChildScrollView(child:IntelligenceForecastCard(key:ValueKey(_forecastPlan),branch:_branch!,initialPlan:_forecastPlan))),
          if(_showAlerts&&_branch!=null)ConstrainedBox(constraints:const BoxConstraints(maxHeight:300),child:SingleChildScrollView(child:IntelligenceAlertsCard(branch:_branch!,initiallyExpanded:true))),
          if(_exportPlan!=null&&_branch!=null)IntelligenceExportCard(branch:_branch!,plan:_exportPlan!,disabled:locked),
          if(_attachment!=null)Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.attach_file),Expanded(child:Text(_attachment!.name,maxLines:1,overflow:TextOverflow.ellipsis)),
              IconButton(tooltip:'Quitar adjunto',onPressed:locked?null:()=>setState((){_attachment=null;_extracted='';_documentWarnings=[];}),icon:const Icon(Icons.close))]),
            if(_attachment!.kind=='photo')ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.memory(_attachment!.bytes,height:120,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('Vista previa no disponible'))),
            if(_attachment!.kind=='video')const Text('Análisis experimental: hasta 30 segundos y 5 MiB. Se examinan tres fotogramas, sin audio. Solo disponible si el servidor lo habilita.'),
            OutlinedButton(onPressed:locked?null:_analyze,child:Text(_attachment!.kind=='video'?'Analizar fotogramas':'Extraer contenido')),
            if(_extracted.isNotEmpty)...[for(final warning in _documentWarnings)Text(warning,style:TextStyle(color:palette.warning)),SelectableText(_extracted),
              if(_attachment!.kind=='file'||_attachment!.kind=='photo')
                OutlinedButton.icon(onPressed:locked||_pendingAction!=null?null:_reviewPurchase,icon:const Icon(Icons.receipt_long),label:const Text('Preparar pedido desde documento')),
              if(_attachment!.kind=='file'&&['.csv','.xlsx'].any((ext)=>_attachment!.name.toLowerCase().endsWith(ext)))
                OutlinedButton.icon(onPressed:locked||_pendingAction!=null?null:_reviewCountCsv,icon:const Icon(Icons.fact_check_outlined),label:const Text('Importar conteo físico CSV')),
              if(_attachment!.kind=='file'&&['.csv','.xlsx'].any((ext)=>_attachment!.name.toLowerCase().endsWith(ext)))
                OutlinedButton.icon(onPressed:locked||_pendingAction!=null?null:_reviewProductImport,icon:const Icon(Icons.inventory_2_outlined),label:const Text('Importar catálogo y precios')),
              if(_attachment!.kind!='video')TextButton(onPressed:locked?null:(){
              final combined=[_text.text.trim(),_extracted].where((x)=>x.isNotEmpty).join('\n\n');
              if(combined.length>2000){setState(()=>_error='Copia un fragmento de hasta 2000 caracteres para enviar.');return;}
              setState(()=>_text.text=combined);
            },child:const Text('Usar texto revisado en el chat'))]
          ]))),
          if(_error.isNotEmpty)Text(_error,style:TextStyle(color:palette.danger)),
        ])),
        if(!_showHistory)Padding(padding:const EdgeInsets.fromLTRB(10,4,10,8),child:Column(children:[
          IntelligenceComposer(controller:_text,focusNode:_composerFocus,enabled:!locked,enterSends:_enterSends,onSend:_send),
          Row(children:[
            MenuAnchor(
              menuChildren:[
                MenuItemButton(leadingIcon:const Icon(Icons.camera_alt_outlined),onPressed:()=>_select('photo',camera:true),child:Text(_cameraAvailable?'Tomar foto':'Adjuntar foto')),
                MenuItemButton(leadingIcon:const Icon(Icons.image_outlined),onPressed:()=>_select('photo'),child:const Text('Elegir imagen')),
                MenuItemButton(leadingIcon:const Icon(Icons.description_outlined),onPressed:()=>_select('file'),child:const Text('Documento')),
                MenuItemButton(leadingIcon:const Icon(Icons.videocam_outlined),onPressed:()=>_select('video',camera:true),child:Text(_cameraAvailable?'Grabar vídeo':'Adjuntar vídeo')),
                MenuItemButton(leadingIcon:const Icon(Icons.video_file_outlined),onPressed:()=>_select('video'),child:const Text('Elegir vídeo')),
                MenuItemButton(leadingIcon:const Icon(Icons.audio_file_outlined),onPressed:()=>_select('audio'),child:const Text('Archivo WAV')),
              ],builder:(context,controller,child)=>IconButton(tooltip:'Adjuntar contenido',onPressed:locked?null:(){controller.isOpen?controller.close():controller.open();},icon:const Icon(Icons.add_circle_outline_rounded))),
            IconButton(tooltip:_recording?'Detener audio':'Grabar nota de voz',onPressed:_busy||_live?null:_recording?_stopAudio:_startAudio,icon:Icon(_recording?Icons.stop_circle_rounded:Icons.mic_none_rounded,color:_recording?palette.danger:palette.secondary)),
            MenuAnchor(menuChildren:[
              MenuItemButton(leadingIcon:Icon(_enterSends?Icons.check:Icons.keyboard_return),onPressed:()=>setState(()=>_enterSends=true),child:const Text('Enter para enviar')),
              MenuItemButton(leadingIcon:Icon(!_enterSends?Icons.check:Icons.keyboard_return),onPressed:()=>setState(()=>_enterSends=false),child:const Text('Enter para nueva línea')),
            ],builder:(context,controller,child)=>IconButton(tooltip:'Configuración de envío',onPressed:locked?null:(){controller.isOpen?controller.close():controller.open();},icon:const Icon(Icons.tune_rounded,size:20))),
            const Spacer(),
            IconButton.filledTonal(tooltip:'Conversación por voz continua',onPressed:locked||_branch==null?null:_startLive,icon:const Icon(Icons.graphic_eq_rounded)),
            const SizedBox(width:6),
            IconButton.filled(tooltip:_sending?'Detener generación':'Enviar mensaje',
              onPressed:_sending?(_cancelRequested?null:()=>setState(()=>_cancelRequested=true)):locked||_branch==null?null:_send,
              icon:Icon(_sending?Icons.stop_rounded:Icons.arrow_upward_rounded)),
          ]),if(_recording)const Text('Grabando audio · máximo 30 segundos'),
          if(_enterSends)const Align(alignment:Alignment.centerLeft,child:Text('Enter: enviar · Shift + Enter: nueva línea',style:TextStyle(fontSize:10))),
          const Text('Revisa los adjuntos antes de enviarlos. No se ejecutan operaciones comerciales desde este chat.',textAlign:TextAlign.center,style:TextStyle(fontSize:10))
        ]))
      ]));
  }
}
