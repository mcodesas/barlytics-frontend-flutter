import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../data/eventos_api.dart';

const sea=Color(0xff009da9);
String dateLabel(DateTime d)=>DateFormat('dd/MM/yyyy').format(d);
String hourLabel(DateTime d)=>DateFormat('hh:mm a').format(d);
int? asId(Object? val)=>val is num?val.toInt():int.tryParse(val?.toString()??'');

class EventosAdminPage extends ConsumerStatefulWidget {
 const EventosAdminPage({super.key});
 @override ConsumerState<EventosAdminPage> createState()=>_EventosAdminState();
}
class _EventosAdminState extends ConsumerState<EventosAdminPage>{
 List<Map<String,dynamic>> entries=[];bool loading=true;String? error;
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  try{final rows=await ref.read(eventosApiProvider).eventos();
    if(mounted)setState((){entries=rows;loading=false;error=null;});
  }catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
 }
 Future<void> editor([Map<String,dynamic>? event])async{
  await showDialog<void>(context:context,builder:(_)=>Dialog(
   insetPadding:const EdgeInsets.symmetric(horizontal:14,vertical:20),
   child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:850),
    child:EventoEditor(initial:event,onSaved:(){Navigator.of(context).pop();load();}))));
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
      }catch(e){if(dialog.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
     },child:const Text('Guardar configuración')),
    ]));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
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
            }catch(e){if(dialog.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
           },icon:const Icon(Icons.check),label:const Text('Aprobar')):null,
         ));
        }),
      ])),
      Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cerrar')))
     ])))));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 Future<void> publish(int id)async{
  try{await ref.read(eventosApiProvider).publicar(id);await load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 Future<void> cancel(int id)async{
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Cancelar evento'),content:const Text('No se permite cancelar eventos con reservas confirmadas sin gestionar primero las devoluciones.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Volver')),
    TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cancelar evento'))]));
  if(confirmed!=true)return;
  try{await ref.read(eventosApiProvider).cancelar(id);await load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 @override Widget build(BuildContext context){
  return Scaffold(backgroundColor:Colors.transparent,body:RefreshIndicator(onRefresh:load,
   child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1180),
    child:ListView(padding:const EdgeInsets.all(22),children:[
     Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:15,runSpacing:12,children:[
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text('Eventos y reservas',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
       const Text('Publica experiencias, comparte enlaces y gestiona las mesas de cada evento.'),
      ]),
      Wrap(spacing:8,children:[
       OutlinedButton.icon(onPressed:paymentConfig,icon:const Icon(Icons.account_balance),label:const Text('Cobros electrónicos')),
       FilledButton.icon(onPressed:()=>editor(),icon:const Icon(Icons.add),label:const Text('Crear evento')),
      ])
     ]),
     const SizedBox(height:18),
     if(error!=null)Card(child:ListTile(title:Text(error!),trailing:TextButton(onPressed:load,child:const Text('Reintentar')))),
     if(loading)const Center(child:CircularProgressIndicator()),
     if(!loading&&entries.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(35),child:Center(child:Text('Aún no tienes eventos. ¡Crea el primero!')))),
     for(final item in entries)
      Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(15),child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(spacing:9,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[
         Text(item['even_titulo']?.toString()??'',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
         Chip(label:Text(item['even_estado']?.toString()??'')),
         Text(item['even_medio_pago']?.toString()??''),
        ]),
        const SizedBox(height:6),
        Text('Inicio: '+(item['even_inicio']?.toString()??'')+'   ·   Finaliza: '+(item['even_fin']?.toString()??'')),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:7,children:[
         OutlinedButton.icon(onPressed:()=>detail(asId(item['even_id'])!),icon:const Icon(Icons.people_outline),label:const Text('Reservas')),
         if(item['even_estado']=='BORRADOR')...[
          OutlinedButton.icon(onPressed:()async{
           try{final e=await ref.read(eventosApiProvider).detalle(asId(item['even_id'])!);if(mounted)editor(e);}
           catch(err){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err.toString())));}
          },icon:const Icon(Icons.edit),label:const Text('Editar')),
          FilledButton.tonalIcon(onPressed:()=>publish(asId(item['even_id'])!),icon:const Icon(Icons.public),label:const Text('Publicar')),
         ],
         if(item['even_estado']=='PUBLICADO')...[
          OutlinedButton.icon(onPressed:(){
           Clipboard.setData(ClipboardData(text:ref.read(eventosApiProvider).link(item['even_slug'].toString())));
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enlace público copiado')));
          },icon:const Icon(Icons.copy),label:const Text('Copiar enlace')),
          OutlinedButton.icon(onPressed:()=>context.go('/evento/'+item['even_slug'].toString()),
           icon:const Icon(Icons.visibility),label:const Text('Ver página pública')),
          TextButton.icon(onPressed:()=>cancel(asId(item['even_id'])!),icon:const Icon(Icons.cancel_outlined),label:const Text('Cancelar')),
         ],
        ]),
       ]))),
    ])))));
 }
}

