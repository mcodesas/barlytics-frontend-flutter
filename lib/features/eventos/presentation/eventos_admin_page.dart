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
import '../../productos/presentation/pages/productos_form_page.dart';

const sea=Color(0xff24d4ce);
const eventSurface=Color(0xff102e40);
const eventBorder=Color(0xff365a6a);
const eventText=Color(0xffeffaff);
const eventSecondary=Color(0xffb2cad4);
String niceEventError(Object e){
 if(e is DioException){
  final status=e.response?.statusCode;
  final data=e.response?.data;
  String? detail;
  if(data is Map){
   final errors=data['errors'];
   if(errors is List&&errors.isNotEmpty){
    final first=errors.first;
    if(first is Map){
     final message=(first['message']??first['detail'])?.toString();
     final field=first['field']?.toString();
     if(message!=null&&message.trim().isNotEmpty){
      detail=field!=null&&field.isNotEmpty?'$field: $message':message;
     }
    }else if(first is String)detail=first;
   }
   detail??=(data['detail']??data['mensaje'])?.toString();
   if(detail==null){
    final message=data['message']?.toString();
    if(message!=null&&message.toLowerCase()!='error de validación'){
     detail=message;
    }
   }
  }
  if(status==401)return 'La sesión expiró. Ingresa nuevamente.';
  if(status==403)return detail??'No tienes permisos para administrar este evento.';
  if(status==400||status==409||status==422){
   return detail??'Revisa sucursal, mesas, fechas, precio y productos seleccionados.';
  }
  if(status==404)return detail??'El recurso solicitado no está disponible.';
  if(status==500||status==503)return detail??'El servidor no pudo completar la operación. Revisa el backend.';
  if(status==null)return 'No hay conexión con el servidor.';
  return detail??'Operación rechazada (HTTP $status)';
 }
 return 'No se pudo completar la operación: $e';
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
 bool _sucursalDialogOpen=false;
 String filter='TODOS',search='';
 final searchController=TextEditingController();
 @override void initState(){super.initState();load();}
 @override void dispose(){searchController.dispose();super.dispose();}
 int _loadSeq=0;
 Future<void> load({bool keepVisible=false})async{
  final seq=++_loadSeq;
  final branchId=ref.read(branchScopeProvider).activeBranchId;
  if(mounted)setState((){loading=!keepVisible;error=null;});
  try{
   final rows=await ref.read(eventosApiProvider).eventos();
   if(!mounted||seq!=_loadSeq||
      branchId!=ref.read(branchScopeProvider).activeBranchId)return;
   setState((){
     // Segunda barrera visual: nunca presentar filas de otra sucursal,
     // ni siquiera si el servidor entrega datos anteriores por error.
     entries=rows.where((r)=>asId(r['sucu_id'])==branchId).toList();
     loading=false;error=null;
   });
  }catch(e){
   if(!mounted||seq!=_loadSeq||
     branchId!=ref.read(branchScopeProvider).activeBranchId)return;
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
  try{
   final info=await ref.read(eventosApiProvider).pagoConfig();
   if(!mounted)return;
   await showDialog<void>(
    context:context,
    builder:(_)=>_EventPaymentGuide(initial:info),
   );
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(niceEventError(e))));
  }
 }
 Future<void> _retirarReserva(
   int eventId,Map<String,dynamic> row,BuildContext parentDialog)async{
  final branchId=ref.read(branchScopeProvider).activeBranchId;
  final id=asId(row['eres_id']);
  if(id==null||branchId==null)return;
  final status=row['eres_estado']?.toString()??'';
  final hasPayment=(row['eres_pago_id']?.toString().isNotEmpty??false)&&
    (double.tryParse(row['eres_importe']?.toString()??'0')??0)>0;
  final needsRefund=hasPayment&&
    (status=='CONFIRMADA'||status=='REEMBOLSO_PENDIENTE');
  final alreadyRetired=row['eres_retirada']==true;
  final reason=TextEditingController(
    text:row['eres_retiro_motivo']?.toString()??'');
  final reference=TextEditingController();
  bool refundRegistered=false;
  Map<String,dynamic>? result;
  try{
   result=await showDialog<Map<String,dynamic>>(
    context:parentDialog,builder:(ctx)=>StatefulBuilder(
     builder:(ctx,update)=>AlertDialog(
      backgroundColor:EventColors.surface,
      title:Text(alreadyRetired?'Gestionar devolución':'Retirar reserva',
       style:const TextStyle(color:EventColors.text,fontWeight:FontWeight.w900)),
      content:ConstrainedBox(
       constraints:const BoxConstraints(maxWidth:500),
       child:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
        children:[
         const Text('La reserva dejará de figurar como activa, pero conservará su historial, QR, pago y trazabilidad.',
          style:TextStyle(color:EventColors.text)),
         const SizedBox(height:12),
         TextField(controller:reason,maxLength:500,maxLines:3,
          style:const TextStyle(color:EventColors.text),
          decoration:const InputDecoration(
           labelText:'Motivo del retiro *',
           hintText:'Cancelación solicitada por el cliente, devolución, etc.')),
         if(needsRefund)...[
          const SizedBox(height:8),
          const Text('Esta reserva tiene un pago registrado. Retirarla no genera automáticamente una devolución en Mercado Pago.',
           style:TextStyle(color:EventColors.warning,fontWeight:FontWeight.w700)),
          CheckboxListTile.adaptive(
           contentPadding:EdgeInsets.zero,
           value:refundRegistered,
           onChanged:(v)=>update(()=>refundRegistered=v==true),
           title:const Text('Ya realicé la devolución del dinero',
            style:TextStyle(color:EventColors.text)),
           subtitle:const Text('Marca únicamente si comprobaste la devolución real.'),
          ),
          if(refundRegistered)TextField(
           controller:reference,maxLength:220,
           style:const TextStyle(color:EventColors.text),
           decoration:const InputDecoration(
            labelText:'Referencia o soporte de devolución *')),
         ],
         if(needsRefund&&!refundRegistered)
          const Text('Quedará en REEMBOLSO PENDIENTE hasta registrar el soporte.',
           style:TextStyle(color:EventColors.muted,fontSize:12)),
        ],
       ))),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(ctx),
        child:const Text('Volver')),
       FilledButton.icon(
        onPressed:(){
         if(reason.text.trim().length<5||
           (refundRegistered&&reference.text.trim().length<4)){
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
           content:Text('Escribe el motivo y, si hubo devolución, su referencia.')));
          return;
         }
         Navigator.pop(ctx,<String,dynamic>{
          'motivo':reason.text.trim(),
          'devolucionRealizada':refundRegistered,
          'referenciaDevolucion':refundRegistered?reference.text.trim():null,
         });
        },
        icon:const Icon(Icons.archive_outlined),
        label:Text(refundRegistered?'Registrar devolución y retirar':
          needsRefund?'Retirar y marcar devolución pendiente':'Retirar reserva'),
       ),
      ],
     )));
  }finally{reason.dispose();reference.dispose();}
  if(result==null||!mounted||
     branchId!=ref.read(branchScopeProvider).activeBranchId)return;
  try{
   final updated=await ref.read(eventosApiProvider).retirarReserva(id,result);
   if(!mounted||branchId!=ref.read(branchScopeProvider).activeBranchId)return;
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
     updated['requiereDevolucion']==true
       ?'Reserva retirada. La devolución está pendiente de realizarse o verificarse.'
       :'Reserva retirada y registrada en el historial.')));
   if(parentDialog.mounted){
    Navigator.of(parentDialog).pop();
    detail(eventId);
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(niceEventError(e))));
  }
 }
 Future<void> detail(int id)async{
  final branchId=ref.read(branchScopeProvider).activeBranchId;
  if(branchId==null)return;
  try{
   final data=await ref.read(eventosApiProvider).detalle(id);
   if(!mounted||branchId!=ref.read(branchScopeProvider).activeBranchId
      ||asId(data['sucu_id'])!=branchId)return;
   _sucursalDialogOpen=true;
   await showDialog<void>(context:context,builder:(dialog)=>Dialog(
    backgroundColor:EventColors.background,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
    child:ConstrainedBox(
     constraints:BoxConstraints(
      maxWidth:890,maxHeight:MediaQuery.sizeOf(dialog).height*.89),
     child:Padding(padding:const EdgeInsets.all(19),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Row(children:[
        const Icon(Icons.groups_outlined,color:EventColors.primary,size:30),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text(data['even_titulo']?.toString()??'Evento',
          style:const TextStyle(color:EventColors.text,
           fontSize:20,fontWeight:FontWeight.w900)),
         const SizedBox(height:4),
         const Text('Reservas del evento · Web, mostrador y teléfono',
          style:TextStyle(color:EventColors.muted,fontSize:12)),
        ])),
        IconButton(onPressed:()=>Navigator.pop(dialog),
         icon:const Icon(Icons.close,color:EventColors.text)),
       ]),
       const SizedBox(height:14),
       EventPanel(background:EventColors.surfaceLight,
        child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,
         spacing:9,runSpacing:8,children:[
          const Icon(Icons.info_outline,color:EventColors.primary,size:20),
          const Text('Puedes registrar mesas apartadas directamente en el bar o por llamada, sin cobro.',
           style:TextStyle(color:EventColors.text,fontSize:12)),
         ])),
       const SizedBox(height:13),
       Align(alignment:Alignment.centerRight,child:FilledButton.icon(
        onPressed:()async{
         final added=await showDialog<bool>(context:dialog,
          builder:(_)=>_ReservaInternaDialog(
           eventId:id,eventTitle:data['even_titulo']?.toString()??'Evento'));
         if(added==true&&dialog.mounted){
          Navigator.of(dialog).pop();
          if(mounted){
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Reserva interna registrada sin cobro. La mesa quedó apartada.')));
           detail(id);
          }
         }
        },
        style:FilledButton.styleFrom(backgroundColor:EventColors.primary,
         foregroundColor:EventColors.onPrimary),
        icon:const Icon(Icons.add_circle_outline),
        label:const Text('Agregar reserva del bar o llamada'))),
       const SizedBox(height:12),
       Expanded(child:ListView(children:[
        if((data['reservas'] as List? ??[]).isEmpty)
         const Padding(padding:EdgeInsets.all(30),
          child:Center(child:Text('Todavía no se han registrado reservas.',
           style:TextStyle(color:EventColors.muted)))),
        for(final item in (data['reservas'] as List? ??[]))
         Builder(builder:(context){
          final r=Map<String,dynamic>.from(item as Map);
          final state=r['eres_estado']?.toString()??'';
          final origin=r['eres_origen']?.toString()??'WEB';
          final internal=origin=='BAR'||origin=='LLAMADA';
          final originLabel=origin=='BAR'?'Mostrador':
            origin=='LLAMADA'?'Llamada':'Reserva web';
          final paid=(double.tryParse(r['eres_importe']?.toString()??'')??0);
          final money=NumberFormat.currency(
           locale:'es_CO',symbol:'COP ',decimalDigits:0).format(paid);
          return Padding(padding:const EdgeInsets.only(bottom:9),
           child:EventPanel(background:EventColors.surface,
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
             Wrap(spacing:9,runSpacing:8,
              crossAxisAlignment:WrapCrossAlignment.center,children:[
               EventPill(icon:internal?Icons.storefront:Icons.public,
                label:originLabel,
                color:internal?EventColors.gold:EventColors.primary),
               EventPill(icon:Icons.event_seat_outlined,
                label:r['mesas_reserva']?.toString()??'Mesa '+(r['mesa_numero']??r['mesa_id']).toString()),
               EventPill(icon:Icons.groups_outlined,
                label:(r['eres_puestos']??1).toString()+' puestos'),
               EventPill(icon:Icons.check_circle_outline,label:state,
                color:state=='CONFIRMADA'?EventColors.success:EventColors.warning),
              ]),
             const SizedBox(height:10),
             Text(r['eres_nombre']?.toString()??'Asistente',
              style:const TextStyle(color:EventColors.text,
               fontSize:15,fontWeight:FontWeight.w800)),
             const SizedBox(height:5),
             Text(
              [
               if((r['eres_telefono']?.toString()??'').isNotEmpty)
                'Tel.: '+r['eres_telefono'].toString(),
               if((r['eres_email']?.toString()??'').isNotEmpty)
                r['eres_email'].toString(),
               internal?'Sin cobro':money,
              ].join(' · '),
              style:const TextStyle(color:EventColors.muted,fontSize:12)),
             if((r['eres_nota']?.toString()??'').isNotEmpty)...[
              const SizedBox(height:8),
              Text(r['eres_nota'].toString(),
               style:const TextStyle(color:EventColors.muted,fontSize:12)),
             ],
             if(state=='PENDIENTE_REVISION'||(internal&&['CONFIRMADA','CANCELADA'].contains(state)))...[
              const SizedBox(height:10),
              Wrap(spacing:10,children:[
               if(state=='PENDIENTE_REVISION')FilledButton.icon(
                onPressed:()async{
                 try{
                  await ref.read(eventosApiProvider).aprobar(asId(r['eres_id'])!);
                  if(dialog.mounted){Navigator.pop(dialog);detail(id);}
                 }catch(e){
                  if(mounted)ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content:Text(niceEventError(e))));
                 }
                },icon:const Icon(Icons.check,size:17),
                label:const Text('Aprobar')),
               if(internal&&['CONFIRMADA','CANCELADA'].contains(state))
                OutlinedButton.icon(
                 onPressed:()async{
                  final edited=await showDialog<bool>(
                   context:dialog,builder:(_)=>_ReservaInternaDialog(
                    eventId:id,
                    eventTitle:data['even_titulo']?.toString()??'Evento',
                    initial:r));
                  if(edited==true&&dialog.mounted){
                   Navigator.pop(dialog);
                   if(mounted)detail(id);
                  }
                 },
                 icon:const Icon(Icons.edit_note_outlined,size:17),
                 label:Text(state=='CANCELADA'?'Modificar / reactivar':'Modificar'),
                ),
               if(internal&&state=='CONFIRMADA')OutlinedButton.icon(
                onPressed:()async{
                 final confirm=await showDialog<bool>(
                  context:dialog,builder:(alert)=>AlertDialog(
                   title:const Text('Liberar mesa'),
                   content:const Text('Se cancelará esta reserva interna y la mesa volverá a estar disponible para este evento.'),
                   actions:[
                    TextButton(onPressed:()=>Navigator.pop(alert,false),
                     child:const Text('Volver')),
                    FilledButton(onPressed:()=>Navigator.pop(alert,true),
                     child:const Text('Liberar mesa')),
                   ]));
                 if(confirm!=true)return;
                 try{
                  await ref.read(eventosApiProvider).cancelarReserva(asId(r['eres_id'])!);
                  if(dialog.mounted){Navigator.pop(dialog);detail(id);}
                 }catch(e){
                  if(mounted)ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content:Text(niceEventError(e))));
                 }
                },
                icon:const Icon(Icons.event_busy_outlined,size:17),
                label:const Text('Liberar mesa')),
              ]),
             ],
            ])));
         }),
       ])),
      ])),
    ),
   ));
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(niceEventError(e))));
  }finally{_sucursalDialogOpen=false;}
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
     if(status!='CANCELADO')OutlinedButton.icon(
      onPressed:id==null?null:()async{
       final added=await showDialog<bool>(context:context,
        builder:(_)=>_ReservaInternaDialog(
         eventId:id,eventTitle:item['even_titulo']?.toString()??'Evento'));
       if(added==true&&mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content:Text('Mesa apartada sin cobro en el evento')));
        detail(id);
       }
      },
      icon:const Icon(Icons.add_call,size:18),
      label:const Text('Reserva interna'),
      style:OutlinedButton.styleFrom(
       foregroundColor:EventColors.gold,
       side:const BorderSide(color:EventColors.border))),
     // Permitir editar los eventos independientemente del estado.
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
     if(draft)FilledButton.icon(onPressed:id==null?null:()=>publish(id),
      icon:const Icon(Icons.public,size:18),label:const Text('Publicar'),
      style:FilledButton.styleFrom(backgroundColor:sea,
       foregroundColor:const Color(0xff072532))),
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
  final branchId=ref.watch(branchScopeProvider).activeBranchId;
  ref.listen<BranchScopeState>(branchScopeProvider,(old,next){
    if(old?.activeBranchId==next.activeBranchId)return;
    // Cerrar el detalle anterior al cambiar de sucursal.
    if(_sucursalDialogOpen){
      _sucursalDialogOpen=false;
      Navigator.of(context,rootNavigator:true).maybePop();
    }
    ++_loadSeq;
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted)return;
      setState((){entries=[];loading=true;error=null;});
      load();
    });
  });
  final visibleEntries=entries.where((e)=>asId(e['sucu_id'])==branchId).toList();
  final published=visibleEntries.where((e)=>e['even_estado']=='PUBLICADO').length;
  final draft=visibleEntries.where((e)=>e['even_estado']=='BORRADOR').length;
  final query=search.trim().toLowerCase();
  final items=visibleEntries.where((e)=>
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
          'Eventos creados',visibleEntries.length,sea)),
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
        Text(visibleEntries.length.toString()+' registrados',
         style:const TextStyle(color:eventSecondary,fontSize:13)),
       ]),
       const SizedBox(height:14),
       if(visibleEntries.isNotEmpty)...[
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
       if(visibleEntries.isEmpty)_empty(false)
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



class _EventPaymentGuide extends ConsumerStatefulWidget{
 const _EventPaymentGuide({required this.initial});
 final Map<String,dynamic> initial;
 @override ConsumerState<_EventPaymentGuide> createState()=>_EventPaymentGuideState();
}
class _EventPaymentGuideState extends ConsumerState<_EventPaymentGuide>{
 final token=TextEditingController(),secret=TextEditingController();
 bool tokenVisible=false,secretVisible=false,saving=false;
 bool replaceToken=false,replaceSecret=false;
 bool showCreateGuide=false;
 String? error;
 bool get configured=>widget.initial['configurada']==true;
 bool get cipherStatusKnown=>widget.initial.containsKey('cifradoDisponible');
 bool get cipherReady=>widget.initial['cifradoDisponible']==true;
 bool showTechnicalHelp=false;
 String get webhook=>widget.initial['webhook']?.toString()??'';
 String get lastUpdated=>widget.initial['ultimaActualizacion']?.toString()??'';
 @override void initState(){
  super.initState();
  showCreateGuide=!configured;
 }
 @override void dispose(){token.dispose();secret.dispose();super.dispose();}
 Future<void> _open(String url)async{
  final uri=Uri.tryParse(url);
  if(uri==null)return;
  final ok=await launchUrl(uri,mode:LaunchMode.externalApplication);
  if(!ok&&mounted)ScaffoldMessenger.of(context).showSnackBar(
   const SnackBar(content:Text('No se pudo abrir Mercado Pago. Copia el enlace e inténtalo desde el navegador.')));
 }
 Future<void> _save()async{
  if(saving)return;
  if(cipherStatusKnown&&!cipherReady){
   setState(()=>error='El cifrado de pagos todavía no está configurado en el servidor BarLytics. Contacta al administrador de la plataforma.');
   return;
  }
  final access=(!configured||replaceToken)?token.text.trim():'';
  final signature=(!configured||replaceSecret)?secret.text.trim():'';
  if(configured&&!replaceToken&&!replaceSecret){
   setState(()=>error='Las credenciales anteriores ya están guardadas. Selecciona Reemplazar si necesitas cambiar alguna.');
   return;
  }
  if((!configured&&(access.isEmpty||signature.isEmpty)) ||
     (configured&&((replaceToken&&access.isEmpty)||(replaceSecret&&signature.isEmpty)))){
   setState(()=>error=configured
    ?'Introduce el nuevo valor de cada credencial que deseas reemplazar.'
    :'Para la primera configuración ingresa el Access Token y la firma del Webhook.');
   return;
  }
  if(access.startsWith('TEST-')||access.startsWith('TEST_')){
   setState(()=>error='Selecciona Producción en Mercado Pago. Este formulario configura cobros reales.');
   return;
  }
  setState((){saving=true;error=null;});
  try{
   await ref.read(eventosApiProvider).configurar(access,signature);
   if(!mounted)return;
   token.clear();secret.clear();
   final messenger=ScaffoldMessenger.maybeOf(context);
   Navigator.of(context).pop();
   messenger?.showSnackBar(const SnackBar(
    content:Text('Credenciales guardadas de forma cifrada. Realiza una reserva de prueba controlada para verificar las notificaciones.')));
  }catch(e){
   if(mounted)setState(()=>error=niceEventError(e));
  }finally{
   if(mounted)setState(()=>saving=false);
  }
 }
 Widget _step(int n,String title,String description,{Widget? child})=>Padding(
  padding:const EdgeInsets.only(bottom:15),
  child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Container(height:33,width:33,alignment:Alignment.center,
    decoration:BoxDecoration(color:EventColors.primary.withOpacity(.16),
     borderRadius:BorderRadius.circular(10)),
    child:Text(n.toString(),style:const TextStyle(
     color:EventColors.primary,fontWeight:FontWeight.w900))),
   const SizedBox(width:12),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(
     color:EventColors.text,fontSize:14,fontWeight:FontWeight.w800)),
    const SizedBox(height:6),
    Text(description,style:const TextStyle(
     color:EventColors.muted,fontSize:12,height:1.5)),
    if(child!=null)...[const SizedBox(height:10),child],
   ])),
  ]),
 );



 Widget _savedCredentials(){
  if(!configured)return EventPanel(
   borderColor:EventColors.border,
   background:EventColors.surfaceLight,
   child:const Row(children:[
    Icon(Icons.account_balance_wallet_outlined,color:EventColors.primary),
    SizedBox(width:12),
    Expanded(child:Text(
     'Este establecimiento aún no tiene credenciales registradas. '
     'Introduce las dos claves para conectarlo con Mercado Pago.',
     style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5))),
   ]),
  );
  return EventPanel(
   borderColor:EventColors.success.withOpacity(.55),
   background:const Color(0xFF103B3B),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Row(children:[
     Icon(Icons.verified_user_outlined,color:EventColors.success,size:27),
     SizedBox(width:11),
     Expanded(child:Text('Credenciales de Mercado Pago guardadas',
      style:TextStyle(color:EventColors.text,
       fontSize:15,fontWeight:FontWeight.w900))),
    ]),
    const SizedBox(height:13),
    const Row(children:[
     Icon(Icons.lock_outline,color:EventColors.primary,size:19),
     SizedBox(width:10),
     Expanded(child:Text('Access Token de producción',
      style:TextStyle(color:EventColors.text,fontSize:12))),
     Text('••••••••  Guardado',style:TextStyle(
      color:EventColors.success,fontWeight:FontWeight.w700,fontSize:12)),
    ]),
    const SizedBox(height:11),
    const Row(children:[
     Icon(Icons.shield_outlined,color:EventColors.primary,size:19),
     SizedBox(width:10),
     Expanded(child:Text('Firma secreta del Webhook',
      style:TextStyle(color:EventColors.text,fontSize:12))),
     Text('••••••••  Guardada',style:TextStyle(
      color:EventColors.success,fontWeight:FontWeight.w700,fontSize:12)),
    ]),
    if(lastUpdated.isNotEmpty)...[
     const SizedBox(height:12),
     Text('Última actualización: $lastUpdated',
      style:const TextStyle(color:EventColors.muted,fontSize:11)),
    ],
    const SizedBox(height:11),
    const Text('Los valores completos nunca se muestran de nuevo por seguridad. '
      'No necesitas reingresarlos para seguir cobrando. '
      'Puedes reemplazar solo el dato que cambió.',
      style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5)),
   ]),
  );
 }

 Widget _credentialField({
  required TextEditingController controller,
  required bool selected,
  required IconData icon,
  required String label,
  required bool visible,
  required VoidCallback toggleVisible,
  required VoidCallback toggleReplacement,
  required String description,
 }){
  final editable=!configured||selected;
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   if(configured)...[
    Row(children:[
     const Icon(Icons.check_circle_outline,
      color:EventColors.success,size:17),
     const SizedBox(width:7),
     Expanded(child:Text(
      selected?'Introduce el nuevo valor':'Valor actual protegido y guardado',
      style:const TextStyle(color:EventColors.muted,fontSize:12))),
     OutlinedButton.icon(
      onPressed:saving?null:toggleReplacement,
      icon:Icon(selected?Icons.close:Icons.edit_outlined,size:16),
      label:Text(selected?'Conservar el anterior':'Reemplazar'),
     ),
    ]),
    const SizedBox(height:8),
   ],
   TextField(
    controller:controller,
    enabled:editable&&!saving,
    obscureText:!visible,
    enableSuggestions:false,
    autocorrect:false,
    onChanged:(_)=>setState((){}),
    decoration:InputDecoration(
     labelText:label,
     hintText:configured?'•••••••• (guardado; no es necesario escribir)':
      'Pega aquí el valor de producción',
     prefixIcon:Icon(icon),
     helperText:description,
     helperMaxLines:3,
     suffixIcon:editable?IconButton(
      tooltip:visible?'Ocultar nuevo valor':'Mostrar nuevo valor',
      onPressed:toggleVisible,
      icon:Icon(visible?Icons.visibility_off:Icons.visibility)):null,
    ),
   ),
  ]);
 }
 Widget _cipherStatus(){
   if(!cipherStatusKnown){
     return EventPanel(
       borderColor:EventColors.warning,
       background:const Color(0xFF3C302B),
       child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Icon(Icons.info_outline,color:EventColors.warning),
         SizedBox(width:11),
         Expanded(child:Text(
           'No se pudo verificar si el servidor tiene el cifrado habilitado. '
           'Asegúrate de actualizar el backend antes de configurar cobros.',
           style:TextStyle(color:EventColors.text,fontSize:12,height:1.5))),
       ]),
     );
   }
   if(cipherReady){
     return EventPanel(
       borderColor:EventColors.success.withOpacity(.5),
       background:const Color(0xFF153C39),
       child:const Row(children:[
         Icon(Icons.verified_user_outlined,color:EventColors.success,size:25),
         SizedBox(width:12),
         Expanded(child:Column(
           crossAxisAlignment:CrossAxisAlignment.start,children:[
             Text('Cifrado habilitado en BarLytics',
               style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
             SizedBox(height:4),
             Text('Puedes guardar las credenciales del negocio.',
               style:TextStyle(color:EventColors.muted,fontSize:12)),
           ])),
       ]),
     );
   }
   return EventPanel(
     background:const Color(0xFF4B2D34),
     borderColor:EventColors.warning,
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Icon(Icons.gpp_bad_outlined,color:EventColors.warning,size:26),
         SizedBox(width:12),
         Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text('BarLytics necesita activar el cifrado del servidor',
             style:TextStyle(color:EventColors.text,
               fontWeight:FontWeight.w900,fontSize:14)),
           SizedBox(height:5),
           Text('No es un error de tus credenciales de Mercado Pago. '
             'El administrador de BarLytics debe terminar la configuración '
             'de seguridad antes de que puedas guardarlas.',
             style:TextStyle(color:EventColors.text,fontSize:12,height:1.5)),
         ])),
       ]),
       const SizedBox(height:12),
       TextButton.icon(
         onPressed:()=>setState(()=>showTechnicalHelp=!showTechnicalHelp),
         icon:Icon(showTechnicalHelp?Icons.expand_less:Icons.expand_more,
           color:EventColors.primary),
         label:const Text('Instrucciones para el administrador técnico',
           style:TextStyle(color:EventColors.primary)),
       ),
       if(showTechnicalHelp) ...[
         const SizedBox(height:8),
         const SelectableText(
           'Variable: BARLYTICS_EVENT_AES_KEY_BASE64',
           style:TextStyle(color:EventColors.text,fontFamily:'monospace',
             fontSize:12)),
         const SizedBox(height:7),
         const Text(
           'Generar una única clave AES aleatoria de 32 bytes '
           'con «openssl rand -base64 32». '
           'Guardarla como variable de entorno del servicio backend '
           'en el gestor de secretos o en su configuración privada '
           'de despliegue, y reiniciar el backend. '
           'Si ya había una clave, conservarla: cambiarla impediría '
           'descifrar los pagos anteriormente configurados. '
           'Nunca incluir la clave en el código, el navegador o capturas.',
           style:TextStyle(color:EventColors.text,height:1.5,fontSize:12)),
       ],
     ]),
   );
 }
 /// Guía integrada para quienes aún no tienen una app en Mercado Pago.
 /// No recibe claves ni crea cuentas automáticamente: enlaza al panel oficial.
 Widget _createApplicationGuide() {
  return EventPanel(
   background:EventColors.surface,
   borderColor:EventColors.primary.withOpacity(.45),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
     Container(
      height:42,width:42,
      decoration:BoxDecoration(
       gradient:const LinearGradient(colors:[
        Color(0xFF20D8CE),Color(0xFF0C9BAD)]),
       borderRadius:BorderRadius.circular(12)),
      child:const Icon(Icons.add_to_home_screen_outlined,
       color:EventColors.onPrimary,size:23)),
     const SizedBox(width:11),
     const Expanded(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text('¿No tienes una aplicación de Mercado Pago?',
        style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,
         color:EventColors.text)),
       SizedBox(height:4),
       Text('Crea una para tu establecimiento antes de copiar las credenciales.',
        style:TextStyle(color:EventColors.muted,fontSize:12)),
      ])),
     IconButton(
      tooltip:showCreateGuide?'Ocultar guía':'Mostrar guía',
      onPressed:()=>setState(()=>showCreateGuide=!showCreateGuide),
      icon:Icon(showCreateGuide?Icons.keyboard_arrow_up:
       Icons.keyboard_arrow_down,color:EventColors.primary)),
    ]),
    if(showCreateGuide)...[
     const SizedBox(height:18),
     _step(1,'Inicia sesión en la cuenta que recibirá los pagos',
      'Entra a Mercado Pago Developers con la cuenta del negocio. '
      'Abre Tus integraciones y pulsa Crear aplicación. '
      'Si te pregunta cómo crearla, elige Crear manualmente.'),
     _step(2,'Nombra la aplicación',
      'Escribe un nombre reconocible, por ejemplo: '
      '«Mi gastrobar - Reservas BarLytics». '
      'Es un nombre para identificar la integración dentro de Mercado Pago.'),
     _step(3,'Selecciona la solución correcta',
      'Selecciona Pagos online y luego Checkout Pro. '
      'BarLytics genera una preferencia de pago y el cliente paga '
      'en el sitio seguro de Mercado Pago.',
      child:const Wrap(spacing:8,runSpacing:8,children:[
       EventPill(icon:Icons.language_outlined,label:'Pagos online'),
       EventPill(icon:Icons.shopping_bag_outlined,label:'Checkout Pro'),
      ])),
     _step(4,'Indica para quién es la aplicación',
      'Esta integración recibe cobros del propio establecimiento. '
      'Si Mercado Pago pregunta por el modelo de integración, '
      'selecciona tu propio negocio o vendedor directo, no Marketplace. '
      'Si pregunta por una plataforma de comercio electrónico, '
      'indica que es una integración propia, no una tienda de otra plataforma.'),
     _step(5,'Confirma la creación',
      'Completa los datos adicionales que solicite Mercado Pago '
      '(como categoría o sitio web, si aplica), acepta sus condiciones '
      'y pulsa Crear aplicación. Al terminar, abre las '
      'credenciales de Producción en la aplicación nueva.'),
     const SizedBox(height:2),
     LayoutBuilder(builder:(context,box){
      return Wrap(spacing:9,runSpacing:9,children:[
       FilledButton.icon(
        onPressed:()=>_open('https://www.mercadopago.com.co/developers/panel/app'),
        style:FilledButton.styleFrom(
         backgroundColor:EventColors.primary,
         foregroundColor:EventColors.onPrimary),
        icon:const Icon(Icons.open_in_new,size:18),
        label:const Text('Crear aplicación en Mercado Pago')),
       OutlinedButton.icon(
        onPressed:()=>_open(
         'https://www.mercadopago.com.co/developers/es/docs/checkout-pro-preferences/create-application'),
        icon:const Icon(Icons.menu_book_outlined,size:18),
        label:const Text('Ver guía oficial')),
      ]);
     }),
     const SizedBox(height:12),
     const Text(
      'Mercado Pago puede variar los nombres de las opciones. '
      'La creación se hace siempre en el sitio oficial; '
      'BarLytics nunca solicita tu contraseña de Mercado Pago.',
      style:TextStyle(fontSize:11,color:EventColors.muted,height:1.5)),
    ],
   ]),
  );
 }
 @override Widget build(BuildContext context){
  return Dialog(
   backgroundColor:EventColors.background,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(21)),
   insetPadding:const EdgeInsets.all(12),
   child:ConstrainedBox(
    constraints:BoxConstraints(maxWidth:820,
     maxHeight:MediaQuery.sizeOf(context).height*.93),
    child:Column(children:[
     Container(width:double.infinity,padding:const EdgeInsets.all(21),
      decoration:const BoxDecoration(gradient:LinearGradient(colors:[
       Color(0xFF104D5D),Color(0xFF0B3040)]),
       borderRadius:BorderRadius.vertical(top:Radius.circular(21))),
      child:Row(children:[
       const Icon(Icons.account_balance_wallet_outlined,
        size:35,color:EventColors.primary),
       const SizedBox(width:12),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Configurar cobros de eventos',
         style:TextStyle(color:EventColors.text,
          fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        Text(configured
         ?'Cuenta conectada. Tus claves siguen guardadas; cámbialas solo si es necesario.'
         :'Conecta tu propia cuenta para recibir pagos directamente en tu establecimiento.',
         style:const TextStyle(color:EventColors.muted,fontSize:12)),
       ])),
       IconButton(onPressed:saving?null:()=>Navigator.pop(context),
        icon:const Icon(Icons.close,color:EventColors.text)),
      ])),
     Expanded(child:SingleChildScrollView(
      padding:const EdgeInsets.all(20),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventPanel(background:EventColors.surfaceLight,child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
         const EventSectionHeading(icon:Icons.info_outline,
          title:'¿Qué método se utiliza?',
          subtitle:'Cobros electrónicos de eventos con Mercado Pago Checkout Pro.'),
         const SizedBox(height:11),
         const Text('Necesitas dos datos de tu propia aplicación de Mercado Pago: Access Token de PRODUCCIÓN y clave secreta del Webhook de PRODUCCIÓN. No necesitas Public Key, Client ID, Client Secret ni credenciales de BarLytics.',
          style:TextStyle(color:EventColors.text,height:1.55,fontSize:12)),
         const SizedBox(height:10),
         EventPill(icon:configured?Icons.verified_outlined:Icons.pending_actions_outlined,
          label:configured?'Guardada en BarLytics (sin comprobar pagos)':'Configuración pendiente',
          color:configured?EventColors.success:EventColors.warning),
        ])),
       const SizedBox(height:14),
       _cipherStatus(),
       const SizedBox(height:14),
       _savedCredentials(),
       const SizedBox(height:19),
       _createApplicationGuide(),
       const SizedBox(height:19),
       const EventSectionHeading(icon:Icons.key_outlined,
        title:'Conecta tu aplicación a BarLytics',
        subtitle:'Si ya tienes una aplicación Checkout Pro, continúa con estos pasos.'),
       const SizedBox(height:16),
       _step(1,'Abre Mercado Pago Developers',
        'Entra con la cuenta de Mercado Pago que recibirá el dinero del negocio. Ve a Tus integraciones y abre la aplicación Checkout Pro creada para tu establecimiento.',
        child:OutlinedButton.icon(
         onPressed:()=>_open('https://www.mercadopago.com.co/developers/panel/app'),
         icon:const Icon(Icons.open_in_new,size:17),
         label:const Text('Abrir Mis integraciones'))),
       _step(2,'Copia el Access Token de producción',
        'Dentro de la aplicación abre Credenciales → Producción y activa el entorno productivo si aún no lo hiciste. Copia Access Token, NO Public Key ni credenciales de prueba.',
        child:_credentialField(
         controller:token,selected:replaceToken,
         icon:Icons.key_outlined,
         label:'Access Token de PRODUCCIÓN',
         visible:tokenVisible,
         toggleVisible:()=>setState(()=>tokenVisible=!tokenVisible),
         toggleReplacement:()=>setState((){
          replaceToken=!replaceToken;token.clear();tokenVisible=false;
         }),
         description:configured?'Si no lo reemplazas, sigue activo el token guardado.':
          'Credencial privada de producción de tu negocio.')),
       _step(3,'Configura las notificaciones Webhook',
        'En la misma aplicación abre Webhooks. En Modo productivo pega esta URL HTTPS y activa las notificaciones de Pagos (payment). Guarda la configuración.',
        child:EventPanel(background:EventColors.surfaceLight,
         child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SelectableText(webhook,style:const TextStyle(
           color:EventColors.primary,fontSize:12)),
          const SizedBox(height:8),
          OutlinedButton.icon(
           onPressed:webhook.isEmpty?null:()async{
            await Clipboard.setData(ClipboardData(text:webhook));
            if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content:Text('URL del webhook copiada')));
           },
           icon:const Icon(Icons.copy,size:17),label:const Text('Copiar URL')),
         ]))),
       _step(4,'Copia la clave secreta del Webhook',
        'En la configuración de Webhooks de Mercado Pago copia la firma secreta generada para el modo productivo. No es el Client Secret ni el Access Token.',
        child:_credentialField(
         controller:secret,selected:replaceSecret,
         icon:Icons.password_outlined,
         label:'Clave secreta de firma Webhook',
         visible:secretVisible,
         toggleVisible:()=>setState(()=>secretVisible=!secretVisible),
         toggleReplacement:()=>setState((){
          replaceSecret=!replaceSecret;secret.clear();secretVisible=false;
         }),
         description:configured?'Mantén el valor anterior salvo que hayas cambiado el Webhook.':
          'Firma privada de las notificaciones productivas.')),
       _step(5,configured?'Actualizar solo lo necesario':'Guarda y verifica una transacción',
        configured
         ?'Tus credenciales anteriores siguen activas. Si cambiaste una de ellas, usa Reemplazar en ese campo y guarda. Después verifica un pago aprobado. Guardar no comprueba automáticamente las credenciales.'
         :'Guarda ambas credenciales. Después comprueba desde la página pública de un evento que un pago aprobado llegue a la cuenta del negocio y la reserva quede confirmada. Guardar no valida automáticamente las credenciales.'),
       if(error!=null)EventPanel(background:const Color(0xFF4A2730),
        borderColor:EventColors.warning,
        child:Row(children:[
         const Icon(Icons.error_outline,color:EventColors.warning),
         const SizedBox(width:10),
         Expanded(child:Text(error!,style:const TextStyle(
          color:EventColors.text,fontSize:12))),
        ])),
       const SizedBox(height:8),
       const Text('Seguridad: los datos se envían al backend para almacenarse cifrados. Nunca publiques estas claves ni las envíes por chat.',
        style:TextStyle(color:EventColors.muted,fontSize:11,height:1.6)),
      ]),
     )),
     Container(width:double.infinity,
      padding:const EdgeInsets.all(16),
      decoration:const BoxDecoration(color:Color(0xFF082532),
       border:Border(top:BorderSide(color:EventColors.border))),
      child:LayoutBuilder(builder:(context,box){
       final cancel=OutlinedButton(
        onPressed:saving?null:()=>Navigator.pop(context),
        child:const Text('Cerrar'));
       final save=FilledButton.icon(
        onPressed:saving||(cipherStatusKnown&&!cipherReady)||
         (configured&&!replaceToken&&!replaceSecret)?null:_save,
        style:FilledButton.styleFrom(backgroundColor:EventColors.primary,
         foregroundColor:EventColors.onPrimary),
        icon:const Icon(Icons.lock_outline),
        label:Text(saving?'Guardando...':configured?'Actualizar credenciales':'Guardar credenciales'));
       if(box.maxWidth<480)return Column(
        mainAxisSize:MainAxisSize.min,children:[
         SizedBox(width:double.infinity,child:save),
         const SizedBox(height:9),
         SizedBox(width:double.infinity,child:cancel),
        ]);
       return Row(children:[
        cancel,const Spacer(),save,
       ]);
      }),
     ),
    ]),
   ),
  );
 }
}

