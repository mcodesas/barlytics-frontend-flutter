import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/eventos_api.dart';
import 'widgets/event_public_landing.dart';
import 'widgets/event_digital_ticket_view.dart';
import 'widgets/event_share_sheet.dart';
import 'widgets/event_visual_kit.dart';
import 'widgets/event_browser_theme.dart';

/// En la web la navegación al checkout reemplaza la pestaña actual.
/// Abrir otra pestaña después de una petición HTTP puede ser bloqueado por
/// el navegador al perderse el gesto inicial del usuario.
Uri? eventCheckoutUri(String raw){
  final uri=Uri.tryParse(raw.trim());
  return uri!=null&&uri.scheme=='https'&&uri.host.isNotEmpty?uri:null;
}
Future<bool> openEventCheckout(String raw)async{
  final uri=eventCheckoutUri(raw);
  if(uri==null)return false;
  return launchUrl(uri,
    mode:kIsWeb?LaunchMode.platformDefault:LaunchMode.externalApplication,
    webOnlyWindowName:kIsWeb?'_self':null);
}

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
  try{
    final e=await ref.read(eventosApiProvider).eventoPublico(widget.slug);
    if(mounted)setState((){event=e;error=null;});
  }catch(e){
    if(mounted)setState(()=>error=e.toString());
  }finally{
    // No retirar la pantalla de carga HTML durante el fotograma genérico.
    // Esperar hasta que Flutter haya dibujado la página o el error.
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)completeEventBrowserLoader();
    });
  }
 }
 Future<void> share()async{
  final current=event;
  if(current==null||!mounted)return;
  final url=eventSocialPreviewUrl(current,
    ref.read(eventosApiProvider).link(widget.slug),
    websiteUri:kIsWeb?Uri.base:null);
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
      scrollable: true,
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
    if(shouldPay==true){
      bool opened=false;
      try{
        opened=await openEventCheckout(checkout);
      }catch(_){opened=false;}
      if(opened){
        // En web la pestaña cambia al checkout; Mercado Pago regresa al
        // enlace de la reserva. En móvil dejamos la consulta accesible.
        if(!kIsWeb&&mounted){
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>EventoEntradaPublicaPage(token:token)));
        }
        return;
      }
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No se pudo abrir Mercado Pago. Usa el botón Pagar ahora en la reserva.')));
    }
    if(mounted)Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(_)=>EventoEntradaPublicaPage(token:token)));
   }else if(state=='CONFIRMADA'){
    if(mounted)Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>EventoEntradaPublicaPage(token:token)));
   }else{
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Reserva solicitada. El negocio revisará el pago y enviará tu entrada QR por correo.')));
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text('Reserva no realizada: '+e.toString())));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  final current=event;
  if(current==null){
   // Aún no se conoce la paleta de BD: usar el tema neutral predefinido.
   final loadingPalette=EventPagePalette.fromHex(null,null);
   return Scaffold(
    backgroundColor:loadingPalette.canvas,
    body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
     Icon(error==null?Icons.event_available_outlined:Icons.cloud_off_outlined,
      color:loadingPalette.accentOnSurface,size:48),
     const SizedBox(height:13),
     Text(error==null?'Preparando tu experiencia...':
       'No se pudo cargar este evento',
       textAlign:TextAlign.center,
       style:TextStyle(color:loadingPalette.onSurface,fontSize:17)),
     if(error!=null)...[
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:refresh,
       icon:const Icon(Icons.refresh),label:const Text('Reintentar')),
     ]else const Padding(padding:EdgeInsets.only(top:17),
       child:CircularProgressIndicator()),
    ])),
   );
  }
  final eventPalette=EventPagePalette.fromHex(
    current['colorPrimario']?.toString(),current['colorFondo']?.toString(),
    current['colorTexto']?.toString(),current['colorTarjeta']?.toString(),
    current['colorBorde']?.toString(),current['colorCarta']?.toString());
  return EventBrowserThemeScope(
   background:eventPalette.canvas,
   child:EventPublicLanding(
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
   ),
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
  final palette=EventPagePalette.fromHex(
    value?['colorPrimario']?.toString(),value?['colorFondo']?.toString(),
    value?['colorTexto']?.toString(),value?['colorTarjeta']?.toString(),
    value?['colorBorde']?.toString(),value?['colorCarta']?.toString());
  return EventBrowserThemeScope(
    background:palette.canvas,
    child:EventDigitalTicketView(
      token:widget.token,
      value:value,
      error:error,
      palette:palette,
      qrUrl:(entryToken)=>ref.read(eventosApiProvider).qrLink(entryToken),
      onRefresh:refresh,
      onFinish:(){
        final slug=(value?['slug']??'').toString().trim();
        if(slug.isNotEmpty){
          context.go('/evento/'+Uri.encodeComponent(slug));
        }else if(Navigator.of(context).canPop()){
          Navigator.of(context).pop();
        }else{
          context.go('/');
        }
      },
      onPay:(checkout)async{
        final ok=await openEventCheckout(checkout)
          .catchError((Object _)=>false);
        if(!ok&&mounted){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('No se pudo abrir Mercado Pago. Comprueba el enlace o intenta de nuevo.')));
        }
      },
    ),
  );
 }
}
