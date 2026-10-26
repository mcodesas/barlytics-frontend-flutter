import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../data/eventos_api.dart';
import 'widgets/event_visual_kit.dart';

const sea=Color(0xff24d4ce);
const eventSurface=Color(0xff102e40);
const eventBorder=Color(0xff365a6a);
const eventText=Color(0xffeffaff);
const eventSecondary=Color(0xffb2cad4);
String niceEventError(Object e){
 if(e is DioException){
  final code=e.response?.statusCode;
  if(code==403)return 'Tu rol no tiene permisos para consultar estos eventos.';
  if(code==401)return 'La sesión expiró. Ingresa nuevamente.';
  if(code==404)return 'Esta función todavía no se encuentra disponible en el backend.';
  if(code==500||code==503)return 'El servidor no puede consultar eventos. Comprueba que las migraciones V43 y V44 se hayan aplicado al backend.';
  if(code==null)return 'No hay conexión con el servidor. Comprueba tu conexión.';
  final data=e.response?.data;
  if(data is Map){
   final msg=(data['mensaje']??data['message']??data['detail'])?.toString();
   if(msg!=null&&msg.isNotEmpty&&msg.length<150)return msg;
  }
  return 'No se pudo completar la solicitud (código '+code.toString()+').';
 }
 return 'No se pudo completar la operación. Inténtalo otra vez.';
}

String dateLabel(DateTime d)=>DateFormat('dd/MM/yyyy').format(d);
String hourLabel(DateTime d)=>DateFormat('hh:mm a').format(d);
int? asId(Object? val)=>val is num?val.toInt():int.tryParse(val?.toString()??'');