/// Registro sin giro o pasarela: aparta la mesa del evento desde el establecimiento.
class _ReservaInternaDialog extends ConsumerStatefulWidget{
 const _ReservaInternaDialog({required this.eventId,required this.eventTitle,this.initial});
 final int eventId;
 final String eventTitle;
 final Map<String,dynamic>? initial;
 @override ConsumerState<_ReservaInternaDialog> createState()=>_ReservaInternaState();
}
class _ReservaInternaState extends ConsumerState<_ReservaInternaDialog>{
 final form=GlobalKey<FormState>();
 final name=TextEditingController(),phone=TextEditingController(),
  notes=TextEditingController();
 List<Map<String,dynamic>> tables=[];
 bool loading=true,saving=false;
 String? error;
 int? selectedTable;
 int seats=1;
 final chosenChairs=<int>{};
 final originalChairs=<int>{};
 String source='BAR';
 bool reactivate=false;
 bool get editing=>widget.initial!=null;
 bool get cancelled=>widget.initial?['eres_estado']=='CANCELADA';
 int? get bookingId=>asId(widget.initial?['eres_id']);
 @override void initState(){
  super.initState();
  final i=widget.initial;
  if(i!=null){
   name.text=i['eres_nombre']?.toString()??'';
   phone.text=i['eres_telefono']?.toString()??'';
   notes.text=i['eres_nota']?.toString()??'';
   selectedTable=asId(i['mesa_id']);
   seats=asId(i['eres_puestos'])??1;
   source=i['eres_origen']?.toString()??'BAR';
   final original=i['eres_sillas']?.toString()??'';
   originalChairs.addAll(RegExp(r'[0-9]+').allMatches(original)
     .map((m)=>int.tryParse(m.group(0)??'')??0).where((v)=>v>0));
   chosenChairs.addAll(originalChairs);
  }
  load();
 }
 @override void dispose(){
  name.dispose();phone.dispose();notes.dispose();super.dispose();
 }
 Future<void> load()async{
  if(mounted)setState((){loading=true;error=null;});
  try{
   final values=await ref.read(eventosApiProvider).mesasEvento(widget.eventId);
   if(!mounted)return;
   setState((){
    tables=values;loading=false;
    if(selectedTable!=null&&!tables.any((t)=>
      asId(t['id'])==selectedTable&&
      (t['estado']=='DISPONIBLE'||(editing&&asId(t['id'])==asId(widget.initial?['mesa_id']))))){
     selectedTable=null;seats=1;
    }
   });
  }catch(e){
   if(mounted)setState((){loading=false;error=niceEventError(e);});
  }
 }
 Future<void> save()async{
  if(saving||!(form.currentState?.validate()??false))return;
  if(selectedTable==null){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Selecciona una mesa disponible para apartar')));
   return;
  }
  final selectedRow=tables.where((t)=>asId(t['id'])==selectedTable).toList();
  if(selectedRow.isNotEmpty&&selectedRow.first['seleccionarSillas']==true
    && !(editing&&cancelled&&!reactivate)&&chosenChairs.length!=seats){
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text('Selecciona exactamente '+seats.toString()+' sillas')));
   return;
  }
  setState(()=>saving=true);
  try{
   final body={
    'mesaId':selectedTable,'puestos':seats,
    'nombre':name.text.trim(),'telefono':phone.text.trim(),
    'origen':source,'nota':notes.text.trim(),
    'sillas':tables.any((t)=>asId(t['id'])==selectedTable&&
      t['seleccionarSillas']==true)
      ?(chosenChairs.toList()..sort()):<int>[],
   };
   if(editing){
    await ref.read(eventosApiProvider).editarReservaInterna(
      bookingId!,{...body,'reactivar':reactivate});
   }else{
    await ref.read(eventosApiProvider).reservarInterna(widget.eventId,body);
   }
   if(mounted)Navigator.of(context).pop(true);
  }catch(e){
   if(mounted){
    setState(()=>saving=false);
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content:Text(niceEventError(e))));
    // Recuperar la disponibilidad cuando otra persona reservó al mismo tiempo.
    await load();
   }
  }
 }
 @override Widget build(BuildContext context){
  final selectedRows=tables.where((t)=>asId(t['id'])==selectedTable).toList();
  final selectedInfo=selectedRows.isEmpty?null:selectedRows.first;
  final fullCapacity=asId(selectedInfo?['capacidad'])??6;
  final originalTable=editing&&selectedTable==asId(widget.initial?['mesa_id']);
  final self=originalTable&&!cancelled;
  final remaining=asId(selectedInfo?['disponibles'])??fullCapacity;
  // Editar una cancelada sin reactivarla no requiere una silla libre:
  // conserva el aforo registrado aunque la mesa ya haya sido reutilizada.
  final protectedSeats=originalTable&&cancelled&&!reactivate
    ?(asId(widget.initial?['eres_puestos'])??0):0;
  final capacity=(remaining+(self?(asId(widget.initial?['eres_puestos'])??0):0))
     .clamp(protectedSeats>0?protectedSeats:1,fullCapacity).toInt();
  final manual=selectedInfo?['seleccionarSillas']==true;
  final unavailable=(selectedInfo?['sillasOcupadas'] as List? ??[])
    .map(asId).whereType<int>().toSet()
    .difference(self?originalChairs:<int>{});
  return Dialog(
   backgroundColor:EventColors.background,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(23)),
   child:ConstrainedBox(
    constraints:BoxConstraints(maxWidth:760,maxHeight:MediaQuery.sizeOf(context).height*.92),
    child:Form(key:form,child:Column(children:[
     Container(width:double.infinity,
      padding:const EdgeInsets.all(19),
      decoration:const BoxDecoration(
       gradient:LinearGradient(colors:[
        Color(0xFF10475A),Color(0xFF0A2B3D)]),
       borderRadius:BorderRadius.vertical(top:Radius.circular(23))),
      child:Row(children:[
       const Icon(Icons.event_seat_outlined,color:EventColors.primary,size:29),
       const SizedBox(width:11),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(editing?'Modificar reserva sin cobro':'Registrar reserva sin cobro',
         style:TextStyle(color:EventColors.text,
          fontWeight:FontWeight.w900,fontSize:21)),
        const SizedBox(height:4),
        Text(widget.eventTitle,maxLines:1,overflow:TextOverflow.ellipsis,
         style:const TextStyle(color:EventColors.muted,fontSize:12)),
       ])),
       IconButton(onPressed:saving?null:()=>Navigator.pop(context),
        icon:const Icon(Icons.close,color:EventColors.text)),
      ])),
     Expanded(child:SingleChildScrollView(
      padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       const EventSectionHeading(icon:Icons.call_outlined,
        title:'Origen de la reserva',
        subtitle:'Se confirmará de inmediato sin solicitar pago.'),
       const SizedBox(height:12),
       SegmentedButton<String>(
        segments:const [
         ButtonSegment(value:'BAR',label:Text('En el bar'),
          icon:Icon(Icons.storefront_outlined)),
         ButtonSegment(value:'LLAMADA',label:Text('Por llamada'),
          icon:Icon(Icons.phone_outlined)),
        ],
        selected:{source},showSelectedIcon:true,
        onSelectionChanged:(values)=>setState(()=>source=values.first)),
       const SizedBox(height:18),
       const EventSectionHeading(icon:Icons.table_restaurant_outlined,
        title:'Selecciona la mesa',
        subtitle:'Las mesas completas están bloqueadas; las compartidas permiten reservar puestos libres.'),
       const SizedBox(height:13),
       if(loading)const Center(child:Padding(padding:EdgeInsets.all(25),
        child:CircularProgressIndicator()))
       else if(error!=null)EventPanel(child:Row(children:[
        Expanded(child:Text(error!,
         style:const TextStyle(color:EventColors.muted))),
        TextButton(onPressed:load,child:const Text('Reintentar')),
       ]))
       else if(tables.isEmpty)const Text('El evento no tiene mesas habilitadas.',
        style:TextStyle(color:EventColors.muted))
       else GridView.builder(
        shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
        itemCount:tables.length,
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent:165,mainAxisExtent:145,
         crossAxisSpacing:9,mainAxisSpacing:9),
        itemBuilder:(context,i){
         final table=tables[i];
         final id=asId(table['id']);
         final current=editing&&id==asId(widget.initial?['mesa_id']);
         final free=table['estado']=='DISPONIBLE'||current;
         final active=id==selectedTable;
         return InkWell(
          onTap:free&&id!=null?()=>setState((){
           selectedTable=id;seats=1;chosenChairs.clear();
          }):null,
          borderRadius:BorderRadius.circular(12),
          child:Container(
           clipBehavior:Clip.antiAlias,
           decoration:BoxDecoration(
            color:active?const Color(0xFF154B5B):EventColors.surface,
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:active?EventColors.primary:EventColors.border,
             width:active?2:1)),
           child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Expanded(child:Stack(children:[
             Positioned.fill(child:EventArtwork(source:table['foto'],
              height:92,borderRadius:0)),
             if(!free)Positioned.fill(child:Container(color:Colors.black54)),
             if(active)const Positioned(top:6,right:6,
              child:CircleAvatar(radius:12,backgroundColor:EventColors.primary,
               child:Icon(Icons.check,size:15,color:EventColors.onPrimary))),
            ])),
            Padding(padding:const EdgeInsets.all(8),child:Column(
             crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Mesa '+(table['numero']??id).toString(),
               style:const TextStyle(color:EventColors.text,
                fontWeight:FontWeight.w800,fontSize:12)),
              Text(free?(table['disponibles']??table['capacidad']??6).toString()+' puestos libres':
               'Sin disponibilidad',
               style:TextStyle(fontSize:11,
                color:free?EventColors.success:EventColors.warning)),
             ])),
           ]),
          ),
         );
        }),
       if(selectedTable!=null)...[
        const SizedBox(height:15),
        Text('Cantidad de puestos (máximo '+capacity.toString()+')',
         style:const TextStyle(color:EventColors.text,fontWeight:FontWeight.w700)),
        const SizedBox(height:7),
        DropdownButtonFormField<int>(
         value:seats,
         decoration:const InputDecoration(
          labelText:'Puestos a apartar',border:OutlineInputBorder()),
         items:List.generate(capacity,(i)=>DropdownMenuItem<int>(
          value:i+1,child:Text((i+1).toString()+' puestos'))),
         onChanged:saving?null:(value){
          if(value!=null)setState((){
           seats=value;chosenChairs.clear();
          });
         }),
        if(manual&&selectedInfo!=null)...[
         const SizedBox(height:13),
         const Text('Selecciona las sillas de esta mesa',
          style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
         const SizedBox(height:8),
         Wrap(spacing:7,runSpacing:7,children:[
          for(var n=1;n<=fullCapacity;n++)
           FilterChip(
            label:Text('Silla '+n.toString()),
            selected:chosenChairs.contains(n),
            onSelected:unavailable.contains(n)?null:(chosen)=>setState((){
             if(chosen){if(chosenChairs.length<seats)chosenChairs.add(n);}
             else{chosenChairs.remove(n);}
            })),
         ]),
         const SizedBox(height:6),
         Text(chosenChairs.length.toString()+' de '+seats.toString()+' sillas seleccionadas',
          style:const TextStyle(color:EventColors.muted,fontSize:12)),
        ],
       ],
       if(editing&&cancelled)...[
        const SizedBox(height:14),
        EventPanel(background:EventColors.surfaceLight,child:Column(
         crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Reserva cancelada',style:TextStyle(
           color:EventColors.warning,fontWeight:FontWeight.w800)),
          const SizedBox(height:7),
          const Text('Puedes corregir los datos sin ocupar la mesa. Para volver a apartarla, activa la opción y confirma que sigue disponible.',
           style:TextStyle(color:EventColors.muted,fontSize:12)),
          const SizedBox(height:9),
          SwitchListTile(
           value:reactivate,
           contentPadding:EdgeInsets.zero,
           title:const Text('Reactivar esta reserva',
            style:TextStyle(color:EventColors.text)),
           subtitle:const Text('Vuelve a bloquear la mesa seleccionada'),
           onChanged:saving?null:(v)=>setState((){
              reactivate=v;
              if(v && chosenChairs.any(unavailable.contains))chosenChairs.clear();
            })),
         ])),
       ],
       const SizedBox(height:19),
       const EventSectionHeading(icon:Icons.person_outline,
        title:'Datos del responsable',
        subtitle:'El teléfono es opcional; no se exige correo ni pago.'),
       const SizedBox(height:11),
       TextFormField(controller:name,maxLength:140,
        decoration:const InputDecoration(labelText:'Nombre o responsable *',
         border:OutlineInputBorder()),
        validator:(v)=>(v?.trim().isEmpty??true)?'Escribe el nombre':null),
       const SizedBox(height:10),
       TextFormField(controller:phone,maxLength:40,
        keyboardType:TextInputType.phone,
        decoration:const InputDecoration(labelText:'Teléfono de contacto',
         border:OutlineInputBorder())),
       const SizedBox(height:10),
       TextFormField(controller:notes,maxLength:600,maxLines:2,
        decoration:const InputDecoration(labelText:'Observaciones (opcional)',
         border:OutlineInputBorder())),
       const SizedBox(height:8),
       const EventPill(icon:Icons.verified_outlined,
        label:'Reserva confirmada sin giro de dinero',
        color:EventColors.success),
      ]),
     )),
     Container(width:double.infinity,padding:const EdgeInsets.all(15),
      decoration:const BoxDecoration(color:Color(0xFF082532),
       border:Border(top:BorderSide(color:EventColors.border))),
      child:LayoutBuilder(builder:(context,box){
       final cancel=OutlinedButton(
        onPressed:saving?null:()=>Navigator.pop(context,false),
        child:const Text('Cancelar'));
       final saveButton=FilledButton.icon(
        onPressed:saving?null:save,
        style:FilledButton.styleFrom(backgroundColor:EventColors.primary,
         foregroundColor:EventColors.onPrimary),
        icon:const Icon(Icons.check_circle_outline,size:18),
        label:Text(saving?'Guardando...':editing
          ?(cancelled&&reactivate?'Guardar y reactivar':'Guardar cambios')
          :'Confirmar sin cobro'));
       if(box.maxWidth<450)return Column(
        mainAxisSize:MainAxisSize.min,children:[
         SizedBox(width:double.infinity,child:saveButton),
         const SizedBox(height:9),
         SizedBox(width:double.infinity,child:cancel),
        ]);
       return Row(children:[
        Expanded(child:cancel),
        const SizedBox(width:11),
        Expanded(child:saveButton),
       ]);
      }),
     ),
    ])),
   ),
  );
 }
}

