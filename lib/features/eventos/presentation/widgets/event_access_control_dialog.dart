import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/eventos_api.dart';
import 'event_access_qr.dart';

const accessBg=Color(0xFF0C2837), accessCard=Color(0xFF143748);
const accessText=Color(0xFFEAF8FC), accessMuted=Color(0xFFB4CAD2);
const accessAccent=Color(0xFF32CCC4);

/// Escanear solo consulta: requiere confirmación explícita para registrar ingreso.
class EventAccessControlDialog extends ConsumerStatefulWidget {
  const EventAccessControlDialog({super.key,required this.eventId,required this.title});
  final int eventId;
  final String title;
  @override ConsumerState<EventAccessControlDialog> createState()=>_EventAccessState();
}

class _EventAccessState extends ConsumerState<EventAccessControlDialog>{
  final filter=TextEditingController(),qrInput=TextEditingController();
  final scanner=MobileScannerController(autoStart:false,
    detectionSpeed:DetectionSpeed.noDuplicates,formats:[BarcodeFormat.qrCode]);
  Map<String,dynamic>? overview,preview,result;
  String? token,error;
  bool loading=true,busy=false,scanning=false;
  bool get cameraSupported=>kIsWeb||
    defaultTargetPlatform==TargetPlatform.iOS||
    defaultTargetPlatform==TargetPlatform.android||
    defaultTargetPlatform==TargetPlatform.macOS;

  @override void initState(){
    super.initState();
    filter.addListener(_rebuild);
    reload();
  }
  void _rebuild(){if(mounted)setState((){});}
  @override void dispose(){
    filter.removeListener(_rebuild);
    filter.dispose();qrInput.dispose();scanner.dispose();
    super.dispose();
  }