class EventosAdminPage extends ConsumerStatefulWidget {
 const EventosAdminPage({super.key});
 @override ConsumerState<EventosAdminPage> createState()=>_EventosAdminState();
}
class _EventosAdminState extends ConsumerState<EventosAdminPage>{
 List<Map<String,dynamic>> entries=[];bool loading=true;String? error;
 String filter='TODOS',search='';
 final searchController=TextEditingController();
 @override void initState(){super.initState();load();}
 @override void dispose(){searchController.dispose();super.dispose();}
 int _loadSeq=0;
 Future<void> load({bool keepVisible=false})async{
  final seq=++_loadSeq;
  if(mounted)setState((){loading=!keepVisible;error=null;});
  try{
   final rows=await ref.read(eventosApiProvider).eventos();
   if(!mounted||seq!=_loadSeq)return;
   setState((){entries=rows;loading=false;error=null;});
  }catch(e){
   if(!mounted||seq!=_loadSeq)return;
   if(keepVisible && entries.isNotEmpty){
    setState((){loading=false;error=null;});
    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content:Text('El evento se guardó. No fue posible actualizar la lista desde el servidor.')));
   }else{
    setState((){loading=false;error=niceEventError(e);});
   }
  }
 }
 Future<void> editor([Map<String,dynamic>? event])async{
  final saved=await showDialog<Map<String,dynamic>>(
   context:context,
   builder:(dialog)=>Dialog(
    backgroundColor:eventSurface,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
    insetPadding:const EdgeInsets.all(12),
    child:SizedBox(width:MediaQuery.sizeOf(dialog).width>1450?1360.0:MediaQuery.sizeOf(dialog).width*.94,
      height:MediaQuery.sizeOf(dialog).height*.93,
     child:EventoEditor(initial:event,
      onSaved:(row)=>Navigator.of(dialog).pop(row))),
   ),
  );
  if(!mounted||saved==null)return;
  setState((){
    filter='TODOS';search='';searchController.clear();
    final id=asId(saved['even_id']);
    if(id!=null)entries=[saved,...entries.where((item)=>asId(item['even_id'])!=id)];
    error=null;loading=false;
  });
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
   content:Text(event==null?'Evento creado correctamente':'Evento actualizado correctamente'),
  ));
  await load(keepVisible:true);
 }
 Future<void> shareEvent(Map<String,dynamic> item)async{
  final slug=item['even_slug']?.toString()??'';
  if(slug.isEmpty)return;
  final url=ref.read(eventosApiProvider).link(slug);
  await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
   title:const Text('Compartir evento'),
   content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:570),
    child:Column(mainAxisSize:MainAxisSize.min,
     crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(item['even_titulo']?.toString()??''),
      const SizedBox(height:11),
      SelectableText(url),
      const SizedBox(height:12),
      const Text('Envía el enlace a tus clientes. Podrán ver el evento y reservar sus puestos.',
       style:TextStyle(fontSize:13)),
     ])),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cerrar')),
    OutlinedButton.icon(onPressed:()async{
     final link=Uri.parse('https://wa.me/?text='+Uri.encodeComponent(
      (item['even_titulo']?.toString()??'Evento')+'\n'+url));
     await launchUrl(link,mode:LaunchMode.externalApplication);
    },icon:const Icon(Icons.message),label:const Text('WhatsApp')),
    FilledButton.icon(onPressed:()async{
     try{
      await Clipboard.setData(ClipboardData(text:url));
      if(dialog.mounted)Navigator.pop(dialog);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content:Text('Enlace copiado correctamente')));
     }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content:Text('Copia manualmente el enlace de la ventana')));
     }
    },icon:const Icon(Icons.copy),label:const Text('Copiar enlace')),
   ],
  ));
 }
 Future<void> paymentConfig()async{
  final token=TextEditingController(),secret=TextEditingController();
  try{
   final info=await ref.read(eventosApiProvider).pagoConfig();
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
    title:const Text('Cuenta de cobros del establecimiento'),
    content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),
     child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(info['configurada']==true?'Cuenta configurada. Puedes reemplazarla.':'Conecta tu propia cuenta de Mercado Pago para recibir tus cobros.'),
       const SizedBox(height:10),
       const Text('Los datos se cifran en el servidor; el token nunca será mostrado públicamente.'),
       const SizedBox(height:12),
       SelectableText('Webhook del comercio: '+(info['webhook']?.toString()??'')),
       const SizedBox(height:14),
       TextField(controller:token,obscureText:true,decoration:const InputDecoration(labelText:'Access Token privado del comercio',border:OutlineInputBorder())),
       const SizedBox(height:12),
       TextField(controller:secret,obscureText:true,decoration:const InputDecoration(labelText:'Firma secreta del webhook',border:OutlineInputBorder())),
      ]))),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cancelar')),
     FilledButton(onPressed:()async{
      try{
       await ref.read(eventosApiProvider).configurar(token.text.trim(),secret.text.trim());
       if(dialog.mounted){
        Navigator.pop(dialog);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cuenta de cobro actualizada')));
       }
      }catch(e){if(dialog.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
     },child:const Text('Guardar configuración')),
    ]));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
  finally{token.dispose();secret.dispose();}
 }
 Future<void> detail(int id)async{
  try{
   final data=await ref.read(eventosApiProvider).detalle(id);
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(dialog)=>Dialog(
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:800,maxHeight:680),
     child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(data['even_titulo']?.toString()??'',style:Theme.of(dialog).textTheme.headlineSmall),
      const SizedBox(height:6),
      Text('Inicio: '+(data['even_inicio']?.toString()??'')+'   ·   Final: '+(data['even_fin']?.toString()??'')),
      const SizedBox(height:13),
      Expanded(child:ListView(children:[
       for(final raw in data['reservas'] as List? ??[])
        Builder(builder:(context){
         final r=Map<String,dynamic>.from(raw as Map);
         final status=r['eres_estado']?.toString()??'';
         return Card(child:ListTile(
          title:Text(r['eres_nombre']?.toString()??''),
          subtitle:Text('Mesa '+r['mesa_id'].toString()+' · '+(r['eres_email']?.toString()??'')+
           '\n'+status+' · Pago: '+(r['eres_pago_id']?.toString()??'Sin pago automático')),
          isThreeLine:true,
          trailing:status=='PENDIENTE_REVISION'?FilledButton.icon(
           onPressed:()async{
            try{
             await ref.read(eventosApiProvider).aprobar(asId(r['eres_id'])!);
             if(dialog.mounted){Navigator.pop(dialog);detail(id);}
            }catch(e){if(dialog.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
           },icon:const Icon(Icons.check),label:const Text('Aprobar')):null,
         ));
        }),
      ])),
      Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cerrar')))
     ])))));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
 }
 Future<void> publish(int id)async{
  try{await ref.read(eventosApiProvider).publicar(id);await load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
 }
 Future<void> cancel(int id)async{
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Cancelar evento'),content:const Text('No se permite cancelar eventos con reservas confirmadas sin gestionar primero las devoluciones.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Volver')),
    TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cancelar evento'))]));
  if(confirmed!=true)return;
  try{await ref.read(eventosApiProvider).cancelar(id);await load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(niceEventError(e))));}
 }
 String _date(Object? raw){
  final d=DateTime.tryParse(raw?.toString()??'');
  return d==null?'Sin definir':DateFormat('d MMM yyyy · h:mm a','es_CO').format(d);
 }
 Widget _event(Map<String,dynamic> item){
  final id=asId(item['even_id']);
  final status=item['even_estado']?.toString()??'BORRADOR';
  final published=status=='PUBLICADO',draft=status=='BORRADOR';
  final start=DateTime.tryParse(item['even_inicio']?.toString()??'');
  final color=published?const Color(0xff58e2af):
    draft?const Color(0xffffd186):const Color(0xfff79b9b);
  final value=double.tryParse(item['even_precio']?.toString()??'')??0;
  final cost=value==0?'Gratis':NumberFormat.currency(
    locale:'es_CO',symbol:'COP ',decimalDigits:0).format(value);
  return Container(
   margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(20),
   decoration:BoxDecoration(color:eventSurface,borderRadius:BorderRadius.circular(20),
    border:Border.all(color:eventBorder)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Container(width:69,height:76,
      decoration:BoxDecoration(color:const Color(0xff1a4657),
       borderRadius:BorderRadius.circular(14)),
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
       Text(start==null?'--':DateFormat('dd').format(start),
        style:const TextStyle(color:eventText,fontSize:28,fontWeight:FontWeight.w900)),
       Text(start==null?'MES':DateFormat('MMM','es_CO').format(start).toUpperCase(),
        style:const TextStyle(color:sea,fontSize:11,fontWeight:FontWeight.w800)),
      ])),
     const SizedBox(width:16),
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(item['even_titulo']?.toString()??'Evento',
       style:const TextStyle(color:eventText,fontSize:19,fontWeight:FontWeight.w800),
       maxLines:2,overflow:TextOverflow.ellipsis),
      const SizedBox(height:7),
      Wrap(spacing:8,runSpacing:8,children:[
       Chip(label:Text(published?'Publicado':draft?'Borrador':'Cancelado',
         style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:12)),
        backgroundColor:color.withOpacity(.1),
        side:BorderSide(color:color.withOpacity(.25)),
        visualDensity:VisualDensity.compact),
       Chip(label:Text(cost,style:const TextStyle(color:eventSecondary,fontSize:12)),
        backgroundColor:const Color(0xff1b3a4a),
        side:const BorderSide(color:eventBorder),visualDensity:VisualDensity.compact),
      ]),
     ])),
    ]),
    const SizedBox(height:17),
    Wrap(spacing:10,runSpacing:9,children:[
     _eventInfo(Icons.calendar_today_outlined,'Inicio: '+_date(item['even_inicio'])),
     _eventInfo(Icons.schedule_outlined,'Finaliza: '+_date(item['even_fin'])),
     _eventInfo(Icons.payments_outlined,
       item['even_medio_pago']=='GRATIS'?'Acceso gratis':
       item['even_medio_pago']=='MANUAL'?'Pago manual':'Pago electrónico'),
    ]),
    const SizedBox(height:16),
    const Divider(color:eventBorder,height:1),
    const SizedBox(height:13),
    Wrap(spacing:8,runSpacing:9,children:[
     OutlinedButton.icon(onPressed:id==null?null:()=>detail(id),
      icon:const Icon(Icons.groups_outlined,size:18),label:const Text('Ver reservas'),
      style:OutlinedButton.styleFrom(foregroundColor:eventText,
       side:const BorderSide(color:eventBorder))),
     if(draft)...[
      OutlinedButton.icon(onPressed:id==null?null:()async{
       try{
        final event=await ref.read(eventosApiProvider).detalle(id);
        if(mounted)editor(event);
       }catch(e){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content:Text(niceEventError(e))));
       }
      },icon:const Icon(Icons.edit_outlined,size:18),label:const Text('Editar'),
       style:OutlinedButton.styleFrom(foregroundColor:eventText,
        side:const BorderSide(color:eventBorder))),
      FilledButton.icon(onPressed:id==null?null:()=>publish(id),
       icon:const Icon(Icons.public,size:18),label:const Text('Publicar'),
       style:FilledButton.styleFrom(backgroundColor:sea,
        foregroundColor:const Color(0xff072532))),
     ],
     if(published)...[
      FilledButton.tonalIcon(
       onPressed:()=>shareEvent(item),
       icon:const Icon(Icons.share_outlined,size:18),label:const Text('Compartir')),
      OutlinedButton.icon(
       onPressed:()=>context.go('/evento/'+item['even_slug'].toString()),
       icon:const Icon(Icons.open_in_new,size:18),label:const Text('Ver página'),
       style:OutlinedButton.styleFrom(foregroundColor:eventText,
        side:const BorderSide(color:eventBorder))),
      TextButton.icon(onPressed:id==null?null:()=>cancel(id),
       icon:const Icon(Icons.cancel_outlined,size:18),label:const Text('Cancelar'),
       style:TextButton.styleFrom(foregroundColor:const Color(0xffffb4b4))),
     ],
    ]),
   ]),
  );
 }
 Widget _eventInfo(IconData icon,String label)=>Container(
  padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
  decoration:BoxDecoration(color:const Color(0xff1b3b4b),
   borderRadius:BorderRadius.circular(11)),
  child:Row(mainAxisSize:MainAxisSize.min,children:[
   Icon(icon,color:eventSecondary,size:17),const SizedBox(width:8),
   Text(label,style:const TextStyle(color:eventText,fontSize:12)),
  ]),
 );
 Widget _stat(IconData icon,String title,int value,Color color)=>Container(
  padding:const EdgeInsets.all(19),
  decoration:BoxDecoration(color:eventSurface,borderRadius:BorderRadius.circular(18),
   border:Border.all(color:eventBorder)),
  child:Row(children:[
   Container(width:44,height:44,
    decoration:BoxDecoration(color:color.withOpacity(.14),
     borderRadius:BorderRadius.circular(13)),
    child:Icon(icon,color:color,size:23)),
   const SizedBox(width:14),
   Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(color:eventSecondary,fontSize:13)),
    Text(value.toString(),style:const TextStyle(
     color:eventText,fontSize:25,fontWeight:FontWeight.w800)),
   ]),
  ]),
 );
 Widget _empty(bool filtered)=>Container(
  width:double.infinity,
  padding:const EdgeInsets.symmetric(horizontal:22,vertical:35),
  decoration:BoxDecoration(color:eventSurface,
   borderRadius:BorderRadius.circular(22),border:Border.all(color:eventBorder)),
  child:Column(children:[
   Container(width:90,height:90,
    decoration:BoxDecoration(
     gradient:const LinearGradient(colors:[Color(0xff166071),Color(0xff173a4b)]),
     borderRadius:BorderRadius.circular(26)),
    child:Icon(filtered?Icons.search_off_rounded:Icons.celebration_outlined,
     color:sea,size:46)),
   const SizedBox(height:19),
   Text(filtered?'No encontramos eventos con estos filtros':
    'Tu próximo gran evento comienza aquí',
    style:const TextStyle(color:eventText,fontSize:21,fontWeight:FontWeight.w800),
    textAlign:TextAlign.center),
   const SizedBox(height:10),
   ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),
    child:Text(filtered?'Cambia el nombre o el estado del filtro.':
     'Crea una experiencia, selecciona las mesas disponibles y comparte un enlace para recibir reservas y pagos.',
     style:const TextStyle(color:eventSecondary,height:1.5),
     textAlign:TextAlign.center)),
   const SizedBox(height:20),
   if(filtered)OutlinedButton.icon(onPressed:()=>setState((){
    filter='TODOS';search='';searchController.clear();
   }),icon:const Icon(Icons.filter_alt_off_outlined),label:const Text('Limpiar filtros'))
   else FilledButton.icon(onPressed:()=>editor(),
    icon:const Icon(Icons.add_circle_outline),
    label:const Text('Crear mi primer evento'),
    style:FilledButton.styleFrom(backgroundColor:sea,
     foregroundColor:const Color(0xff072532),
     padding:const EdgeInsets.symmetric(horizontal:23,vertical:15))),
   if(!filtered)...[
    const SizedBox(height:23),
    const Wrap(alignment:WrapAlignment.center,spacing:18,runSpacing:9,children:[
     _EventHint(Icons.calendar_month_outlined,'Fechas y horarios'),
     _EventHint(Icons.table_restaurant_outlined,'Mesas disponibles'),
     _EventHint(Icons.qr_code_2,'Reservas con QR'),
    ]),
   ],
  ]),
 );

 @override Widget build(BuildContext context){
  final published=entries.where((e)=>e['even_estado']=='PUBLICADO').length;
  final draft=entries.where((e)=>e['even_estado']=='BORRADOR').length;
  final query=search.trim().toLowerCase();
  final items=entries.where((e)=>
   (filter=='TODOS'||e['even_estado']==filter) &&
   (query.isEmpty||(e['even_titulo']?.toString().toLowerCase().contains(query)??false))
  ).toList();
  return Scaffold(backgroundColor:Colors.transparent,
   body:RefreshIndicator(onRefresh:load,
    child:Center(child:ConstrainedBox(
     constraints:const BoxConstraints(maxWidth:1220),
     child:ListView(padding:const EdgeInsets.fromLTRB(20,24,20,52),children:[
      Container(padding:const EdgeInsets.all(27),
       decoration:BoxDecoration(
        gradient:const LinearGradient(begin:Alignment.topLeft,
         end:Alignment.bottomRight,colors:[
          Color(0xff15475a),Color(0xff0a2638),Color(0xff104052)]),
        borderRadius:BorderRadius.circular(23),
        border:Border.all(color:const Color(0xff3a6b7a))),
       child:Wrap(
        alignment:WrapAlignment.spaceBetween,spacing:18,runSpacing:20,
        crossAxisAlignment:WrapCrossAlignment.center,children:[
         ConstrainedBox(constraints:const BoxConstraints(maxWidth:600),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           const Row(mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.auto_awesome_outlined,color:sea,size:17),
            SizedBox(width:8),
            Text('TU AGENDA DE EXPERIENCIAS',
             style:TextStyle(color:sea,letterSpacing:1.5,
              fontSize:11,fontWeight:FontWeight.w800)),
           ]),
           const SizedBox(height:12),
           const Text('Haz que cada evento sea inolvidable',
            style:TextStyle(color:eventText,fontSize:25,
             fontWeight:FontWeight.w900,height:1.2)),
           const SizedBox(height:9),
           const Text('Organiza fechas especiales, aparta mesas y recibe reservas desde una página pública con la identidad de tu negocio.',
            style:TextStyle(color:eventSecondary,height:1.5,fontSize:14)),
          ])),
         Wrap(spacing:9,runSpacing:9,children:[
          OutlinedButton.icon(onPressed:paymentConfig,
           icon:const Icon(Icons.account_balance_wallet_outlined,size:19),
           label:const Text('Configurar cobros'),
           style:OutlinedButton.styleFrom(foregroundColor:eventText,
            side:const BorderSide(color:Color(0xff73909e)),
            padding:const EdgeInsets.symmetric(horizontal:18,vertical:16))),
          FilledButton.icon(onPressed:()=>editor(),
           icon:const Icon(Icons.add_circle_outline,size:19),
           label:const Text('Nuevo evento'),
           style:FilledButton.styleFrom(backgroundColor:sea,
            foregroundColor:const Color(0xff072532),
            padding:const EdgeInsets.symmetric(horizontal:20,vertical:16))),
         ]),
        ])),
      const SizedBox(height:20),
      if(loading)const Padding(padding:EdgeInsets.only(top:76),
       child:Column(children:[
        CircularProgressIndicator(color:sea),
        SizedBox(height:16),
        Text('Cargando tus eventos…',style:TextStyle(color:eventSecondary)),
       ])),
      if(error!=null)Container(padding:const EdgeInsets.all(24),
       decoration:BoxDecoration(color:eventSurface,
        borderRadius:BorderRadius.circular(20),
        border:Border.all(color:const Color(0xffb37b60))),
       child:Wrap(spacing:16,runSpacing:13,
        crossAxisAlignment:WrapCrossAlignment.center,children:[
         const Icon(Icons.cloud_off_rounded,size:34,color:Color(0xffffbf9c)),
         ConstrainedBox(constraints:const BoxConstraints(maxWidth:700),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           const Text('No pudimos cargar tus eventos',
            style:TextStyle(color:eventText,fontSize:17,
             fontWeight:FontWeight.w800)),
           const SizedBox(height:6),
           Text(error!,style:const TextStyle(
            color:eventSecondary,height:1.5)),
          ])),
         OutlinedButton.icon(onPressed:load,
          icon:const Icon(Icons.refresh),label:const Text('Reintentar'),
          style:OutlinedButton.styleFrom(foregroundColor:eventText,
           side:const BorderSide(color:eventBorder))),
        ])),
      if(!loading&&error==null)...[
       LayoutBuilder(builder:(context,box){
        final width=box.maxWidth<700?box.maxWidth:(box.maxWidth-24)/3;
        return Wrap(spacing:12,runSpacing:12,children:[
         SizedBox(width:width,child:_stat(Icons.calendar_month_outlined,
          'Eventos creados',entries.length,sea)),
         SizedBox(width:width,child:_stat(Icons.check_circle_outline,
          'Publicados',published,const Color(0xff58e2af))),
         SizedBox(width:width,child:_stat(Icons.edit_calendar_outlined,
          'En preparación',draft,const Color(0xffffd186))),
        ]);
       }),
       const SizedBox(height:25),
       Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Text('Tus eventos',style:TextStyle(
         color:eventText,fontSize:21,fontWeight:FontWeight.w800)),
        Text(entries.length.toString()+' registrados',
         style:const TextStyle(color:eventSecondary,fontSize:13)),
       ]),
       const SizedBox(height:14),
       if(entries.isNotEmpty)...[
        Wrap(crossAxisAlignment:WrapCrossAlignment.center,
         spacing:10,runSpacing:10,children:[
          SizedBox(width:295,child:TextField(
           controller:searchController,
           onChanged:(v)=>setState(()=>search=v),
           style:const TextStyle(color:eventText),
           decoration:InputDecoration(hintText:'Buscar eventos',
            hintStyle:const TextStyle(color:eventSecondary),
            prefixIcon:const Icon(Icons.search,color:eventSecondary),
            filled:true,fillColor:eventSurface,
            enabledBorder:OutlineInputBorder(
             borderRadius:BorderRadius.circular(12),
             borderSide:const BorderSide(color:eventBorder)),
            border:OutlineInputBorder(
             borderRadius:BorderRadius.circular(12),
             borderSide:const BorderSide(color:eventBorder))))),
          for(final option in const [
           ('TODOS','Todos'),('PUBLICADO','Publicados'),
           ('BORRADOR','Borradores'),('CANCELADO','Cancelados')])
           ChoiceChip(label:Text(option.$2),
            selected:filter==option.$1,
            onSelected:(_)=>setState(()=>filter=option.$1),
            backgroundColor:eventSurface,
            selectedColor:const Color(0xff196778),
            side:BorderSide(color:filter==option.$1?sea:eventBorder),
            labelStyle:TextStyle(color:filter==option.$1?eventText:eventSecondary)),
         ]),
        const SizedBox(height:18),
       ],
       if(entries.isEmpty)_empty(false)
       else if(items.isEmpty)_empty(true)
       else for(final item in items)_event(item),
      ],
     ]),
    )),
   ),
  );
 }
}

