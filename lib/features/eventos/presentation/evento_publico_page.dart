import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/eventos_api.dart';

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
String money(Object? raw)=>NumberFormat.currency(locale:'es_CO',symbol:'$',decimalDigits:0).format(double.tryParse(raw.toString())??0);

class EventoPublicoPage extends ConsumerStatefulWidget{
 const EventoPublicoPage({super.key,required this.slug});
 final String slug;
 @override ConsumerState<EventoPublicoPage> createState()=>_PublicState();
}
class _PublicState extends ConsumerState<EventoPublicoPage>{
 Map<String,dynamic>? event;String? error;int? selected;bool busy=false;
 final name=TextEditingController(),email=TextEditingController(),phone=TextEditingController();
 @override void initState(){super.initState();refresh();}
 @override void dispose(){name.dispose();email.dispose();phone.dispose();super.dispose();}
 Future<void> refresh()async{
  try{final e=await ref.read(eventosApiProvider).eventoPublico(widget.slug);if(mounted)setState((){event=e;error=null;});}
  catch(e){if(mounted)setState(()=>error=e.toString());}
 }
 Future<void> book()async{
  if(selected==null||name.text.trim().isEmpty||!email.text.contains('@')){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Selecciona mesa y completa nombre y correo.')));return;
  }
  setState(()=>busy=true);
  try{
   final result=await ref.read(eventosApiProvider).reservar(widget.slug,{
    'mesaId':selected,'nombre':name.text.trim(),'email':email.text.trim(),'telefono':phone.text.trim()
   });
   if(!mounted)return;
   final token=result['token']?.toString()??'';
   final checkout=result['checkoutUrl']?.toString()??'';
   final state=result['estado']?.toString()??'';
   await refresh();
   if(!mounted)return;
   if(state=='PENDIENTE_PAGO'&&checkout.isNotEmpty){
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Tu mesa se apartó por 20 minutos'),
      content:const Text('Completa el pago en la plataforma segura. La confirmación se enviará únicamente después de verificarlo con la entidad financiera.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar')),
       FilledButton(onPressed:(){Navigator.pop(ctx);launchUrl(Uri.parse(checkout),mode:LaunchMode.externalApplication);},
        child:const Text('Pagar ahora'))]));
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
  final e=event;
  if(e==null)return Scaffold(backgroundColor:ink,body:Center(child:Text(error??'Cargando evento...',style:const TextStyle(color:Colors.white))));
  final wide=MediaQuery.sizeOf(context).width>700;
  final logo=cover(e['logo']),photo=cover(e['imagen']);
  final tables=(e['mesas'] as List? ??[]).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
  final catalog=(e['carta'] as List? ??[]).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
  return Theme(data:ThemeData.dark(useMaterial3:true).copyWith(colorScheme:const ColorScheme.dark(primary:teal,surface:Color(0xff19243e))),
   child:Scaffold(backgroundColor:ink,body:RefreshIndicator(onRefresh:refresh,
    child:CustomScrollView(slivers:[
     SliverToBoxAdapter(child:Container(
      constraints:const BoxConstraints(minHeight:380),
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff142c4d),Color(0xff282044),ink]),
       image:photo==null?null:DecorationImage(image:photo,fit:BoxFit.cover,colorFilter:ColorFilter.mode(ink.withOpacity(.6),BlendMode.darken))),
      child:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),
       child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
         CircleAvatar(radius:27,backgroundColor:Colors.white,backgroundImage:logo,
          child:logo==null?const Icon(Icons.local_bar,color:ink):null),
         const SizedBox(width:13),
         Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(e['empresa']?.toString()??'',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          Text(e['sucursal']?.toString()??'',style:const TextStyle(color:muted))
         ])),
         IconButton(tooltip:'Copiar enlace para redes sociales',onPressed:()async{
          await Clipboard.setData(ClipboardData(text:ref.read(eventosApiProvider).link(widget.slug)));
          if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enlace copiado')));
         },icon:const Icon(Icons.share,color:teal))
        ]),
        const SizedBox(height:55),
        const Text('VIVE UNA NOCHE INOLVIDABLE',style:TextStyle(color:teal,letterSpacing:2,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        Text(e['titulo']?.toString()??'',style:TextStyle(fontSize:wide?52:34,height:1.05,fontWeight:FontWeight.w900)),
        const SizedBox(height:20),
        Wrap(spacing:16,runSpacing:9,children:[
         _chip(Icons.event_available,'Inicio: '+when(e['inicio'])),
         _chip(Icons.nights_stay_outlined,'Fin: '+when(e['fin'])),
         _chip(Icons.location_on_outlined,e['direccion']?.toString()??'')
        ]),
        const SizedBox(height:18),
        Text((e['precio'] as num).toDouble()==0?'RESERVA GRATUITA':'Reserva por mesa · '+money(e['precio']),
          style:const TextStyle(color:accent,fontWeight:FontWeight.bold,fontSize:19))
       ]))))))),
     SliverToBoxAdapter(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),
      child:Padding(padding:const EdgeInsets.all(23),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       _h('El evento'),Text(e['descripcion']?.toString()??'',style:const TextStyle(color:muted,height:1.65,fontSize:16)),
       const SizedBox(height:30),
       _h('Escoge tu mesa'),
       const Text('Disponibilidad actualizada. Las mesas apartadas aparecen bloqueadas.',style:TextStyle(color:muted)),
       const SizedBox(height:16),
       Wrap(spacing:12,runSpacing:12,children:tables.map((t){
        final tableId=(t['id'] as num).toInt();
        final free=t['estado']=='DISPONIBLE';
        final checked=selected==tableId;
        return InkWell(onTap:free?()=>setState(()=>selected=tableId):null,
         child:AnimatedContainer(duration:const Duration(milliseconds:180),width:wide?194:152,padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(color:checked?teal.withOpacity(.19):const Color(0xff192540),
           border:Border.all(color:checked?teal:Colors.white12,width:checked?2:1),borderRadius:BorderRadius.circular(18)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Icon(Icons.table_restaurant,color:checked?teal:free?Colors.white:Colors.white38,size:33),
           const SizedBox(height:10),Text('Mesa '+t['numero'].toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
           Text(free?'Disponible':'Apartada',style:TextStyle(color:free?teal:accent)),
           if((t['descripcion']?.toString()??'').isNotEmpty)
            Text(t['descripcion'].toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:muted))
          ])));}
        ).toList()),
       const SizedBox(height:30),
       Container(padding:const EdgeInsets.all(21),decoration:BoxDecoration(color:const Color(0xff1b2945),
        borderRadius:BorderRadius.circular(22)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         _h('Aparta tu lugar'),
         Text(e['medioPago']=='GRATIS'?'Recibirás tu entrada QR inmediatamente.':
          e['medioPago']=='MANUAL'?'El establecimiento aprobará el pago antes de emitir tu QR.':
          'Tienes 20 minutos para completar el pago en línea.',
          style:const TextStyle(color:muted)),
         const SizedBox(height:15),
         Wrap(spacing:12,runSpacing:10,children:[
          SizedBox(width:260,child:TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre completo *',border:OutlineInputBorder()))),
          SizedBox(width:260,child:TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Correo electrónico *',border:OutlineInputBorder()))),
          SizedBox(width:190,child:TextField(controller:phone,decoration:const InputDecoration(labelText:'Teléfono',border:OutlineInputBorder()))),
         ]),
         if(e['medioPago']=='MANUAL')Padding(padding:const EdgeInsets.only(top:12),
          child:Text(e['instruccionesPago']?.toString()??'',style:const TextStyle(color:accent))),
         const SizedBox(height:17),
         FilledButton.icon(onPressed:selected==null||busy?null:book,
          style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:25,vertical:19),
           backgroundColor:teal,foregroundColor:ink),
          icon:const Icon(Icons.confirmation_number_outlined),
          label:Text(busy?'Procesando...':'Reservar · '+money(e['precio'])))
        ])),
       const SizedBox(height:35),
       if(catalog.isNotEmpty)...[
        _h('Descubre nuestra carta'),
        Wrap(spacing:12,runSpacing:12,children:catalog.map((p){
         final img=cover(p['imagen']);
         return Container(width:wide?234:156,clipBehavior:Clip.antiAlias,
          decoration:BoxDecoration(color:const Color(0xff192540),borderRadius:BorderRadius.circular(16)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           if(img!=null)Image(image:img,height:110,width:double.infinity,fit:BoxFit.cover)
           else const SizedBox(height:90,child:Center(child:Icon(Icons.local_dining,color:accent,size:32))),
           Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p['nombre']?.toString()??'',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:6),Text(money(p['precio']),style:const TextStyle(color:teal,fontWeight:FontWeight.bold))
           ]))]));
        }).toList()),
       ],
       const SizedBox(height:50),
       const Center(child:Text('Experiencias y reservas con BarLytics',style:TextStyle(color:muted,fontSize:12)))
      ]))))),
    ]))));}
  Widget _h(String title)=>Padding(padding:const EdgeInsets.only(bottom:16),
    child:Text(title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w800)));
  Widget _chip(IconData icon,String title)=>Container(padding:const EdgeInsets.symmetric(vertical:9,horizontal:12),
    decoration:BoxDecoration(color:Colors.black45,borderRadius:BorderRadius.circular(25)),
    child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:teal,size:16),const SizedBox(width:7),
     Flexible(child:Text(title,style:const TextStyle(color:Colors.white,fontSize:12)))]));
}
class EventoEntradaPublicaPage extends ConsumerStatefulWidget{
 const EventoEntradaPublicaPage({super.key,required this.token});
 final String token;
 @override ConsumerState<EventoEntradaPublicaPage> createState()=>_EntradaState();
}
class _EntradaState extends ConsumerState<EventoEntradaPublicaPage>{
 Map<String,dynamic>? value;String? error;
 @override void initState(){super.initState();refresh();}
 Future<void> refresh()async{
  try{final x=await ref.read(eventosApiProvider).entrada(widget.token);
   if(mounted)setState((){value=x;error=null;});
  }catch(e){if(mounted)setState(()=>error=e.toString());}
 }
 @override Widget build(BuildContext context){
  final confirmed=value?['estado']=='CONFIRMADA';
  final link=ref.read(eventosApiProvider).entradaLink(widget.token);
  return Scaffold(backgroundColor:ink,body:SafeArea(child:Center(child:SingleChildScrollView(
   padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),
    child:Card(color:const Color(0xff1b2945),child:Padding(padding:const EdgeInsets.all(25),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.celebration,color:accent,size:42),
      const SizedBox(height:12),
      Text(value?['empresa']?.toString()??'Entrada digital',textAlign:TextAlign.center,
       style:const TextStyle(color:teal,fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      Text(value?['evento']?.toString()??'Consultando...',textAlign:TextAlign.center,
       style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:15),
      if(value!=null)...[
       Text('Mesa '+value!['mesa'].toString(),style:const TextStyle(color:Colors.white,fontSize:21)),
       Text('Inicio: '+when(value!['inicio']),style:const TextStyle(color:muted)),
       Text('Fin: '+when(value!['fin']),style:const TextStyle(color:muted)),
      ],
      const SizedBox(height:17),
      if(confirmed)Container(color:Colors.white,padding:const EdgeInsets.all(12),
       child:QrImageView(data:link,backgroundColor:Colors.white,size:210))
      else const Icon(Icons.pending_actions_rounded,color:accent,size:65),
      const SizedBox(height:13),
      Text(confirmed?'ENTRADA CONFIRMADA':value?['estado']?.toString()??error??'Cargando...',
       style:TextStyle(color:confirmed?teal:accent,fontWeight:FontWeight.bold)),
      const SizedBox(height:18),
      if(confirmed)FilledButton.icon(onPressed:()=>launchUrl(Uri.parse(ref.read(eventosApiProvider).qrLink(widget.token)),
       mode:LaunchMode.externalApplication),icon:const Icon(Icons.download),label:const Text('Descargar QR')),
      TextButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh),label:const Text('Consultar estado')),
     ]))))))));
 }
}
