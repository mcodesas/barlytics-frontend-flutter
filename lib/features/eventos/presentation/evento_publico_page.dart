import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/eventos_api.dart';
import 'widgets/event_public_landing.dart';
import 'widgets/event_share_sheet.dart';
import 'widgets/event_visual_kit.dart';

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
  final current=event;
  if(current==null||!mounted)return;
  final url=current['enlaceCompartir']?.toString()??
    ref.read(eventosApiProvider).link(widget.slug);
  await showEventShareSheet(context,current,url);
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
    // La persona ya confirmó puestos y datos en el diálogo principal:
    // abrir Mercado Pago sin un segundo diálogo redundante.
    final directPayment=event?['modoReserva']=='PUESTOS' &&
      event?['seleccionarMesa']==false;
    final palette=EventPagePalette.fromHex(
      event?['colorPrimario']?.toString(),event?['colorFondo']?.toString(),
      event?['colorTexto']?.toString(),event?['colorTarjeta']?.toString(),
      event?['colorBorde']?.toString(),event?['colorCarta']?.toString());
    final readable=EventPagePalette.contrast(palette.text,palette.surface)>=4.5
      ?palette.text:(EventPagePalette.contrast(Colors.black,palette.surface)>
        EventPagePalette.contrast(Colors.white,palette.surface)
        ?Colors.black:Colors.white);
    final shouldPay=directPayment?true:await showDialog<bool>(
      context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:palette.surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
        side:BorderSide(color:palette.border)),
      title:Text('Reserva pendiente de pago',style:TextStyle(
        color:readable,fontWeight:FontWeight.w900)),
      content:Text('Los puestos quedan apartados provisionalmente durante $minutes minutos. '
       'Solo un pago aprobado por Mercado Pago confirma tu reserva. '
       'Si termina el plazo sin aprobación, los puestos volverán a estar disponibles.',
       style:TextStyle(color:readable)),
      actions:[
       TextButton(style:TextButton.styleFrom(foregroundColor:readable),
         onPressed:()=>Navigator.pop(ctx,false),
         child:const Text('Consultar estado')),
       if(checkout.isNotEmpty)FilledButton(
         style:FilledButton.styleFrom(backgroundColor:palette.accent,
           foregroundColor:palette.onAccent),
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
  final palette=EventPagePalette.fromHex(
    value?['colorPrimario']?.toString(),value?['colorFondo']?.toString(),
    value?['colorTexto']?.toString(),value?['colorTarjeta']?.toString(),
    value?['colorBorde']?.toString(),value?['colorCarta']?.toString());
  final base=palette.canvas, surface=palette.surface;
  final foreground=palette.onSurface;
  final itemForeground=palette.onSurfaceSoft;
  final subtle=EventPagePalette.readable(
    Color.lerp(foreground,surface,.23)!,surface);
  final ticketList=value?['entradas'] is List?value!['entradas'] as List:<dynamic>[];
  final individual=value?['entradaIndividual']==true;
  return Scaffold(backgroundColor:base,body:SafeArea(child:Center(child:SingleChildScrollView(
   padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),
    child:Card(color:surface,child:Padding(padding:const EdgeInsets.all(25),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(Icons.celebration,color:palette.accentOnSurface,size:42),
      const SizedBox(height:12),
      Text(value?['sucursal']?.toString()??'Entrada digital',textAlign:TextAlign.center,
       style:TextStyle(color:foreground,fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      Text(value?['evento']?.toString()??'Consultando...',textAlign:TextAlign.center,
       style:TextStyle(color:foreground,fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:15),
      if(value!=null)...[
       if(individual)...[
        Text('Entrada '+(value?['numeroEntrada']??'').toString()+
          ' de '+(value?['totalEntradas']??'').toString(),
          style:TextStyle(color:foreground,fontSize:18,
            fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
       ],
       if((value!['mesas'] as List? ??[]).length>1)...[
         Text('Mesas asignadas',style:TextStyle(
           color:foreground,fontSize:20,fontWeight:FontWeight.w800)),
         const SizedBox(height:7),
         for(final table in (value!['mesas'] as List? ??[]))
           Text('Mesa '+(table['numero']??'').toString()+' · '+
             (table['puestos']??'').toString()+' puestos',
             style:TextStyle(color:foreground,fontSize:15)),
       ]else
         Text('Mesa '+value!['mesa'].toString(),style:TextStyle(color:foreground,fontSize:21)),
        Text((value!['puestos']?.toString()??'1')+' puestos',
         style:TextStyle(color:foreground,fontSize:17)),
       Text('Inicio: '+when(value!['inicio']),style:TextStyle(color:subtle)),
       Text('Fin: '+when(value!['fin']),style:TextStyle(color:subtle)),
      ],
      const SizedBox(height:17),
      if(confirmed&&(individual||ticketList.isEmpty))Container(
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
       Icons.pending_actions_rounded,color:palette.accentOnSurface,size:65),
      if(confirmed&&ticketList.isNotEmpty&&!individual)...[
       const SizedBox(height:13),
       Text('Tus entradas individuales',style:TextStyle(
        color:foreground,fontWeight:FontWeight.w900,fontSize:18)),
       const SizedBox(height:7),
       Text('Cada asistente dispone de un QR propio.',
        textAlign:TextAlign.center,
        style:TextStyle(color:subtle,fontSize:12)),
       const SizedBox(height:13),
       for(final raw in ticketList)
        if(raw is Map)Container(
         padding:const EdgeInsets.all(13),
         margin:const EdgeInsets.only(bottom:12),
         decoration:BoxDecoration(color:palette.surfaceSoft,
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:palette.border)),
         child:Column(children:[
          Text('Entrada '+(raw['numero']??'').toString()+
            ' de '+ticketList.length.toString(),
            style:TextStyle(color:itemForeground,
              fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:5),
          Text('Mesa '+(raw['mesa']??'').toString()+
           (raw['silla']==null?'':' · Puesto '+raw['silla'].toString()),
           style:TextStyle(color:EventPagePalette.readable(
            subtle,palette.surfaceSoft))),
          const SizedBox(height:10),
          Container(color:Colors.white,padding:const EdgeInsets.all(8),
           child:Image.network(
            ref.read(eventosApiProvider).qrLink(raw['token'].toString()),
            width:175,height:175,fit:BoxFit.contain,
            errorBuilder:(_,__,___)=>const Text(
              'QR no disponible. Abre la entrada digital.',
              style:TextStyle(color:Colors.black87)))),
          const SizedBox(height:7),
          TextButton.icon(
           onPressed:()=>launchUrl(Uri.parse(raw['url'].toString()),
             mode:LaunchMode.externalApplication),
           icon:const Icon(Icons.open_in_new_outlined),
           style:TextButton.styleFrom(foregroundColor:
             EventPagePalette.readable(palette.accent,palette.surfaceSoft)),
           label:const Text('Ver entrada digital')),
          OutlinedButton.icon(
           onPressed:()=>launchUrl(Uri.parse(ref.read(eventosApiProvider)
             .qrLink(raw['token'].toString())),
             mode:LaunchMode.externalApplication),
           icon:const Icon(Icons.download_outlined),
           style:OutlinedButton.styleFrom(foregroundColor:itemForeground,
             side:BorderSide(color:palette.border)),
           label:const Text('Descargar QR')),
         ]),
        ),
      ],
      const SizedBox(height:13),
      Text(confirmed?(individual?'ENTRADA INDIVIDUAL CONFIRMADA':'RESERVA CONFIRMADA'):
       value?['estado']=='PENDIENTE_PAGO'?'PAGO PENDIENTE':
       value?['estado']=='EXPIRADA'?'RESERVA VENCIDA':
       value?['estado']=='REEMBOLSO_PENDIENTE'?'REVISIÓN DE DEVOLUCIÓN':
       value?['estado']?.toString()??error??'Cargando...',
       style:TextStyle(color:foreground,fontWeight:FontWeight.bold)),
      if(value?['mensajeEstado']!=null)...[
       const SizedBox(height:8),
       Text(value!['mensajeEstado'].toString(),textAlign:TextAlign.center,
        style:TextStyle(color:subtle,fontSize:13,height:1.5)),
      ],
      if(value?['estado']=='PENDIENTE_PAGO'&&value?['vencePago']!=null)...[
       const SizedBox(height:9),
       Text('Plazo para pagar hasta: '+when(value!['vencePago']),
        textAlign:TextAlign.center,
        style:TextStyle(color:foreground,fontSize:12)),
       const SizedBox(height:5),
       Text('Comprobando automáticamente cada 15 segundos',
        style:TextStyle(color:subtle,fontSize:11)),
      ],
      const SizedBox(height:18),
      if(confirmed&&(individual||ticketList.isEmpty))FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:palette.accent,foregroundColor:palette.onAccent),onPressed:()=>launchUrl(Uri.parse(ref.read(eventosApiProvider).qrLink(widget.token)),
       mode:LaunchMode.externalApplication),icon:const Icon(Icons.download),label:const Text('Descargar QR')),
      TextButton.icon(style:TextButton.styleFrom(foregroundColor:foreground),onPressed:refresh,icon:const Icon(Icons.refresh),label:const Text('Consultar estado')),
     ]))))))));
 }
}