class EventoEditor extends ConsumerStatefulWidget{
 const EventoEditor({super.key,required this.onSaved,this.initial});
 final Map<String,dynamic>? initial;
 final VoidCallback onSaved;
 @override ConsumerState<EventoEditor> createState()=>_EventEditorState();
}
class _EventEditorState extends ConsumerState<EventoEditor>{
 final form=GlobalKey<FormState>();
 final title=TextEditingController(),description=TextEditingController(),
       amount=TextEditingController(text:'0'),instructions=TextEditingController();
 DateTime start=DateTime.now().add(const Duration(days:1)).copyWith(hour:20,minute:0),
   finish=DateTime.now().add(const Duration(days:2)).copyWith(hour:2,minute:0);
 String method='GRATIS';String? photo;bool publish=false,busy=false;
 int? branch;Set<int> chosen={};List<Map<String,dynamic>> tables=[];
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
  }
  WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_loadTables();});
 }
 @override void dispose(){title.dispose();description.dispose();amount.dispose();instructions.dispose();super.dispose();}
 Future<void> _loadTables()async{
  final branchState=ref.read(branchScopeProvider);
  branch??=branchState.activeBranchId;
  if(branch==null)return;
  try{final t=await ref.read(eventosApiProvider).mesas(branch!);
    if(mounted)setState(()=>tables=t.where((e)=>e['mesaEstado']?.toString().toUpperCase()!='INACTIVA').toList());
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Mesas: '+e.toString())));}
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
  if(!(form.currentState?.validate()??false))return;
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
    'mesas':chosen.toList(),'publicar':publish};
   if(widget.initial==null)await ref.read(eventosApiProvider).crear(body);
   else await ref.read(eventosApiProvider).cambiar(asId(widget.initial!['even_id'])!,body);
   if(mounted)widget.onSaved();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se guardó: '+e.toString())));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){
  final branches=ref.watch(branchScopeProvider).branches;
  return Padding(padding:const EdgeInsets.all(20),child:Form(key:form,child:Column(children:[
   Row(children:[Expanded(child:Text(widget.initial==null?'Nuevo evento':'Editar borrador',
      style:Theme.of(context).textTheme.headlineSmall)),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
   Expanded(child:ListView(children:[
    const SizedBox(height:12),
    TextFormField(controller:title,maxLength:180,decoration:const InputDecoration(labelText:'Nombre del evento *',border:OutlineInputBorder()),
     validator:(v)=>(v?.trim().isEmpty??true)?'Ingresa un título':null),
    const SizedBox(height:8),
    TextFormField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Descripción / artistas / recomendaciones',border:OutlineInputBorder())),
    const SizedBox(height:14),
    OutlinedButton.icon(onPressed:_image,icon:const Icon(Icons.upload),label:Text(photo==null?'Cargar afiche o imagen':'Cambiar imagen del evento')),
    if(photo!=null)const Text('Imagen seleccionada · JPG, PNG o WebP',style:TextStyle(color:sea)),
    const SizedBox(height:14),
    DropdownButtonFormField<int>(value:branch,decoration:const InputDecoration(labelText:'Sucursal *',border:OutlineInputBorder()),
     items:branches.where((e)=>e.sucuId!=null).map((b)=>DropdownMenuItem(value:b.sucuId,child:Text(b.sucuNombre??'Sucursal'))).toList(),
     onChanged:(v){setState((){branch=v;tables=[];chosen={};});_loadTables();}),
    const SizedBox(height:15),
    Text('Inicio del evento',style:Theme.of(context).textTheme.titleMedium),
    Wrap(spacing:10,runSpacing:8,children:[
     OutlinedButton.icon(onPressed:()=>_pick(true,true),icon:const Icon(Icons.calendar_month),label:Text('Fecha: '+dateLabel(start))),
     OutlinedButton.icon(onPressed:()=>_pick(true,false),icon:const Icon(Icons.schedule),label:Text('Hora: '+hourLabel(start))),
    ]),
    const SizedBox(height:12),
    Text('Finalización del evento',style:Theme.of(context).textTheme.titleMedium),
    Wrap(spacing:10,runSpacing:8,children:[
     OutlinedButton.icon(onPressed:()=>_pick(false,true),icon:const Icon(Icons.calendar_month),label:Text('Fecha: '+dateLabel(finish))),
     OutlinedButton.icon(onPressed:()=>_pick(false,false),icon:const Icon(Icons.schedule),label:Text('Hora: '+hourLabel(finish))),
    ]),
    const SizedBox(height:20),
    Text('Mesas habilitadas para este evento',style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:7),
    Wrap(spacing:8,runSpacing:8,children:tables.map((m){
     final id=asId(m['mesaId']);
     if(id==null)return const SizedBox.shrink();
     return FilterChip(label:Text('Mesa '+(m['mesaNumero']?.toString()??id.toString())),
      selected:chosen.contains(id),onSelected:(v)=>setState((){if(v)chosen.add(id);else chosen.remove(id);}));
    }).toList()),
    if(tables.isEmpty)const Padding(padding:EdgeInsets.all(9),child:Text('No se encontraron mesas para la sucursal seleccionada.')),
    const SizedBox(height:18),
    DropdownButtonFormField<String>(value:method,
     decoration:const InputDecoration(labelText:'Forma de reservar *',border:OutlineInputBorder()),
     items:const [
      DropdownMenuItem(value:'GRATIS',child:Text('Gratis, QR inmediato')),
      DropdownMenuItem(value:'MANUAL',child:Text('Pago manual, revisión del negocio')),
      DropdownMenuItem(value:'MERCADOPAGO',child:Text('Pago electrónico / PSE (Mercado Pago)')),
     ],onChanged:(v)=>setState((){method=v??'GRATIS';if(method=='GRATIS')amount.text='0';})),
    const SizedBox(height:13),
    TextFormField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Valor de reserva por mesa (COP)',prefixText:'\$ ',border:OutlineInputBorder())),
    if(method=='MANUAL')...[
     const SizedBox(height:13),TextFormField(controller:instructions,maxLines:3,
      decoration:const InputDecoration(labelText:'Instrucciones de pago / datos del negocio',border:OutlineInputBorder()))
    ],
    const SizedBox(height:12),
    SwitchListTile(value:publish,title:const Text('Publicar ahora'),
     subtitle:const Text('Si lo dejas desactivado, podrás editarlo como borrador.'),
     onChanged:(v)=>setState(()=>publish=v)),
   ])),
   const SizedBox(height:10),
   Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:busy?null:_save,
    icon:const Icon(Icons.save),label:Text(busy?'Guardando...':'Guardar evento'))),
  ])));
 }
}