class _EventHint extends StatelessWidget{
 const _EventHint(this.icon,this.label);
 final IconData icon;
 final String label;
 @override Widget build(BuildContext context)=>Row(
  mainAxisSize:MainAxisSize.min,children:[
   Icon(icon,color:sea,size:16),
   const SizedBox(width:7),
   Text(label,style:const TextStyle(color:eventSecondary,fontSize:12)),
  ],
 );
}

class EventoEditor extends ConsumerStatefulWidget{
 const EventoEditor({super.key,required this.onSaved,this.initial});
 final Map<String,dynamic>? initial;
 final ValueChanged<Map<String,dynamic>> onSaved;
 @override ConsumerState<EventoEditor> createState()=>_EventEditorState();
}
class _EventEditorState extends ConsumerState<EventoEditor>{
 final form=GlobalKey<FormState>();
 final title=TextEditingController(),description=TextEditingController(),
       amount=TextEditingController(text:'0'),instructions=TextEditingController(),
       mapsUrl=TextEditingController();
 DateTime start=DateTime.now().add(const Duration(days:1)).copyWith(hour:20,minute:0),
   finish=DateTime.now().add(const Duration(days:2)).copyWith(hour:2,minute:0);
 String method='GRATIS';String? photo;bool publish=false,busy=false;
 int? branch;Set<int> chosen={};List<Map<String,dynamic>> tables=[];
 Map<int,int> capacities={};List<String> venuePhotos=[];
 @override void initState(){
  super.initState();
  final i=widget.initial;
  if(i!=null){
   title.text=i['even_titulo']?.toString()??'';description.text=i['even_descripcion']?.toString()??'';
   amount.text=i['even_precio']?.toString()??'0';
   instructions.text=i['even_instrucciones_pago']?.toString()??'';
   photo=i['even_imagen']?.toString();method=i['even_medio_pago']?.toString()??'GRATIS';
   start=DateTime.tryParse(i['even_inicio']?.toString()??'')??start;
   finish=DateTime.tryParse(i['even_fin']?.toString()??'')??finish;
   branch=asId(i['sucu_id']);
   chosen=(i['mesas'] as List? ??[]).map(asId).whereType<int>().toSet();
   mapsUrl.text=i['even_maps_url']?.toString()??'';
   capacities=(i['capacidadesMesas'] as Map? ??{}).map((key,value)=>
    MapEntry(int.tryParse(key.toString())??-1,asId(value)??6))..remove(-1);
   venuePhotos=(i['fotosLugar'] as List? ??[]).whereType<String>().toList();
  }
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_loadTables();});
 }
 @override void dispose(){title.dispose();description.dispose();amount.dispose();instructions.dispose();mapsUrl.dispose();super.dispose();}
 Future<void> _loadTables()async{
  final branchState=ref.read(branchScopeProvider);
  branch??=branchState.activeBranchId;
  if(branch==null)return;
  try{final t=await ref.read(eventosApiProvider).mesas(branch!);
    if(mounted)setState(()=>tables=t.where((e)=>e['mesaEstado']?.toString().toUpperCase()!='INACTIVA').toList());
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Mesas: '+niceEventError(e))));}
 }
 Future<void> _venueImage()async{
  final files=await FilePicker.platform.pickFiles(allowMultiple:true,
   type:FileType.image,withData:true);
  if(files==null)return;
  final next=<String>[];
  for(final file in files.files){
   if(file.bytes==null||file.size>700000){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content:Text('Máximo 700 KB por foto')));
    return;
   }
   final ext=file.extension?.toLowerCase();
   if(!['jpg','jpeg','png','webp'].contains(ext)){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content:Text('Solo JPG, PNG o WebP')));
    return;
   }
   final mime=ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg';
   next.add('data:'+mime+';base64,'+base64Encode(file.bytes!));
  }
  if(venuePhotos.length+next.length>4){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Se admiten máximo cuatro fotos del establecimiento')));
   return;
  }
  if(mounted)setState(()=>venuePhotos=[...venuePhotos,...next]);
 }
 ImageProvider? _photoSource(String raw){
  try{
   if(raw.startsWith('data:image/')&&raw.contains(',')){
    return MemoryImage(base64Decode(raw.substring(raw.indexOf(',')+1)));
   }
   if(raw.startsWith('https://'))return NetworkImage(raw);
  }catch(_){}
  return null;
 }
 Future<void> _pick(bool beginning,bool date)async{
  final original=beginning?start:finish;
  if(date){
   final selected=await showDatePicker(context:context,initialDate:original,firstDate:DateTime(2020),lastDate:DateTime(2100));
   if(selected==null)return;
   setState((){
    final v=DateTime(selected.year,selected.month,selected.day,original.hour,original.minute);
    if(beginning)start=v;else finish=v;
   });
  }else{
   final selected=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(original));
   if(selected==null)return;
   setState((){
    final v=DateTime(original.year,original.month,original.day,selected.hour,selected.minute);
    if(beginning)start=v;else finish=v;
   });
  }
 }
 Future<void> _image()async{
  final result=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);
  final file=result?.files.singleOrNull;
  if(file==null||file.bytes==null)return;
  if(file.size>1900000){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La imagen debe pesar menos de 1.9 MB')));
   return;
  }
  final ext=file.extension?.toLowerCase();
  final mime=ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg';
  setState(()=>photo='data:'+mime+';base64,'+base64Encode(file.bytes!));
 }
 Future<void> _save()async{
  if(busy||!(form.currentState?.validate()??false))return;
  final location=Uri.tryParse(mapsUrl.text.trim());
  if(location==null||location.scheme!='https'||
   !const ['maps.app.goo.gl','goo.gl','maps.google.com','google.com','www.google.com'].contains(location.host.toLowerCase())){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Pega un enlace de ubicación válido de Google Maps')));return;
  }
  if(branch==null||chosen.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Selecciona sucursal y por lo menos una mesa')));return;}
  if(!finish.isAfter(start)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La fecha/hora de fin debe ser posterior al inicio')));return;}
  final price=double.tryParse(amount.text.replaceAll(',','.'))??-1;
  if(price<0||(method=='GRATIS'&&price!=0)||(method!='GRATIS'&&price<=0)){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Verifica el precio y el medio de pago')));return;
  }
  setState(()=>busy=true);
  try{
   final body={'sucursalId':branch,'titulo':title.text.trim(),'descripcion':description.text.trim(),
    'imagen':photo,'inicio':start.toIso8601String(),'fin':finish.toIso8601String(),
    'precio':price,'medioPago':method,'instruccionesPago':instructions.text.trim(),
    'mesas':chosen.toList(),'publicar':publish,
    'googleMapsUrl':mapsUrl.text.trim(),'fotosLugar':venuePhotos,
    'capacidadesMesas':{for(final id in chosen)id.toString():capacities[id]??6}};
   final api=ref.read(eventosApiProvider);
   final result=widget.initial==null
     ?await api.crear(body)
     :await api.cambiar(asId(widget.initial!['even_id'])!,body);
   if(!mounted)return;
   widget.onSaved({
    'even_id':result['id']??widget.initial?['even_id'],
    'even_slug':result['slug']??widget.initial?['even_slug'],
    'even_titulo':title.text.trim(),
    'even_inicio':start.toIso8601String(),
    'even_fin':finish.toIso8601String(),
    'even_estado':publish?'PUBLICADO':'BORRADOR',
    'even_precio':price,
    'even_medio_pago':method,
    'sucu_id':branch,
   });
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se guardó: '+niceEventError(e))));}
  finally{if(mounted)setState(()=>busy=false);}
 }

 Widget _block(int number,String title,String subtitle,Widget child){
   return EventPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     EventSectionHeading(number:number,title:title,subtitle:subtitle),
     const SizedBox(height:17),child,
   ]));
 }
 Widget _dateButton(String label,String value,IconData icon,VoidCallback action){
   return InkWell(onTap:action,borderRadius:BorderRadius.circular(12),
     child:Container(padding:const EdgeInsets.all(13),
       decoration:BoxDecoration(color:EventColors.surfaceLight,
         borderRadius:BorderRadius.circular(12),
         border:Border.all(color:EventColors.border)),
       child:Row(children:[
         Icon(icon,color:EventColors.primary,size:21),const SizedBox(width:11),
         Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text(label,style:const TextStyle(color:EventColors.muted,fontSize:10)),
           const SizedBox(height:4),
           Text(value,style:const TextStyle(color:EventColors.text,
             fontWeight:FontWeight.w800,fontSize:13)),
         ])),
         const Icon(Icons.expand_more,color:EventColors.muted,size:16),
       ])));
 }
 Widget _general(List<dynamic> branches,double width){
   final details=Column(children:[
     TextFormField(controller:title,maxLength:180,
       decoration:const InputDecoration(labelText:'Nombre del evento *',
         prefixIcon:Icon(Icons.celebration_outlined)),
       validator:(v)=>(v?.trim().isEmpty??true)?'Escribe el nombre del evento':null),
     const SizedBox(height:10),
     TextFormField(controller:description,maxLines:3,maxLength:1200,
       decoration:const InputDecoration(
         labelText:'Descripción y experiencia',alignLabelWithHint:true)),
     const SizedBox(height:12),
     TextFormField(controller:mapsUrl,
       decoration:const InputDecoration(labelText:'Ubicación en Google Maps *',
         prefixIcon:Icon(Icons.location_on_outlined),
         hintText:'https://maps.app.goo.gl/...'),
       validator:(v)=>(v?.trim().isEmpty??true)?'Pega la ubicación de Google Maps':null),
     const SizedBox(height:8),
     const Align(alignment:Alignment.centerLeft,
       child:Text('En Google Maps selecciona Compartir → Copiar enlace.',
         style:TextStyle(color:EventColors.muted,fontSize:11))),
     const SizedBox(height:16),
     DropdownButtonFormField<int>(value:branch,
       decoration:const InputDecoration(labelText:'Sucursal *',
         prefixIcon:Icon(Icons.storefront_outlined)),
       items:branches.where((e)=>e.sucuId!=null).map<DropdownMenuItem<int>>((v)=>
         DropdownMenuItem<int>(value:v.sucuId,child:Text(v.sucuNombre??'Sucursal'))).toList(),
       onChanged:(v){setState((){
         branch=v;tables=[];chosen={};capacities={};
       });_loadTables();}),
   ]);
   final media=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('Afiche o portada del evento',
       style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
     const SizedBox(height:8),
     Stack(children:[
       EventArtwork(source:photo,width:double.infinity,height:178),
       if(photo!=null)Positioned(right:7,top:7,
         child:IconButton.filledTonal(
           onPressed:()=>setState(()=>photo=null),
           icon:const Icon(Icons.delete_outline,size:18))),
     ]),
     const SizedBox(height:8),
     SizedBox(width:double.infinity,child:OutlinedButton.icon(
       onPressed:busy?null:_image,icon:const Icon(Icons.upload_file_outlined),
       label:Text(photo==null?'Cargar afiche':'Cambiar afiche'))),
     const SizedBox(height:14),
     Row(children:[
       const Expanded(child:Text('Fotos del establecimiento',
         style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w700))),
       TextButton.icon(
         onPressed:venuePhotos.length>=4?null:_venueImage,
         icon:const Icon(Icons.add_photo_alternate_outlined,size:16),
         label:const Text('Agregar')),
     ]),
     SizedBox(height:100,child:ListView.separated(
       scrollDirection:Axis.horizontal,
       itemCount:venuePhotos.length<4?venuePhotos.length+1:venuePhotos.length,
       separatorBuilder:(_,__)=>const SizedBox(width:8),
       itemBuilder:(context,i){
         if(i==venuePhotos.length)return InkWell(onTap:_venueImage,
           child:Container(width:100,
             decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),
               border:Border.all(color:EventColors.primary)),
             child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[
               Icon(Icons.add_photo_alternate_outlined,color:EventColors.primary),
               SizedBox(height:5),
               Text('Agregar fotos',style:TextStyle(
                 fontSize:10,color:EventColors.primary)),
             ])));
         return SizedBox(width:132,child:Stack(children:[
           EventArtwork(source:venuePhotos[i],width:132,height:100),
           Positioned(right:2,top:2,child:IconButton.filledTonal(
             onPressed:()=>setState(()=>venuePhotos.removeAt(i)),
             constraints:const BoxConstraints(minWidth:30,minHeight:30),
             padding:EdgeInsets.zero,icon:const Icon(Icons.close,size:15))),
         ]));
       },
     )),
   ]);
   return _block(1,'Información general',
     'Da identidad al evento: foto, lugar, nombre y descripción.',
     width>635?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Expanded(flex:6,child:details),const SizedBox(width:17),
       Expanded(flex:5,child:media),
     ]):Column(children:[details,const SizedBox(height:17),media]));
 }
 Widget _dates()=>_block(2,'Fecha y horario',
   'Elige cuándo comienza y termina tu evento.',
   LayoutBuilder(builder:(context,box){
     final count=box.maxWidth>680?4:box.maxWidth>330?2:1;
     final w=(box.maxWidth-10*(count-1))/count;
     return Wrap(spacing:10,runSpacing:10,children:[
       SizedBox(width:w,child:_dateButton('Fecha de inicio',dateLabel(start),
         Icons.calendar_month_outlined,()=>_pick(true,true))),
       SizedBox(width:w,child:_dateButton('Hora de inicio',hourLabel(start),
         Icons.schedule_outlined,()=>_pick(true,false))),
       SizedBox(width:w,child:_dateButton('Fecha de fin',dateLabel(finish),
         Icons.event_available_outlined,()=>_pick(false,true))),
       SizedBox(width:w,child:_dateButton('Hora de fin',hourLabel(finish),
         Icons.nights_stay_outlined,()=>_pick(false,false))),
     ]);
   }));
 Widget _tables()=>_block(3,'Mesas habilitadas',
   'Selecciona las mesas y define su capacidad de puestos.',
   Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Align(alignment:Alignment.centerRight,child:TextButton.icon(
       onPressed:tables.isEmpty?null:()=>setState((){
         final all=tables.every((m)=>chosen.contains(asId(m['mesaId'])));
         if(all){chosen.clear();capacities.clear();}
         else{for(final m in tables){
           final id=asId(m['mesaId']);
           if(id!=null){chosen.add(id);capacities.putIfAbsent(id,()=>6);}
         }}
       }),
       icon:const Icon(Icons.select_all,size:18),
       label:const Text('Seleccionar / quitar todas'))),
     if(tables.isEmpty)const Padding(
       padding:EdgeInsets.all(22),
       child:Center(child:Text('No se encontraron mesas de esta sucursal.',
         style:TextStyle(color:EventColors.muted))))
     else GridView.builder(
       shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
       itemCount:tables.length,
       gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent:185,mainAxisExtent:198,
         mainAxisSpacing:10,crossAxisSpacing:10),
       itemBuilder:(ctx,i){
         final m=tables[i],id=asId(m['mesaId']);
         if(id==null)return const SizedBox.shrink();
         final active=chosen.contains(id);
         return Container(
           clipBehavior:Clip.antiAlias,
           decoration:BoxDecoration(
             color:active?const Color(0xFF17495A):EventColors.surfaceLight,
             borderRadius:BorderRadius.circular(13),
             border:Border.all(color:active?EventColors.primary:EventColors.border,
               width:active?1.8:1)),
           child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
             Expanded(child:InkWell(
               onTap:()=>setState((){
                 if(active){chosen.remove(id);capacities.remove(id);}
                 else{chosen.add(id);capacities.putIfAbsent(id,()=>6);}
               }),
               child:Stack(children:[
                 Positioned.fill(child:EventArtwork(
                   source:m['mesaFoto'],height:115,
                   borderRadius:0,emptyIcon:Icons.table_restaurant_outlined)),
                 Positioned(left:6,top:6,child:Container(
                   decoration:BoxDecoration(
                     color:active?EventColors.primary:EventColors.background,
                     borderRadius:BorderRadius.circular(7)),
                   padding:const EdgeInsets.all(5),
                   child:Icon(active?Icons.check:Icons.add,size:15,
                     color:active?EventColors.onPrimary:EventColors.muted))),
               ]))),
             Padding(padding:const EdgeInsets.fromLTRB(10,8,10,0),
               child:Text('Mesa '+(m['mesaNumero']??id).toString(),
                 style:const TextStyle(color:EventColors.text,
                   fontWeight:FontWeight.w800,fontSize:12))),
             SizedBox(height:43,child:Padding(
               padding:const EdgeInsets.symmetric(horizontal:9),
               child:DropdownButtonHideUnderline(child:DropdownButton<int>(
                 isExpanded:true,isDense:true,value:capacities[id]??6,
                 dropdownColor:EventColors.surfaceLight,
                 style:const TextStyle(color:EventColors.text,fontSize:12),
                 items:List.generate(30,(x)=>DropdownMenuItem<int>(
                   value:x+1,child:Text((x+1).toString()+' puestos'))),
                 onChanged:active?(v){if(v!=null)setState(()=>capacities[id]=v);}:null,
               )))),
           ]),
         );
       }),
   ]));
 Widget _paymentOption(String value,IconData icon,String name,String subtitle){
   final active=method==value;
   return InkWell(onTap:()=>setState((){
     method=value;if(method=='GRATIS')amount.text='0';
   }),child:Container(
     padding:const EdgeInsets.all(13),
     decoration:BoxDecoration(
       color:active?EventColors.primary:EventColors.surfaceLight,
       borderRadius:BorderRadius.circular(12),
       border:Border.all(color:active?EventColors.primary:EventColors.border)),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Icon(icon,color:active?EventColors.onPrimary:EventColors.primary,size:23),
       const SizedBox(height:6),
       Text(name,style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,
         color:active?EventColors.onPrimary:EventColors.text)),
       Text(subtitle,style:TextStyle(fontSize:10,
         color:active?EventColors.onPrimary:EventColors.muted)),
     ]),
   ));
 }
 Widget _payments()=>_block(4,'Reservas y pagos',
   'Configura cómo reservar y el precio por cada puesto.',
   Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     LayoutBuilder(builder:(context,box){
       final columns=box.maxWidth>485?3:1;
       final w=(box.maxWidth-(columns-1)*9)/columns;
       return Wrap(spacing:9,runSpacing:9,children:[
         SizedBox(width:w,child:_paymentOption('GRATIS',
           Icons.celebration_outlined,'Gratis','Reserva sin costo')),
         SizedBox(width:w,child:_paymentOption('MANUAL',
           Icons.payments_outlined,'Pago manual','Revisión del negocio')),
         SizedBox(width:w,child:_paymentOption('MERCADOPAGO',
           Icons.credit_card_outlined,'Pago electrónico','Mercado Pago / PSE')),
       ]);
     }),
     const SizedBox(height:16),
     TextFormField(controller:amount,readOnly:method=='GRATIS',
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>setState((){}),
       decoration:const InputDecoration(
         labelText:'Precio por puesto (COP)',prefixIcon:Icon(Icons.attach_money),
         helperText:'Total = precio por puesto × cantidad de puestos reservados')),
     if(method=='MANUAL')...[
       const SizedBox(height:13),
       TextFormField(controller:instructions,maxLines:3,
         decoration:const InputDecoration(labelText:'Instrucciones de pago manual',
           alignLabelWithHint:true)),
     ],
   ]));
 Widget _summary(){
   final capacity=chosen.fold<int>(0,(n,id)=>n+(capacities[id]??6));
   final unit=double.tryParse(amount.text.replaceAll(',','.'))??0;
   return EventPanel(background:const Color(0xFF0A2637),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       const EventSectionHeading(icon:Icons.fact_check_outlined,
         title:'Resumen del evento',
         subtitle:'Todo listo para dar vida a tu experiencia.'),
       const SizedBox(height:22),
       EventMetric(icon:Icons.table_restaurant_outlined,
         label:'Mesas seleccionadas',value:chosen.length.toString()),
       const Divider(color:EventColors.border,height:28),
       EventMetric(icon:Icons.groups_outlined,
         label:'Capacidad total',value:capacity.toString()+' puestos'),
       const Divider(color:EventColors.border,height:28),
       EventMetric(icon:Icons.payments_outlined,label:'Precio por puesto',
         value:method=='GRATIS'?'Gratis':
           NumberFormat.currency(locale:'es_CO',symbol:'COP ',decimalDigits:0).format(unit)),
       const Divider(color:EventColors.border,height:28),
       const EventMetric(icon:Icons.public_outlined,label:'Página pública',
         value:'Lista al publicar',color:EventColors.success),
       const SizedBox(height:17),
       const Text('Los asistentes verán el afiche, el lugar y las mesas reales. Podrán elegir puestos y compartir el evento.',
         style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5)),
     ]));
 }

 @override Widget build(BuildContext context){
   final branches=ref.watch(branchScopeProvider).branches;
   return Theme(
     data:ThemeData.dark(useMaterial3:true).copyWith(
       colorScheme:const ColorScheme.dark(
         primary:EventColors.primary,surface:EventColors.surface),
       inputDecorationTheme:InputDecorationTheme(
         filled:true,fillColor:EventColors.surfaceLight,
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(11)),
         enabledBorder:OutlineInputBorder(
           borderRadius:BorderRadius.circular(11),
           borderSide:const BorderSide(color:EventColors.border)),
         contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
         labelStyle:const TextStyle(color:EventColors.muted),
       )),
     child:Form(key:form,child:LayoutBuilder(builder:(context,box){
       final wide=box.maxWidth>=1000;
       return Column(children:[
         Container(padding:const EdgeInsets.symmetric(horizontal:19,vertical:17),
           decoration:const BoxDecoration(
             gradient:LinearGradient(colors:[
               Color(0xFF10485A),Color(0xFF0C2B3E),Color(0xFF103B4D)]),
             border:Border(bottom:BorderSide(color:EventColors.border))),
           child:Row(children:[
             Container(width:45,height:45,
               decoration:BoxDecoration(
                 color:EventColors.primary.withOpacity(.15),
                 borderRadius:BorderRadius.circular(13)),
               child:const Icon(Icons.event_available_outlined,color:EventColors.primary)),
             const SizedBox(width:12),
             Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
               Text(widget.initial==null?'Crear nuevo evento':'Editar evento',
                 style:const TextStyle(color:EventColors.text,
                   fontSize:21,fontWeight:FontWeight.w900)),
               const SizedBox(height:3),
               const Text('Crea una experiencia única y recibe reservas en línea desde tu página pública.',
                 maxLines:2,style:TextStyle(color:EventColors.muted,fontSize:12)),
             ])),
             if(wide)const EventPill(icon:Icons.edit_note_outlined,label:'Borrador'),
             const SizedBox(width:7),
             IconButton(onPressed:busy?null:()=>Navigator.pop(context),
               icon:const Icon(Icons.close,color:EventColors.text)),
           ])),
         Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Expanded(child:ListView(padding:const EdgeInsets.all(13),children:[
             LayoutBuilder(builder:(context,inner)=>
               _general(branches,inner.maxWidth)),
             const SizedBox(height:12),_dates(),
             const SizedBox(height:12),_tables(),
             const SizedBox(height:12),_payments(),
             if(!wide)...[const SizedBox(height:12),_summary()],
             const SizedBox(height:22),
           ])),
           if(wide)SizedBox(width:303,child:Padding(
             padding:const EdgeInsets.fromLTRB(0,13,13,13),
             child:SingleChildScrollView(child:_summary()))),
         ])),
         Container(padding:const EdgeInsets.fromLTRB(14,11,14,13),
           decoration:const BoxDecoration(color:Color(0xFF082532),
             border:Border(top:BorderSide(color:EventColors.border))),
           child:Wrap(alignment:WrapAlignment.end,spacing:9,runSpacing:8,
             children:[
               OutlinedButton(onPressed:busy?null:()=>Navigator.pop(context),
                 child:const Text('Cancelar')),
               OutlinedButton.icon(onPressed:busy?null:(){
                 setState(()=>publish=false);_save();
               },icon:const Icon(Icons.save_outlined,size:17),
                 label:Text(busy?'Guardando...':'Guardar borrador')),
               FilledButton.icon(
                 onPressed:busy?null:(){setState(()=>publish=true);_save();},
                 style:FilledButton.styleFrom(
                   backgroundColor:EventColors.primary,
                   foregroundColor:EventColors.onPrimary,
                   padding:const EdgeInsets.symmetric(horizontal:20,vertical:14)),
                 icon:const Icon(Icons.send_outlined,size:17),
                 label:Text(busy?'Publicando...':'Publicar evento')),
             ])),
       ]);
     })),
   );
 }
}