  Future<void> reload()async{
    try{
      final data=await ref.read(eventosApiProvider).ingresosEvento(widget.eventId);
      if(mounted)setState((){overview=data;loading=false;error=null;});
    }catch(e){
      if(mounted)setState((){
        loading=false;error='No fue posible consultar las entradas: $e';
      });
    }
  }
  Future<void> toggleScanner()async{
    if(!cameraSupported||busy)return;
    if(scanning){
      await scanner.stop();
      if(mounted)setState(()=>scanning=false);
      return;
    }
    setState((){scanning=true;preview=null;result=null;error=null;});
    await Future<void>.delayed(Duration.zero);
    try{await scanner.start();}
    catch(e){
      if(mounted)setState((){
        scanning=false;
        error='No se pudo abrir la cámara. Revisa permisos o utiliza ingreso manual.';
      });
    }
  }
  Future<void> readQr(String raw)async{
    if(busy)return;
    final parsed=extractEventEntryToken(raw);
    if(parsed==null){
      setState(()=>error='QR inválido: se requiere el código personal de una entrada.');
      return;
    }
    setState((){busy=true;error=null;preview=null;result=null;token=null;});
    if(scanning){
      await scanner.stop();
      if(mounted)setState(()=>scanning=false);
    }
    try{
      final info=await ref.read(eventosApiProvider)
        .consultarEntradaQr(widget.eventId,parsed);
      if(mounted)setState((){preview=info;token=parsed;});
    }catch(e){
      if(mounted)setState((){
        error='El QR no corresponde a una entrada de este evento.';
      });
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> confirmQr()async{
    if(busy||token==null||preview?['puedeIngresar']!=true)return;
    setState((){busy=true;error=null;});
    try{
      final data=await ref.read(eventosApiProvider).validarEntradaQr(widget.eventId,token!);
      if(mounted)setState((){result=data;preview=null;token=null;});
      await reload();
    }catch(e){
      if(mounted)setState((){
        error='Ingreso rechazado. La entrada pudo haber sido utilizada: $e';
        preview=null;token=null;
      });
      await reload();
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> markManual(Map<String,dynamic> entry)async{
    final id=(entry['entradaId'] as num?)?.toInt();
    if(id==null||busy||entry['ingreso']!=null)return;
    if(entry['estadoReserva']!='CONFIRMADA'||entry['retirada']==true)return;
    final approved=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('Confirmar ingreso manual'),
      content:Text('¿Ingresó ${entry['nombre']}? Entrada ${entry['numero']} · '
        'Mesa ${entry['mesa']}.\nSe registrarán fecha, hora y responsable.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),
          child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),
          child:const Text('Confirmar ingreso')),
      ],
    ));
    if(approved!=true||!mounted)return;
    setState((){busy=true;error=null;result=null;});
    try{
      final data=await ref.read(eventosApiProvider)
        .registrarIngresoManual(widget.eventId,id);
      if(mounted)setState(()=>result=data);
      await reload();
    }catch(e){
      if(mounted)setState(()=>error='No se pudo registrar el ingreso: $e');
      await reload();
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Widget status(Map<String,dynamic> data,{required String heading,required Color color}){
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:accessCard,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:color)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(heading,style:TextStyle(color:color,fontWeight:FontWeight.w800)),
        Text('${data['nombre']??'Asistente'} · Entrada ${data['numero']??'-'}',
          style:const TextStyle(color:accessText,fontSize:15)),
        Text('Mesa ${data['mesa']??'-'}'
          '${data['silla']==null?'':' · Puesto '+data['silla'].toString()}',
          style:const TextStyle(color:accessMuted)),
        if(data['ingreso']!=null)
          Text('Registrada: ${data['ingreso']} · ${data['ingresoPor']??''}',
            style:const TextStyle(color:accessMuted)),
      ]),
    );
  }

  @override Widget build(BuildContext context){
    final entries=(overview?['entradas'] as List? ??const [])
      .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
    final query=filter.text.trim().toLowerCase();
    final filtered=entries.where((r)=>query.isEmpty||
      ('${r['nombre']??''} ${r['email']??''} ${r['reservaId']??''} '
       '${r['entradaId']??''} ${r['mesa']??''}')
        .toLowerCase().contains(query)).toList();
    return Dialog(
      backgroundColor:accessBg,
      insetPadding:const EdgeInsets.all(12),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:850,
          maxHeight:MediaQuery.sizeOf(context).height*.94),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Padding(padding:const EdgeInsets.fromLTRB(17,13,9,9),
            child:Row(children:[
              const Icon(Icons.qr_code_scanner,color:accessAccent,size:26),
              const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Control de ingreso',style:TextStyle(
                  color:accessText,fontSize:20,fontWeight:FontWeight.w900)),
                Text(widget.title,style:const TextStyle(color:accessMuted),
                  maxLines:1,overflow:TextOverflow.ellipsis),
              ])),
              IconButton(onPressed:()=>Navigator.pop(context),
                icon:const Icon(Icons.close,color:accessText)),
            ])),
          Flexible(child:SingleChildScrollView(
            padding:const EdgeInsets.all(17),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              if(loading)const Center(child:CircularProgressIndicator()),
              if(overview!=null)Wrap(spacing:8,runSpacing:8,children:[
                for(final pair in [
                  ('Total',overview!['total']),
                  ('Habilitadas',overview!['habilitadas']),
                  ('Ingresaron',overview!['ingresadas']),
                  ('Pendientes',overview!['pendientes']),
                ])
                  Chip(label:Text('${pair.$1}: ${pair.$2}',
                    style:const TextStyle(color:accessText,fontWeight:FontWeight.bold)),
                    backgroundColor:accessCard),
              ]),
              const SizedBox(height:13),
              if(cameraSupported)FilledButton.icon(
                key:const Key('access-camera'),
                onPressed:busy?null:toggleScanner,
                icon:Icon(scanning?Icons.stop_circle_outlined:Icons.camera_alt_outlined),
                label:Text(scanning?'Detener cámara':'Escanear QR'),
                style:FilledButton.styleFrom(backgroundColor:accessAccent,
                  foregroundColor:accessBg,padding:const EdgeInsets.all(15)),
              )else const Text('Sin cámara en esta plataforma. Usa ingreso manual.',
                style:TextStyle(color:accessMuted)),
              if(scanning)...[
                const SizedBox(height:11),
                ClipRRect(borderRadius:BorderRadius.circular(12),
                  child:SizedBox(height:235,child:MobileScanner(
                    controller:scanner,
                    onDetect:(capture){
                      if(busy||capture.barcodes.isEmpty)return;
                      final scanned=capture.barcodes.first.rawValue;
                      if(scanned!=null)readQr(scanned);
                    },
                  ))),
                const Text('Apunta a un QR individual del evento.',
                  style:TextStyle(color:accessMuted)),
              ],
              const SizedBox(height:10),
              TextField(
                key:const Key('access-paste-qr'),
                controller:qrInput,
                style:const TextStyle(color:accessText),
                onSubmitted:readQr,
                decoration:InputDecoration(
                  labelText:'Pegar enlace o código QR',
                  labelStyle:const TextStyle(color:accessMuted),
                  border:const OutlineInputBorder(),
                  suffixIcon:IconButton(
                    tooltip:'Consultar QR',
                    onPressed:busy?null:()=>readQr(qrInput.text),
                    icon:const Icon(Icons.search,color:accessAccent)),
                )),
              if(error!=null)Padding(
                padding:const EdgeInsets.symmetric(vertical:10),
                child:Text(error!,style:const TextStyle(color:Colors.orangeAccent))),
              if(result!=null)...[
                const SizedBox(height:10),
                status(result!,heading:'Ingreso confirmado',color:Colors.greenAccent),
              ],
              if(preview!=null)...[
                const SizedBox(height:10),
                status(preview!,
                  heading:preview!['yaIngreso']==true?'Esta entrada ya ingresó':
                    preview!['puedeIngresar']==true?'Entrada válida':'Entrada no habilitada',
                  color:preview!['puedeIngresar']==true?Colors.greenAccent:
                    Colors.orangeAccent),
                if(preview!['puedeIngresar']==true)
                  FilledButton.icon(
                    key:const Key('access-confirm-qr'),
                    onPressed:busy?null:confirmQr,
                    icon:const Icon(Icons.verified_user_outlined),
                    label:const Text('Confirmar ingreso')),
              ],
              const SizedBox(height:24),
              Row(children:[
                const Expanded(child:Text('Ingreso manual por persona',
                  style:TextStyle(color:accessText,fontSize:17,
                    fontWeight:FontWeight.w800))),
                IconButton(onPressed:busy?null:reload,tooltip:'Actualizar',
                  icon:const Icon(Icons.refresh,color:accessAccent)),
              ]),
              TextField(
                key:const Key('access-search'),
                controller:filter,style:const TextStyle(color:accessText),
                decoration:const InputDecoration(
                  hintText:'Buscar nombre, correo, mesa o reserva',
                  hintStyle:TextStyle(color:accessMuted),
                  prefixIcon:Icon(Icons.search,color:accessMuted),
                  border:OutlineInputBorder(),
                )),
              const SizedBox(height:11),
              if(!loading&&filtered.isEmpty)const Text('No se encontraron entradas',
                style:TextStyle(color:accessMuted)),
              for(final entry in filtered)
                _entryRow(entry),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _entryRow(Map<String,dynamic> entry){
    final used=entry['ingreso']!=null;
    final enabled=entry['estadoReserva']=='CONFIRMADA'&&entry['retirada']!=true;
    return Container(
      key:Key('access-entry-${entry['entradaId']}'),
      margin:const EdgeInsets.only(bottom:8),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:accessCard,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:used?Colors.greenAccent:const Color(0xFF416070))),
      child:Wrap(spacing:12,runSpacing:8,
        crossAxisAlignment:WrapCrossAlignment.center,
        children:[
          SizedBox(width:220,child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${entry['nombre']??'Asistente'} · Entrada ${entry['numero']}',
                style:const TextStyle(color:accessText,fontWeight:FontWeight.bold)),
              Text('Mesa ${entry['mesa']??'-'}'
                '${entry['silla']==null?'':' · Puesto '+entry['silla'].toString()}',
                style:const TextStyle(color:accessMuted)),
              Text(used?'Ya ingresó: ${entry['ingreso']}':
                enabled?'Pendiente de ingreso':'Reserva no confirmada',
                style:TextStyle(color:used?Colors.greenAccent:accessMuted,fontSize:12)),
            ])),
          OutlinedButton.icon(
            key:Key('access-manual-${entry['entradaId']}'),
            onPressed:busy||used||!enabled?null:()=>markManual(entry),
            icon:Icon(used?Icons.check_circle_outline:Icons.how_to_reg_outlined),
            label:Text(used?'Ya ingresó':'Confirmar manualmente')),
        ],
      ),
    );
  }
}