class EventoEditor extends ConsumerStatefulWidget{
 const EventoEditor({super.key,required this.onSaved,this.initial});
 final Map<String,dynamic>? initial;
 final ValueChanged<Map<String,dynamic>> onSaved;
 @override ConsumerState<EventoEditor> createState()=>_EventEditorState();
}
class _EventEditorState extends ConsumerState<EventoEditor>{
 final form=GlobalKey<FormState>();
 final productSearch=TextEditingController();
 final title=TextEditingController(),description=TextEditingController(),
       amount=TextEditingController(text:'0'),instructions=TextEditingController(),
       mapsUrl=TextEditingController();
 final primaryHex=TextEditingController(text:'#35D0C5'),
       backgroundHex=TextEditingController(text:'#102735'),
       textHex=TextEditingController(text:'#F2FBFF'),
       cardHex=TextEditingController(),borderHex=TextEditingController(),
       menuHex=TextEditingController();
 final instagramUrl=TextEditingController(),facebookUrl=TextEditingController(),
       tiktokUrl=TextEditingController(),whatsappUrl=TextEditingController();
 String bookingMode='MESA';bool sharing=false,selectChairs=false,selectTable=true;
 bool get bookingLocked=>(asId(widget.initial?['reservasRegistradas'])??0)>0;
 String? customLogo;
 DateTime start=DateTime.now().add(const Duration(days:1)).copyWith(hour:20,minute:0),
   finish=DateTime.now().add(const Duration(days:2)).copyWith(hour:2,minute:0);
 String method='GRATIS';String? photo;bool publish=false,busy=false;
 int? branch;Set<int> chosen={};List<Map<String,dynamic>> tables=[];
 Map<int,int> capacities={};List<String> venuePhotos=[];
 List<Map<String,dynamic>> availableProducts=[];
 Set<int> selectedProducts={};
 bool loadingProducts=false,onlySelected=false;
 String typeFilter='TODOS',brandFilter='TODAS',controlFilter='TODOS';
 String? productError;
 int productRequest=0;
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
   selectedProducts=(i['productos'] as List? ??[]).map(asId).whereType<int>().toSet();
   bookingMode=i['modoReserva']?.toString()??'MESA';
   sharing=i['compartirMesa']==true;selectChairs=i['seleccionarSillas']==true;
   selectTable=i['seleccionarMesa']!=false;
   primaryHex.text=i['colorPrimario']?.toString()??'#23D8D1';
   backgroundHex.text=i['colorFondo']?.toString()??'#061925';
   textHex.text=i['colorTexto']?.toString()??'#F2FBFF';
   cardHex.text=i['colorTarjeta']?.toString()??'';
   borderHex.text=i['colorBorde']?.toString()??'';
   menuHex.text=i['colorCarta']?.toString()??'';
   customLogo=i['logoEvento']?.toString();
   instagramUrl.text=i['instagram']?.toString()??'';
   facebookUrl.text=i['facebook']?.toString()??'';
   tiktokUrl.text=i['tiktok']?.toString()??'';
   whatsappUrl.text=i['whatsapp']?.toString()??'';
  }
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_loadTables();});
 }
 @override void dispose(){
  productSearch.dispose();title.dispose();description.dispose();amount.dispose();
  instructions.dispose();mapsUrl.dispose();
  primaryHex.dispose();backgroundHex.dispose();textHex.dispose();
  cardHex.dispose();borderHex.dispose();menuHex.dispose();
  instagramUrl.dispose();facebookUrl.dispose();tiktokUrl.dispose();
  whatsappUrl.dispose();super.dispose();
 }
 Future<void> _loadTables()async{
  branch??=ref.read(branchScopeProvider).activeBranchId;
  final branchId=branch;
  if(branchId==null)return;
  _loadProducts(branchId);
  try{
   final rows=await ref.read(eventosApiProvider).mesas(branchId);
   if(!mounted||branch!=branchId)return;
   setState(()=>tables=rows.where((e)=>
    e['mesaEstado']?.toString().toUpperCase()!='INACTIVA').toList());
  }catch(e){
   if(mounted&&branch==branchId)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text('Mesas: '+niceEventError(e))));
  }
 }
 Future<void> _createProduct()async{
  final branchId=branch;
  if(branchId==null){
   ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Selecciona la sucursal primero')));
   return;
  }
  final created=await showDialog<int>(
   context:context,barrierDismissible:false,
   builder:(dialog)=>Dialog(
    backgroundColor:EventColors.background,
    insetPadding:const EdgeInsets.all(12),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
    child:SizedBox(
     width:MediaQuery.sizeOf(dialog).width>1320?1180.0:MediaQuery.sizeOf(dialog).width*.95,
     height:MediaQuery.sizeOf(dialog).height*.92,
     child:ProductosFormPage(embedded:true,sucursalId:branchId)),
   ),
  );
  if(!mounted||branch!=branchId||created==null)return;
  await _loadProducts(branchId);
  if(!mounted)return;
  if(availableProducts.any((p)=>asId(p['id'])==created)){
   setState(()=>selectedProducts.add(created));
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Producto creado y agregado al evento')));
  }else{
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content:Text('Producto creado. Comprueba que tenga precio vigente en esta sucursal.')));
  }
 }
 Future<void> _loadProducts(int branchId)async{
  final req=++productRequest;
  if(mounted)setState((){loadingProducts=true;productError=null;});
  try{
   final products=await ref.read(eventosApiProvider).productos(branchId);
   if(!mounted||branch!=branchId||req!=productRequest)return;
   setState((){
    availableProducts=products;loadingProducts=false;productError=null;
   });
  }catch(e){
   if(!mounted||branch!=branchId||req!=productRequest)return;
   setState((){
    loadingProducts=false;productError=niceEventError(e);
   });
  }
 }
 Future<void> _pickLogo()async{
  final selected=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);
  final image=selected?.files.singleOrNull;
  if(image==null||image.bytes==null)return;
  if(image.size>1700000){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
   const SnackBar(content:Text('El logo no debe superar 1.7 MB')));return;}
  final ext=image.extension?.toLowerCase();
  if(!['jpg','jpeg','png','webp'].contains(ext)){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Formatos admitidos: JPG, PNG o WebP')));return;
  }
  final mime=ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg';
  if(mounted)setState(()=>customLogo='data:'+mime+';base64,'+base64Encode(image.bytes!));
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
  if(!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(primaryHex.text.trim())||
     !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(backgroundHex.text.trim())||
     !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(textHex.text.trim())||
     [cardHex,borderHex,menuHex].any((controller)=>controller.text.trim().isNotEmpty&&
       !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(controller.text.trim()))){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('Usa colores con el formato #RRGGBB')));
    return;
  }
  setState(()=>busy=true);
  try{
   final body={'sucursalId':branch,'titulo':title.text.trim(),'descripcion':description.text.trim(),
    'imagen':photo,'inicio':start.toIso8601String(),'fin':finish.toIso8601String(),
    'precio':price,'medioPago':method,'instruccionesPago':instructions.text.trim(),
    'mesas':chosen.toList(),'publicar':publish,
    'googleMapsUrl':mapsUrl.text.trim(),'fotosLugar':venuePhotos,
    'capacidadesMesas':{for(final id in chosen)id.toString():capacities[id]??6},
    'productos':selectedProducts.toList(),
    'modoReserva':bookingMode,
    'compartirMesa':bookingMode=='PUESTOS'&&sharing,
    'seleccionarSillas':bookingMode=='PUESTOS'&&selectTable&&selectChairs,
    'seleccionarMesa':bookingMode!='PUESTOS'||selectTable,
    'colorPrimario':primaryHex.text.trim(),
    'colorFondo':backgroundHex.text.trim(),
    'colorTexto':textHex.text.trim(),'logo':customLogo,
    'colorTarjeta':cardHex.text.trim(),
    'colorBorde':borderHex.text.trim(),
    'colorCarta':menuHex.text.trim(),
    'instagram':instagramUrl.text.trim(),
    'facebook':facebookUrl.text.trim(),
    'tiktok':tiktokUrl.text.trim(),'whatsapp':whatsappUrl.text.trim()};
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
    'even_estado':result['estado']??widget.initial?['even_estado']??(publish?'PUBLICADO':'BORRADOR'),
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
       onChanged:null, // La sede se cambia desde el selector principal.
       /* onChanged:(v){setState((){
         productRequest++;
         branch=v;tables=[];chosen={};capacities={};
         availableProducts=[];selectedProducts={};onlySelected=false;
         typeFilter='TODOS';brandFilter='TODAS';controlFilter='TODOS';
         productSearch.clear();productError=null;
       });_loadTables();}), */
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

 Widget _bookingPreferences()=>_block(3,'Modalidad de reservas',
  'Decide si vendes mesas completas o puestos individuales y cómo se eligen las sillas.',
  Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   SegmentedButton<String>(
    segments:const [
     ButtonSegment(value:'MESA',label:Text('Mesa completa'),
      icon:Icon(Icons.table_restaurant_outlined)),
     ButtonSegment(value:'PUESTOS',label:Text('Por puestos'),
      icon:Icon(Icons.event_seat_outlined)),
    ],selected:{bookingMode},
    onSelectionChanged:bookingLocked?null:(v)=>setState((){
     bookingMode=v.first;
     if(bookingMode=='MESA'){sharing=false;selectChairs=false;selectTable=true;}
    })),
   const SizedBox(height:12),
   Text(bookingMode=='MESA'
     ?'Una reserva ocupa la mesa entera, incluso si hay menos asistentes.'
     :'La persona puede reservar uno o varios puestos de la misma mesa.',
     style:const TextStyle(color:EventColors.muted,fontSize:12)),
   if(bookingMode=='PUESTOS')...[
    const SizedBox(height:12),
    SwitchListTile.adaptive(
     contentPadding:EdgeInsets.zero,value:selectTable,
     title:const Text('Permitir que el cliente elija la mesa',
      style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w700)),
     subtitle:const Text('Si está desactivado, solo se elige la cantidad de puestos. BarLytics asigna automáticamente una mesa con disponibilidad.'),
     onChanged:(v)=>setState((){
      selectTable=v;
      if(!v)selectChairs=false;
     })),
    SwitchListTile.adaptive(
     contentPadding:EdgeInsets.zero,value:sharing,
     title:const Text('Permitir compartir mesa',
      style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w700)),
     subtitle:const Text('Admite reservas independientes en distintos puestos de una mesa.'),
     onChanged:bookingLocked?null:(v)=>setState(()=>sharing=v)),
    SwitchListTile.adaptive(
     contentPadding:EdgeInsets.zero,value:selectChairs,
     title:const Text('El cliente puede elegir sus sillas',
      style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w700)),
     subtitle:const Text('Si está apagado, BarLytics asigna los asientos automáticamente.'),
     onChanged:bookingLocked||!selectTable?null:(v)=>setState(()=>selectChairs=v)),
   ],
   const SizedBox(height:8),
   if(bookingLocked)Container(
     padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(
       borderRadius:BorderRadius.circular(11),
       color:EventColors.surfaceLight,
       border:Border.all(color:EventColors.border)),
     child:const Row(children:[
       Icon(Icons.lock_outline,color:EventColors.warning,size:20),
       SizedBox(width:10),
       Expanded(child:Text(
         'Este evento ya tiene reservas. Para proteger sus puestos, la modalidad y las sillas quedan bloqueadas; puedes seguir editando el diseño, colores, fotos y carta.',
         style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5))),
     ]),
   )else const Text(
    'Puedes cambiar la modalidad mientras no haya reservas registradas.',
    style:TextStyle(color:EventColors.muted,fontSize:11)),
  ]));

 Future<void> _pickThemeColor(
   TextEditingController controller,String heading) async {
  final paletteNow=EventPagePalette.fromHex(
    primaryHex.text,backgroundHex.text,textHex.text,
    cardHex.text,borderHex.text,menuHex.text);
  final fallback=identical(controller,cardHex)?paletteNow.surface:
    identical(controller,borderHex)?paletteNow.border:
    identical(controller,menuHex)?paletteNow.menuPaper:
    EventColors.primary;
  var hsv=HSVColor.fromColor(EventPagePalette.parse(controller.text,fallback));
  final selected=await showDialog<Color>(
   context:context,
   builder:(dialogContext)=>StatefulBuilder(
    builder:(dialogContext,update)=>AlertDialog(
     backgroundColor:EventColors.surface,
     title:Text(heading,style:const TextStyle(color:EventColors.text)),
     content:SizedBox(width:380,child:Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Container(height:68,decoration:BoxDecoration(
        color:hsv.toColor(),
        borderRadius:BorderRadius.circular(13),
        border:Border.all(color:EventColors.border))),
       const SizedBox(height:16),
       const Text('Tono',style:TextStyle(color:EventColors.muted)),
       Slider(value:hsv.hue,min:0,max:360,
        onChanged:(v)=>update(()=>hsv=hsv.withHue(v))),
       const Text('Intensidad',style:TextStyle(color:EventColors.muted)),
       Slider(value:hsv.saturation,min:0,max:1,
        onChanged:(v)=>update(()=>hsv=hsv.withSaturation(v))),
       const Text('Luminosidad',style:TextStyle(color:EventColors.muted)),
       Slider(value:hsv.value,min:0,max:1,
        onChanged:(v)=>update(()=>hsv=hsv.withValue(v))),
      ],
     )),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(dialogContext),
       child:const Text('Cancelar')),
      FilledButton(onPressed:()=>Navigator.pop(dialogContext,hsv.toColor()),
       child:const Text('Aplicar color')),
     ],
    ),
   ),
  );
  if(selected==null||!mounted)return;
  final rgb=(selected.toARGB32()&0xFFFFFF)
    .toRadixString(16).padLeft(6,'0').toUpperCase();
  setState(()=>controller.text='#'+rgb);
 }

 Widget _visualTheme(){
  final previewProducts=availableProducts.where(
    (p)=>selectedProducts.contains(asId(p['id']))).take(2).toList();
  final selected=EventPagePalette.fromHex(
    primaryHex.text.trim(),backgroundHex.text.trim(),textHex.text.trim(),
    cardHex.text.trim(),borderHex.text.trim(),menuHex.text.trim());
  final validAccent=RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(primaryHex.text.trim());
  final validBase=RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(backgroundHex.text.trim());
  final validText=RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(textHex.text.trim());
  final validAdvanced=[cardHex,borderHex,menuHex].every(
    (c)=>c.text.trim().isEmpty||RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c.text.trim()));

  Widget presetCard(EventPalettePreset p){
   final scheme=EventPagePalette.fromHex(p.accent,p.background,p.text);
   final active=primaryHex.text.toUpperCase()==p.accent &&
     backgroundHex.text.toUpperCase()==p.background &&
     textHex.text.toUpperCase()==p.text &&
     cardHex.text.trim().isEmpty&&borderHex.text.trim().isEmpty&&
     menuHex.text.trim().isEmpty;
   return Container(
    width:225,padding:const EdgeInsets.all(11),
    decoration:BoxDecoration(
     color:EventColors.surfaceLight,
     borderRadius:BorderRadius.circular(15),
     border:Border.all(
      color:active?EventColors.primary:EventColors.border,
      width:active?2:1)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     InkWell(
      onTap:()=>setState((){
       primaryHex.text=p.accent;
       backgroundHex.text=p.background;
       textHex.text=p.text;
       cardHex.clear();borderHex.clear();menuHex.clear();
      }),
      borderRadius:BorderRadius.circular(11),
      child:Container(
       padding:const EdgeInsets.all(12),
       decoration:BoxDecoration(
        color:scheme.canvas,borderRadius:BorderRadius.circular(11)),
       child:Row(children:[
        Container(width:34,height:34,
         decoration:BoxDecoration(
          shape:BoxShape.circle,
          color:scheme.accent,
          border:Border.all(color:Colors.white24,width:2))),
        const SizedBox(width:11),
        Expanded(child:Column(
         crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,
           style:TextStyle(color:scheme.text,
            fontWeight:FontWeight.w800,fontSize:13)),
          Text(p.description,maxLines:1,overflow:TextOverflow.ellipsis,
           style:TextStyle(color:scheme.muted,fontSize:10)),
         ])),
        if(active)Icon(Icons.check_circle,
          color:scheme.accent,size:17),
       ]),
      ),
     ),
     const SizedBox(height:8),
     Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      for(final color in [scheme.canvas,scheme.surface,scheme.text,scheme.accent])
       Container(width:25,height:13,margin:const EdgeInsets.symmetric(horizontal:3),
        decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(3),
         border:Border.all(color:EventColors.border))),
     ]),
     const SizedBox(height:6),
     Row(children:[
      Expanded(child:TextButton(
       onPressed:()=>setState(()=>primaryHex.text=p.accent),
       style:TextButton.styleFrom(
        padding:const EdgeInsets.symmetric(horizontal:4)),
       child:const Text('Solo acento',style:TextStyle(fontSize:11)))),
      Expanded(child:TextButton(
       onPressed:()=>setState((){
        backgroundHex.text=p.background;
        if(EventPagePalette.contrast(
          EventPagePalette.parse(textHex.text,EventColors.text),
          EventPagePalette.parse(p.background,EventColors.background))<4.5){
          textHex.text=p.text;
        }
       }),
       style:TextButton.styleFrom(
        padding:const EdgeInsets.symmetric(horizontal:4)),
       child:const Text('Solo fondo',style:TextStyle(fontSize:11)))),
     ]),
     SizedBox(width:double.infinity,child:TextButton(
      onPressed:()=>setState(()=>textHex.text=p.text),
      child:const Text('Solo texto',style:TextStyle(fontSize:11)))),
    ]),
   );
  }

  return _block(4,'Identidad y paleta de colores',
   'Combinaciones profesionales con fondos armonizados. Puedes mezclarlas y ajustar cada color a tu gusto.',
   Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Logo del evento o establecimiento',
     style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
    const SizedBox(height:9),
    Wrap(spacing:13,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:[
     EventArtwork(source:customLogo,width:76,height:76,
      emptyIcon:Icons.storefront_outlined),
     OutlinedButton.icon(onPressed:_pickLogo,
      icon:const Icon(Icons.add_photo_alternate_outlined),
      label:const Text('Cargar logo')),
     if(customLogo!=null)TextButton.icon(
      onPressed:()=>setState(()=>customLogo=null),
      icon:const Icon(Icons.close,size:17),
      label:const Text('Quitar')),
    ]),
    const SizedBox(height:20),
    const Text('Paletas prediseñadas',
     style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800,fontSize:15)),
    const SizedBox(height:5),
    const Text('Selecciona una combinación completa de fondo, texto y acento. O mezcla los colores a tu gusto.',
     style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5)),
    const SizedBox(height:13),
    Wrap(spacing:10,runSpacing:10,children:[
     for(final preset in eventPalettePresets)presetCard(preset),
    ]),
    const SizedBox(height:20),
    Row(children:[
     const Expanded(child:Text('Personaliza tus propios tonos',
      style:TextStyle(color:EventColors.text,
       fontWeight:FontWeight.w800,fontSize:15))),
     TextButton.icon(
      onPressed:()=>setState((){
       primaryHex.text='#35D0C5';
       backgroundHex.text='#102735';
       textHex.text='#F2FBFF';
       cardHex.clear();borderHex.clear();menuHex.clear();
      }),
      icon:const Icon(Icons.restart_alt_outlined,size:17),
      label:const Text('Restablecer')),
    ]),
    const SizedBox(height:7),
    LayoutBuilder(builder:(context,space){
     Widget input(TextEditingController controller,String label,
        String helper,Color swatch){
      return TextField(
       controller:controller,
       maxLength:7,
       onChanged:(_)=>setState((){}),
       decoration:InputDecoration(
        labelText:label,counterText:'',
        helperText:helper,helperMaxLines:2,
        prefixIcon:Padding(padding:const EdgeInsets.all(12),
         child:Container(width:20,height:20,
          decoration:BoxDecoration(
           color:swatch,borderRadius:BorderRadius.circular(7),
           border:Border.all(color:Colors.white54)))),
       ),
      );
     }
     final accentInput=input(primaryHex,'Color de acento · #RRGGBB',
      'Botones, destacados e iconos',selected.accent);
     final backgroundInput=input(backgroundHex,'Color del fondo · #RRGGBB',
      'Determina el fondo y las tarjetas',selected.canvas);
     final textInput=input(textHex,'Color del texto · #RRGGBB',
      'Títulos, descripciones y carta',selected.text);
     if(space.maxWidth<560)return Column(children:[
      accentInput,const SizedBox(height:10),backgroundInput,
      const SizedBox(height:10),textInput,
     ]);
     return Row(children:[
      Expanded(child:accentInput),const SizedBox(width:14),
      Expanded(child:backgroundInput),const SizedBox(width:14),
      Expanded(child:textInput),
     ]);
    }),
    const SizedBox(height:10),
    Wrap(spacing:12,runSpacing:9,children:[
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(primaryHex,'Elegir color de acento'),
      icon:const Icon(Icons.color_lens_outlined),
      label:const Text('Elegir acento visualmente')),
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(backgroundHex,'Elegir tono de ambiente'),
      icon:const Icon(Icons.format_color_fill_outlined),
      label:const Text('Elegir ambiente visualmente')),
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(textHex,'Elegir color del texto'),
      icon:const Icon(Icons.format_color_text_outlined),
      label:const Text('Elegir color del texto')),
    ]),
    if(!validAccent||!validBase||!validText||!validAdvanced)
     const Padding(padding:EdgeInsets.only(top:7),child:Text(
      'Escribe seis dígitos hexadecimales por color, por ejemplo #E6BE83.',
      style:TextStyle(color:EventColors.warning,fontSize:12))),
    const SizedBox(height:19),
    Row(children:[
     const Expanded(child:Text('Opciones avanzadas',
       style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800,fontSize:15))),
     TextButton.icon(
      onPressed:()=>setState((){
       cardHex.clear();borderHex.clear();menuHex.clear();
      }),
      icon:const Icon(Icons.auto_awesome_outlined,size:17),
      label:const Text('Colores automáticos')),
    ]),
    const Text('Deja vacío cualquier campo para heredar el color de la paleta. Puedes personalizar cada superficie sin afectar a otros eventos.',
     style:TextStyle(color:EventColors.muted,fontSize:12,height:1.45)),
    const SizedBox(height:10),
    LayoutBuilder(builder:(context,space){
     Widget field(TextEditingController controller,String name,Color sample){
      return TextField(controller:controller,maxLength:7,
       onChanged:(_)=>setState((){}),
       decoration:InputDecoration(labelText:name,counterText:'',
        hintText:'Automático',
        prefixIcon:Padding(padding:const EdgeInsets.all(12),
         child:Container(width:20,height:20,decoration:BoxDecoration(
          color:sample,borderRadius:BorderRadius.circular(6))))));
     }
     final controls=<Widget>[
      field(cardHex,'Fondo de las tarjetas',selected.surface),
      field(borderHex,'Color de los bordes',selected.border),
      field(menuHex,'Color de las hojas de carta',selected.menuPaper),
     ];
     if(space.maxWidth<570)return Column(children:[
      controls[0],const SizedBox(height:9),controls[1],
      const SizedBox(height:9),controls[2],
     ]);
     return Row(children:[
      Expanded(child:controls[0]),const SizedBox(width:12),
      Expanded(child:controls[1]),const SizedBox(width:12),
      Expanded(child:controls[2]),
     ]);
    }),
    const SizedBox(height:8),
    Wrap(spacing:10,runSpacing:9,children:[
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(cardHex,'Color de tarjetas'),
      icon:const Icon(Icons.dashboard_customize_outlined),
      label:const Text('Tarjetas')),
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(borderHex,'Color de bordes'),
      icon:const Icon(Icons.border_outer_outlined),
      label:const Text('Bordes')),
     OutlinedButton.icon(
      onPressed:()=>_pickThemeColor(menuHex,'Color de carta'),
      icon:const Icon(Icons.menu_book_outlined),
      label:const Text('Hojas de carta')),
    ]),
    if(!validAdvanced)
     const Text('Los colores personalizados deben tener formato #RRGGBB.',
       style:TextStyle(color:EventColors.warning,fontSize:12)),
    const SizedBox(height:18),
    const Text('Vista previa en vivo',
     style:TextStyle(color:EventColors.text,
      fontWeight:FontWeight.w800,fontSize:15)),
    const SizedBox(height:11),
    Container(
     clipBehavior:Clip.antiAlias,
     decoration:BoxDecoration(color:selected.canvas,
      borderRadius:BorderRadius.circular(16),
      border:Border.all(color:selected.border)),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(18),
       decoration:BoxDecoration(gradient:LinearGradient(
        begin:Alignment.centerLeft,end:Alignment.centerRight,
        colors:[selected.heroShade,selected.canvas])),
       child:Wrap(spacing:16,runSpacing:12,
        crossAxisAlignment:WrapCrossAlignment.center,children:[
        EventArtwork(source:customLogo??photo,width:66,height:66,
         emptyIcon:Icons.event_outlined),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text(title.text.trim().isEmpty?'Tu próximo gran evento':title.text,
          maxLines:2,overflow:TextOverflow.ellipsis,
          style:TextStyle(color:selected.text,
           fontSize:21,fontWeight:FontWeight.w900)),
         const SizedBox(height:6),
         Text('Presentación del establecimiento',
          style:TextStyle(color:selected.muted,fontSize:11)),
        ]),
        Container(
         padding:const EdgeInsets.symmetric(horizontal:16,vertical:11),
         decoration:BoxDecoration(color:selected.accent,
          borderRadius:BorderRadius.circular(11)),
         child:Text('Reservar ahora',
          style:TextStyle(color:selected.onAccent,
           fontWeight:FontWeight.w800,fontSize:12)),
        ),
       ]),
      ),
      Padding(padding:const EdgeInsets.all(15),
       child:Row(children:[
        Expanded(child:Container(
         padding:const EdgeInsets.all(14),
         decoration:BoxDecoration(color:selected.surface,
          border:Border.all(color:selected.border),
          borderRadius:BorderRadius.circular(12)),
         child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.image_outlined,color:selected.accent),
          const SizedBox(height:8),
          Text('Afiche oficial',
           style:TextStyle(color:selected.text,fontWeight:FontWeight.w800)),
          const SizedBox(height:3),
          Text('Superficie personalizable',
           style:TextStyle(color:selected.muted,fontSize:10)),
         ]))),
        const SizedBox(width:10),
        Expanded(child:Container(
         padding:const EdgeInsets.all(14),
         decoration:BoxDecoration(color:selected.surfaceSoft,
          border:Border.all(color:selected.border),
          borderRadius:BorderRadius.circular(12)),
         child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.restaurant_menu,color:selected.accent),
          const SizedBox(height:8),
          Text('Nuestra carta',
           style:TextStyle(color:selected.text,fontWeight:FontWeight.w800)),
          const SizedBox(height:3),
          Text('Tarjetas y detalles',
           style:TextStyle(color:selected.muted,fontSize:10)),
         ]))),
       ]),
      ),
     ]),
    ),
    const SizedBox(height:13),
    Container(
     width:double.infinity,padding:const EdgeInsets.all(8),
     decoration:BoxDecoration(color:selected.menuPaper,
      border:Border.all(color:selected.menuBorder,width:2)),
     child:Container(padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(border:Border.all(
       color:selected.menuBorder.withOpacity(.7))),
      child:Column(children:[
       Text('CARTA DEL EVENTO',textAlign:TextAlign.center,
        style:TextStyle(fontFamily:'Georgia',fontSize:20,
         letterSpacing:2,color:selected.menuInk)),
       const SizedBox(height:6),
       Text(title.text.trim().isEmpty?'Vista previa del evento':title.text.trim(),
        textAlign:TextAlign.center,maxLines:2,
        style:TextStyle(fontFamily:'Georgia',
          color:selected.menuInk,fontSize:11)),
       const SizedBox(height:12),
       Divider(color:selected.menuBorder),
       if(previewProducts.isEmpty)
        Text('Selecciona productos del catálogo para previsualizarlos',
         textAlign:TextAlign.center,
         style:TextStyle(color:selected.menuInk,fontSize:11))
       else for(final p in previewProducts)...[
        Row(children:[
         Expanded(child:Text((p['nombre']??'').toString(),
          maxLines:2,style:TextStyle(fontFamily:'Georgia',
           color:selected.menuInk,fontWeight:FontWeight.bold))),
         const SizedBox(width:10),
         Text(p['precio']==null?'Consultar':
          NumberFormat.currency(locale:'es_CO',symbol:'\$',decimalDigits:0).format(
            double.tryParse(p['precio'].toString())??0),
          style:TextStyle(fontFamily:'Georgia',
           fontWeight:FontWeight.bold,color:selected.menuInk)),
        ]),
        if((p['descripcion']?.toString()??'').isNotEmpty)
         Align(alignment:Alignment.centerLeft,
          child:Text(p['descripcion'].toString(),maxLines:2,
           overflow:TextOverflow.ellipsis,
           style:TextStyle(fontFamily:'Georgia',
            color:selected.menuInk,fontSize:11))),
        Divider(color:selected.menuBorder),
       ],
      ]),
     ),
    ),
    const SizedBox(height:10),
    const Text('La carta, fondos y tarjetas siguen los colores elegidos. Ajusta el contraste para lograr una lectura cómoda.',
     style:TextStyle(color:EventColors.muted,fontSize:11,height:1.5)),
    if(EventPagePalette.contrast(selected.text,selected.surface)<4.5)
     const Padding(padding:EdgeInsets.symmetric(vertical:5),
      child:Text('El texto contrasta poco con las tarjetas: cambia la letra o el fondo.',
       style:TextStyle(color:EventColors.warning,fontWeight:FontWeight.w700,fontSize:12))),
    if(EventPagePalette.contrast(selected.menuInk,selected.menuPaper)<4.5)
     const Padding(padding:EdgeInsets.symmetric(vertical:5),
      child:Text('El color de las hojas de carta tiene poco contraste con el texto.',
       style:TextStyle(color:EventColors.warning,fontWeight:FontWeight.w700,fontSize:12))),
    const SizedBox(height:20),
    const Text('Redes sociales para la página pública',
     style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
    const SizedBox(height:9),
    TextField(controller:instagramUrl,
      decoration:const InputDecoration(prefixIcon:Icon(Icons.camera_alt_outlined),
        labelText:'Instagram · enlace HTTPS')),
    const SizedBox(height:9),
    TextField(controller:facebookUrl,
      decoration:const InputDecoration(prefixIcon:Icon(Icons.people_alt_outlined),
        labelText:'Facebook · enlace HTTPS')),
    const SizedBox(height:9),
    TextField(controller:tiktokUrl,
      decoration:const InputDecoration(prefixIcon:Icon(Icons.smart_display_outlined),
        labelText:'TikTok · enlace HTTPS')),
    const SizedBox(height:9),
    TextField(controller:whatsappUrl,
      decoration:const InputDecoration(prefixIcon:Icon(Icons.chat_outlined),
        labelText:'WhatsApp · enlace wa.me HTTPS')),
   ]));
 }

 Widget _tables()=>_block(5,'Mesas habilitadas',
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

 Widget _products()=>_block(6,'Productos destacados del evento',
  'Selecciona de la carta de esta sucursal lo que verán tus asistentes.',
  Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
    SizedBox(width:300,child:TextField(
     controller:productSearch,onChanged:(_)=>setState((){}),
     decoration:const InputDecoration(
      hintText:'Buscar bebidas, comidas o cócteles',
      prefixIcon:Icon(Icons.search_outlined),isDense:true))),
    FilterChip(
     selected:onlySelected,
     label:Text('Seleccionados ('+selectedProducts.length.toString()+')'),
     onSelected:(v)=>setState(()=>onlySelected=v)),
    OutlinedButton.icon(
     onPressed:loadingProducts||branch==null?null:()=>_loadProducts(branch!),
     icon:const Icon(Icons.refresh,size:18),
     label:const Text('Actualizar')),
    FilledButton.icon(
     onPressed:busy?null:_createProduct,
     style:FilledButton.styleFrom(backgroundColor:EventColors.primary,
       foregroundColor:EventColors.onPrimary),
     icon:const Icon(Icons.add_circle_outline,size:18),
     label:const Text('Crear producto')),
   ]),
   const SizedBox(height:12),
   if(availableProducts.isNotEmpty)
    LayoutBuilder(builder:(context,box){
     final types=<String,String>{'TODOS':'Todos los tipos'};
     final brands=<String,String>{'TODAS':'Todas las marcas'};
     for(final item in availableProducts){
      final typeKey=item['tipoId']?.toString()??'SIN_TIPO';
      types[typeKey]=item['tipo']?.toString()??'Sin tipo';
      final brandKey=item['marcaId']?.toString()??'SIN_MARCA';
      brands[brandKey]=item['marca']?.toString()??'Sin marca';
     }
     final controls=<String,String>{
      'TODOS':'Todos los controles',
      'NORMAL':'Normal',
      'PREPARADO':'Preparado',
      'ADICIONAL':'Adicional'
     };
     final w=box.maxWidth>630?(box.maxWidth-18)/3:box.maxWidth;
     return Wrap(spacing:9,runSpacing:9,children:[
      SizedBox(width:w,child:DropdownButtonFormField<String>(
       value:types.containsKey(typeFilter)?typeFilter:'TODOS',
       isExpanded:true,
       decoration:const InputDecoration(
        labelText:'Tipo de producto',isDense:true),
       items:types.entries.map((x)=>DropdownMenuItem<String>(
        value:x.key,child:Text(x.value,overflow:TextOverflow.ellipsis))).toList(),
       onChanged:(v)=>setState(()=>typeFilter=v??'TODOS'))),
      SizedBox(width:w,child:DropdownButtonFormField<String>(
       value:brands.containsKey(brandFilter)?brandFilter:'TODAS',
       isExpanded:true,
       decoration:const InputDecoration(
        labelText:'Marca',isDense:true),
       items:brands.entries.map((x)=>DropdownMenuItem<String>(
        value:x.key,child:Text(x.value,overflow:TextOverflow.ellipsis))).toList(),
       onChanged:(v)=>setState(()=>brandFilter=v??'TODAS'))),
      SizedBox(width:w,child:DropdownButtonFormField<String>(
       value:controls.containsKey(controlFilter)?controlFilter:'TODOS',
       isExpanded:true,
       decoration:const InputDecoration(
        labelText:'Tipo de control',isDense:true),
       items:controls.entries.map((x)=>DropdownMenuItem<String>(
        value:x.key,child:Text(x.value))).toList(),
       onChanged:(v)=>setState(()=>controlFilter=v??'TODOS'))),
     ]);
    }),
   const SizedBox(height:12),
   if(loadingProducts)const Padding(
    padding:EdgeInsets.all(25),child:Center(child:CircularProgressIndicator()))
   else if(productError!=null)
    EventPanel(background:EventColors.surfaceLight,child:Row(children:[
     const Icon(Icons.warning_amber_rounded,color:EventColors.warning),
     const SizedBox(width:10),
     Expanded(child:Text(productError!,
      style:const TextStyle(color:EventColors.muted,fontSize:12))),
     TextButton(onPressed:branch==null?null:()=>_loadProducts(branch!),
      child:const Text('Reintentar')),
    ]))
   else if(availableProducts.isEmpty)
    const Padding(padding:EdgeInsets.all(25),child:Center(
     child:Text('No hay productos vendibles con precio vigente en esta sucursal.',
      textAlign:TextAlign.center,style:TextStyle(color:EventColors.muted))))
   else LayoutBuilder(builder:(ctx,box){
    final query=productSearch.text.toLowerCase().trim();
    final filtered=availableProducts.where((item){
     final id=asId(item['id']);
     if(id==null||(onlySelected&&!selectedProducts.contains(id)))return false;
     if(typeFilter!='TODOS'&&(item['tipoId']?.toString()??'SIN_TIPO')!=typeFilter)return false;
     if(brandFilter!='TODAS'&&(item['marcaId']?.toString()??'SIN_MARCA')!=brandFilter)return false;
     if(controlFilter!='TODOS'&&(item['tipoControl']?.toString()??'NORMAL')!=controlFilter)return false;
     if(query.isEmpty)return true;
     return (item['nombre']?.toString().toLowerCase().contains(query)??false)||
            (item['descripcion']?.toString().toLowerCase().contains(query)??false);
    }).toList();
    if(filtered.isEmpty)return const Padding(
     padding:EdgeInsets.all(22),
     child:Text('No encontramos productos con esos filtros.',
      style:TextStyle(color:EventColors.muted)));
    return SizedBox(height:filtered.length<=3?132:340,
     child:GridView.builder(
      itemCount:filtered.length,
      gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
       maxCrossAxisExtent:310,mainAxisExtent:119,
       crossAxisSpacing:10,mainAxisSpacing:10),
      itemBuilder:(ctx,index){
       final item=filtered[index],id=asId(item['id']);
       if(id==null)return const SizedBox.shrink();
       final selected=selectedProducts.contains(id);
       final cost=NumberFormat.currency(locale:'es_CO',symbol:'COP ',
        decimalDigits:0).format(double.tryParse(item['precio']?.toString()??'')??0);
       return InkWell(
        onTap:(){
         if(!selected&&selectedProducts.length>=100){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content:Text('Puedes destacar máximo 100 productos por evento')));
          return;
         }
         setState((){if(selected)selectedProducts.remove(id);
           else selectedProducts.add(id);});
        },
        borderRadius:BorderRadius.circular(13),
        child:Container(
         clipBehavior:Clip.antiAlias,
         decoration:BoxDecoration(
          color:selected?const Color(0xFF194B5A):EventColors.surfaceLight,
          borderRadius:BorderRadius.circular(13),
          border:Border.all(
           color:selected?EventColors.primary:EventColors.border,
           width:selected?1.7:1)),
         child:Row(children:[
          SizedBox(width:90,child:Stack(children:[
           Positioned.fill(child:EventArtwork(
            source:item['imagen'],borderRadius:0,height:119,
            emptyIcon:Icons.restaurant_menu_outlined)),
           if(selected)const Positioned(top:7,left:7,
            child:CircleAvatar(radius:13,backgroundColor:EventColors.primary,
             child:Icon(Icons.check,color:EventColors.onPrimary,size:16))),
          ])),
          const SizedBox(width:11),
          Expanded(child:Column(
           mainAxisAlignment:MainAxisAlignment.center,
           crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(item['nombre']?.toString()??'Producto',
             maxLines:2,overflow:TextOverflow.ellipsis,
             style:const TextStyle(fontWeight:FontWeight.w800,
              color:EventColors.text,fontSize:12)),
            const SizedBox(height:7),
            Text(cost,style:const TextStyle(color:EventColors.primary,
             fontWeight:FontWeight.w700,fontSize:12)),
            const SizedBox(height:3),
            Text(selected?'Incluido en el evento':'Toca para incluir',
             style:TextStyle(fontSize:10,
              color:selected?EventColors.success:EventColors.muted)),
           ])),
          const SizedBox(width:8),
         ]),
        ),
       );
      },
     ));
   }),
   const SizedBox(height:12),
   Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:EventColors.surfaceLight,
      borderRadius:BorderRadius.circular(12),
      border:Border.all(color:EventColors.border)),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Icon(Icons.auto_stories_outlined,color:EventColors.primary,size:23),
     const SizedBox(width:12),
     Expanded(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(selectedProducts.isEmpty
         ?'No has seleccionado productos para la carta'
         :'Se crearán '+((selectedProducts.length+3)~/4).toString()+
           ' hoja(s) con '+selectedProducts.length.toString()+' producto(s)',
        style:const TextStyle(color:EventColors.text,
          fontWeight:FontWeight.w800,fontSize:13)),
       const SizedBox(height:6),
       const Text('Las hojas se crean automáticamente desde los productos '
        'seleccionados y guardados en la base de datos, con hasta cuatro '
        'productos por hoja. Mostrarán sus imágenes, nombres, descripciones y precios.',
        style:TextStyle(color:EventColors.muted,fontSize:11,height:1.5)),
      ],
     )),
    ]),
   ),
  ]));

 Widget _payments()=>_block(7,'Reservas y pagos',
   bookingMode=='PUESTOS'
     ?'Configura el precio por asistente y el método de pago.'
     :'Configura el precio por mesa completa y el método de pago.',
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
       decoration:InputDecoration(
         labelText:bookingMode=='PUESTOS'?'Precio por puesto (COP)':'Precio por mesa (COP)',
         prefixIcon:const Icon(Icons.attach_money),
         helperText:bookingMode=='PUESTOS'
          ?'Total = precio × cantidad de puestos'
          :'La reserva ocupa la mesa y se cobra una sola vez')),
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
       EventMetric(icon:Icons.payments_outlined,
          label:bookingMode=='PUESTOS'?'Precio por puesto':'Precio por mesa',
         value:method=='GRATIS'?'Gratis':
           NumberFormat.currency(locale:'es_CO',symbol:'COP ',decimalDigits:0).format(unit)),
       const Divider(color:EventColors.border,height:28),
       EventMetric(icon:Icons.restaurant_menu_outlined,
        label:'Productos destacados',value:selectedProducts.length.toString()),
       const Divider(color:EventColors.border,height:28),
       const EventMetric(icon:Icons.public_outlined,label:'Página pública',
         value:'Lista al publicar',color:EventColors.success),
       const SizedBox(height:17),
       const Text('Los asistentes verán el afiche, el lugar y las mesas reales. Podrán elegir puestos y compartir el evento.',
         style:TextStyle(color:EventColors.muted,fontSize:12,height:1.5)),
     ]));
 }

 bool get editingNonDraft=>
   widget.initial!=null&&(widget.initial?['even_estado']?.toString()??'BORRADOR')!='BORRADOR';
 String get eventStatus=>widget.initial?['even_estado']?.toString()??'BORRADOR';

 /// Botones responsivos: un evento publicado o cancelado se guarda sin cambiar su estado.
 Widget _editorFooter(){
   final cancel=OutlinedButton(
     onPressed:busy?null:()=>Navigator.pop(context),
     style:OutlinedButton.styleFrom(
       foregroundColor:EventColors.text,
       side:const BorderSide(color:EventColors.border),
       padding:const EdgeInsets.symmetric(horizontal:20,vertical:17),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
     child:const Text('Cancelar'),
   );
   final draft=OutlinedButton.icon(
     onPressed:busy?null:(){
       setState(()=>publish=false);
       _save();
     },
     style:OutlinedButton.styleFrom(
       foregroundColor:EventColors.primary,
       side:const BorderSide(color:EventColors.primary),
       padding:const EdgeInsets.symmetric(horizontal:20,vertical:17),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
     icon:const Icon(Icons.save_outlined,size:18),
     label:Text(busy?'Guardando...':'Guardar borrador'),
   );
   final primary=FilledButton.icon(
     onPressed:busy?null:(){
       setState(()=>publish=!editingNonDraft);
       _save();
     },
     style:FilledButton.styleFrom(
       backgroundColor:EventColors.primary,
       foregroundColor:EventColors.onPrimary,
       padding:const EdgeInsets.symmetric(horizontal:23,vertical:17),
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
     icon:Icon(editingNonDraft?Icons.save_outlined:Icons.send_outlined,size:18),
     label:Text(busy?'Guardando...':editingNonDraft?'Guardar cambios':'Publicar evento'),
   );
   return Container(
     width:double.infinity,
     padding:const EdgeInsets.symmetric(horizontal:21,vertical:15),
     decoration:const BoxDecoration(
       color:Color(0xFF082532),
       border:Border(top:BorderSide(color:EventColors.border))),
     child:LayoutBuilder(builder:(context,available){
       if(available.maxWidth<500){
         return Column(mainAxisSize:MainAxisSize.min,children:[
           SizedBox(width:double.infinity,child:primary),
           if(!editingNonDraft)...[
             const SizedBox(height:9),
             SizedBox(width:double.infinity,child:draft),
           ],
           const SizedBox(height:9),
           SizedBox(width:double.infinity,child:cancel),
         ]);
       }
       if(available.maxWidth<780&&!editingNonDraft){
         return Column(mainAxisSize:MainAxisSize.min,children:[
           SizedBox(width:double.infinity,child:primary),
           const SizedBox(height:9),
           Row(children:[
             Expanded(child:cancel),
             const SizedBox(width:10),
             Expanded(child:draft),
           ]),
         ]);
       }
       return Row(children:[
         cancel,
         const Spacer(),
         if(!editingNonDraft)...[draft,const SizedBox(width:12)],
         primary,
       ]);
     }),
   );
 }
 @override Widget build(BuildContext context){
   final current=ref.watch(branchScopeProvider);
   final branches=current.branches.where((b)=>b.sucuId==current.activeBranchId).toList();
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
               Text(editingNonDraft
                 ?'Puedes modificar el evento sin cambiar su estado ni afectar reservas.'
                 :'Crea una experiencia única y recibe reservas en línea desde tu página pública.',
                 maxLines:2,style:TextStyle(color:EventColors.muted,fontSize:12)),
             ])),
             if(wide)EventPill(
               icon:eventStatus=='CANCELADO'?Icons.cancel_outlined:
                eventStatus=='PUBLICADO'?Icons.public_outlined:Icons.edit_note_outlined,
               label:widget.initial==null?'Nuevo evento':
                eventStatus=='CANCELADO'?'Cancelado · se conserva':
                eventStatus=='PUBLICADO'?'Publicado · se conserva':'Borrador',
               color:eventStatus=='CANCELADO'?EventColors.warning:
                eventStatus=='PUBLICADO'?EventColors.success:EventColors.primary),
             const SizedBox(width:7),
             IconButton(onPressed:busy?null:()=>Navigator.pop(context),
               icon:const Icon(Icons.close,color:EventColors.text)),
           ])),
         Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Expanded(child:ListView(padding:const EdgeInsets.all(13),children:[
             LayoutBuilder(builder:(context,inner)=>
               _general(branches,inner.maxWidth)),
             const SizedBox(height:12),_dates(),
             const SizedBox(height:12),_bookingPreferences(),
             const SizedBox(height:12),_visualTheme(),
             const SizedBox(height:12),_tables(),
             const SizedBox(height:12),_products(),
             const SizedBox(height:12),_payments(),
             if(!wide)...[const SizedBox(height:12),_summary()],
             const SizedBox(height:22),
           ])),
           if(wide)SizedBox(width:303,child:Padding(
             padding:const EdgeInsets.fromLTRB(0,13,13,13),
             child:SingleChildScrollView(child:_summary()))),
         ])),
         _editorFooter(),
       ]);
     })),
   );
 }
}
