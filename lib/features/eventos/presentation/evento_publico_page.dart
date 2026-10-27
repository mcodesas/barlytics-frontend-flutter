import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/eventos_api.dart';
import 'widgets/event_public_landing.dart';

const ink=Color(0xff0b1025),teal=Color(0xff34ddcf),muted=Color(0xffb5bed5),accent=Color(0xffffca83);
ImageProvider? cover(Object? value){
 final v=value?.toString()??'';
 try{
  if(v.startsWith('data:image/')&&v.contains(','))return MemoryImage(base64Decode(v.substring(v.indexOf(',')+1)));
  if(v.startsWith('https://'))return NetworkImage(v);
 }catch(_){}
 return null;
}
String when(Object? raw){
 final dt=DateTime.tryParse(raw?.toString()??'');
 return dt==null?'Pendiente':DateFormat("EEE d MMM yyyy · h:mm a",'es_CO').format(dt);
}
String money(Object? raw)=>NumberFormat.currency(locale:'es_CO',symbol:'\$',decimalDigits:0).format(double.tryParse(raw.toString())??0);

class EventoPublicoPage extends ConsumerStatefulWidget{
 const EventoPublicoPage({super.key,required this.slug});
 final String slug;
 @override ConsumerState<EventoPublicoPage> createState()=>_PublicState();
}
class _PublicState extends ConsumerState<EventoPublicoPage>{
 Map<String,dynamic>? event;String? error;int? selected;int seats=1;bool busy=false;
 final name=TextEditingController(),email=TextEditingController(),phone=TextEditingController();
 @override void initState(){super.initState();refresh();}
 @override void dispose(){name.dispose();email.dispose();phone.dispose();super.dispose();}
 Future<void> refresh()async{
  try{final e=await ref.read(eventosApiProvider).eventoPublico(widget.slug);if(mounted)setState((){event=e;error=null;});}
  catch(e){if(mounted)setState(()=>error=e.toString());}
 }
 Future<void> share()async{
  final url=event?['enlaceCompartir']?.toString()??
    ref.read(eventosApiProvider).link(widget.slug);
  if(!mounted)return;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,
   backgroundColor:const Color(0xff182a43),
   shape:const RoundedRectangleBorder(
    borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
   builder:(sheet)=>SafeArea(
    child:Padding(padding:const EdgeInsets.all(24),
     child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,children:[
       const Text('Compartir este evento',style:TextStyle(
        color:Colors.white,fontSize:23,fontWeight:FontWeight.w800)),
       const SizedBox(height:7),
       const Text('Invita a otros a reservar sus puestos.',style:TextStyle(color:muted)),
       const SizedBox(height:15),
       SelectableText(url,style:const TextStyle(color:teal,fontSize:13)),
       const SizedBox(height:18),
       Wrap(spacing:9,runSpacing:9,children:[
        FilledButton.icon(
         onPressed:()async{
          try{
           await Clipboard.setData(ClipboardData(text:url));
           if(sheet.mounted)Navigator.pop(sheet);
           if(mounted)ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Enlace del evento copiado')));
          }catch(_){
           if(mounted)ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Selecciona y copia el enlace mostrado')));
          }
         },
         icon:const Icon(Icons.copy),label:const Text('Copiar enlace')),
        OutlinedButton.icon(
         onPressed:()async{
          final text='Te invito a '+(event?['titulo']?.toString()??'este evento')+'\n'+url;
          final target=Uri.parse('https://wa.me/?text='+Uri.encodeComponent(text));
          final ok=await launchUrl(target,mode:LaunchMode.externalApplication);
          if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content:Text('No se pudo abrir WhatsApp')));
         },icon:const Icon(Icons.message),label:const Text('WhatsApp')),
        OutlinedButton.icon(
         onPressed:()async{
          final target=Uri.parse('https://www.facebook.com/sharer/sharer.php?u='+
            Uri.encodeComponent(url));
          final ok=await launchUrl(target,mode:LaunchMode.externalApplication);
          if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content:Text('No se pudo abrir Facebook')));
         },icon:const Icon(Icons.share_outlined),label:const Text('Facebook')),
       ]),
       const SizedBox(height:13),
      ]),
    ),
   ),
  );
 }
 Future<void> book(List<int> chairs)async{
  if((selected==null&&event?['modoReserva']!='PUESTOS')||
      name.text.trim().isEmpty||!email.text.contains('@')){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Completa el nombre y correo para reservar.')));return;
  }
  setState(()=>busy=true);
  try{
   final result=await ref.read(eventosApiProvider).reservar(widget.slug,{
    'mesaId':selected,'puestos':seats,'sillas':chairs,
    'nombre':name.text.trim(),'email':email.text.trim(),'telefono':phone.text.trim()
   });
   if(!mounted)return;
   final token=result['token']?.toString()??'';
   final checkout=result['checkoutUrl']?.toString()??'';
   final state=result['estado']?.toString()??'';
   await refresh();
   if(!mounted)return;
   if(state=='PENDIENTE_PAGO'){
    final minutes=(result['plazoPagoMinutos'] as num?)?.toInt()??20;
    final shouldPay=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Reserva pendiente de pago'),
      content:Text('La mesa se aparta provisionalmente durante $minutes minutos. '
       'Solo un pago aprobado por Mercado Pago confirma tu reserva. '
       'Si termina el plazo sin aprobación, la mesa volverá a estar disponible.'),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(ctx,false),
         child:const Text('Consultar estado')),
       if(checkout.isNotEmpty)FilledButton(
         onPressed:()=>Navigator.pop(ctx,true),
         child:const Text('Pagar ahora')),
      ]));
    if(!mounted)return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(_)=>EventoEntradaPublicaPage(token:token)));
    if(shouldPay==true&&checkout.isNotEmpty){
      final url=Uri.tryParse(checkout);
      if(url!=null&&url.scheme=='https'){
        final ok=await launchUrl(url,mode:LaunchMode.externalApplication);
        if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('No se pudo abrir Mercado Pago. Consulta el estado de la reserva.')));
      }
    }
   }else if(state=='CONFIRMADA'){
    if(mounted)Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>EventoEntradaPublicaPage(token:token)));
   }else{
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Reserva solicitada. El negocio revisará el pago y enviará tu entrada QR por correo.')));
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Reserva no realizada: '+e.toString())));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  final current=event;
  if(current==null){
   return Scaffold(
    backgroundColor:const Color(0xFF061925),
    body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
     Icon(error==null?Icons.event_available_outlined:Icons.cloud_off_outlined,
      color:const Color(0xFF23D8D1),size:48),
     const SizedBox(height:13),
     Text(error==null?'Preparando tu experiencia...':
       'No se pudo cargar este evento',
       textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.white,fontSize:17)),
     if(error!=null)...[
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:refresh,
       icon:const Icon(Icons.refresh),label:const Text('Reintentar')),
     ]else const Padding(padding:EdgeInsets.only(top:17),
       child:CircularProgressIndicator()),
    ])),
   );
  }
  return EventPublicLanding(
   event:current,
   selectedTable:selected,
   seats:seats,
   busy:busy,
   name:name,email:email,phone:phone,
   onSelectTable:(id)=>setState((){
    selected=id>0?id:null;
    seats=1;
   }),
   onSeatsChanged:(value)=>setState(()=>seats=value),
   onBook:book,
   onShare:share,
   onRefresh:refresh,
  );
 }
}
class EventoEntradaPublicaPage extends ConsumerStatefulWidget{
 const EventoEntradaPublicaPage({super.key,required this.token});
 final String token;
 @override ConsumerState<EventoEntradaPublicaPage> createState()=>_EntradaState();
}
class _EntradaState extends ConsumerState<EventoEntradaPublicaPage>{
 Map<String,dynamic>? value;String? error;
 Timer? _refreshTimer;
 bool _requestInProgress=false;
 @override void initState(){
  super.initState();
  refresh();
  _refreshTimer=Timer.periodic(const Duration(seconds:15),(_){
   if(mounted&&value?['estado']=='PENDIENTE_PAGO')refresh();
  });
 }
 @override void dispose(){_refreshTimer?.cancel();super.dispose();}
 Future<void> refresh()async{
  if(_requestInProgress)return;
  _requestInProgress=true;
  try{
   final x=await ref.read(eventosApiProvider).entrada(widget.token);
   if(mounted)setState((){value=x;error=null;});
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{_requestInProgress=false;}
 }
 @override Widget build(BuildContext context){
  final confirmed=value?['estado']=='CONFIRMADA';
  return Scaffold(backgroundColor:ink,body:SafeArea(child:Center(child:SingleChildScrollView(
   padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),
    child:Card(color:const Color(0xff1b2945),child:Padding(padding:const EdgeInsets.all(25),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.celebration,color:accent,size:42),
      const SizedBox(height:12),
      Text(value?['sucursal']?.toString()??'Entrada digital',textAlign:TextAlign.center,
       style:const TextStyle(color:teal,fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      Text(value?['evento']?.toString()??'Consultando...',textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:15),
      if(value!=null)...[
       Text('Mesa '+value!['mesa'].toString(),style:const TextStyle(color:Colors.white,fontSize:21)),
        Text((value!['puestos']?.toString()??'1')+' puestos',
         style:const TextStyle(color:teal,fontSize:17)),
       Text('Inicio: '+when(value!['inicio']),style:const TextStyle(color:muted)),
       Text('Fin: '+when(value!['fin']),style:const TextStyle(color:muted)),
      ],
      const SizedBox(height:17),
      if(confirmed)Container(
       color: Colors.white,
       padding: const EdgeInsets.all(12),
       child: Image.network(
        ref.read(eventosApiProvider).qrLink(widget.token),
        width: 210,
        height: 210,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
          const SizedBox(
            width: 210,
            height: 210,
            child: Center(
              child: Text(
                'No se pudo cargar el QR. Usa el botón Descargar QR.',
                style: TextStyle(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
          ),
       ),
      )
      else Icon(
       value?['estado']=='EXPIRADA'?Icons.event_busy_outlined:
       value?['estado']=='REEMBOLSO_PENDIENTE'?Icons.support_agent_outlined:
       Icons.pending_actions_rounded,color:accent,size:65),
      const SizedBox(height:13),
      Text(confirmed?'ENTRADA CONFIRMADA':
       value?['estado']=='PENDIENTE_PAGO'?'PAGO PENDIENTE':
       value?['estado']=='EXPIRADA'?'RESERVA VENCIDA':
       value?['estado']=='REEMBOLSO_PENDIENTE'?'REVISIÓN DE DEVOLUCIÓN':
       value?['estado']?.toString()??error??'Cargando...',
       style:TextStyle(color:confirmed?teal:accent,fontWeight:FontWeight.bold)),
      if(value?['mensajeEstado']!=null)...[
       const SizedBox(height:8),
       Text(value!['mensajeEstado'].toString(),textAlign:TextAlign.center,
        style:const TextStyle(color:muted,fontSize:13,height:1.5)),
      ],
      if(value?['estado']=='PENDIENTE_PAGO'&&value?['vencePago']!=null)...[
       const SizedBox(height:9),
       Text('Plazo para pagar hasta: '+when(value!['vencePago']),
        textAlign:TextAlign.center,
        style:const TextStyle(color:accent,fontSize:12)),
       const SizedBox(height:5),
       const Text('Comprobando automáticamente cada 15 segundos',
        style:TextStyle(color:muted,fontSize:11)),
      ],
      const SizedBox(height:18),
      if(confirmed)FilledButton.icon(onPressed:()=>launchUrl(Uri.parse(ref.read(eventosApiProvider).qrLink(widget.token)),
       mode:LaunchMode.externalApplication),icon:const Icon(Icons.download),label:const Text('Descargar QR')),
      TextButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh),label:const Text('Consultar estado')),
     ]))))))));
 }
}
