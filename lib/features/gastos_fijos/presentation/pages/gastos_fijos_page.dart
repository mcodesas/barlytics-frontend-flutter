import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

class GastosFijosPage extends ConsumerStatefulWidget {
  const GastosFijosPage({super.key});
  @override ConsumerState<GastosFijosPage> createState()=>_GastosFijosPageState();
}

class _GastosFijosPageState extends ConsumerState<GastosFijosPage>{
  List<Map<String,dynamic>> items=[]; bool loading=true; String filter='TODOS';
  final search=TextEditingController();
  final money=NumberFormat.currency(locale:'es_CO',symbol:r'$',decimalDigits:0);
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_load());}
  @override void dispose(){search.dispose();super.dispose();}
  Future<void> _load()async{
    final id=ref.read(branchScopeProvider).activeBranchId;
    if(id==null){if(mounted)setState(()=>loading=false);return;}
    setState(()=>loading=true);
    final r=await ref.read(apiClientProvider).get<List<dynamic>>('/api/v1/gastos-fijos/sucursal/$id',(j)=>(j as List?)??const[]);
    if(!mounted)return;
    setState(()=>items=(r.data??const[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList());
    setState(()=>loading=false);
  }
  Future<void> _edit([Map<String,dynamic>? current])async{
    final branch=ref.read(branchScopeProvider).activeBranchId;if(branch==null)return;
    final name=TextEditingController(text:current?['gafiNombre']?.toString()??'');
    final value=TextEditingController(text:current?['gafiValor']?.toString()??'');
    final note=TextEditingController(text:current?['gafiObservacion']?.toString()??'');
    String category=current?['gafiCategoria']?.toString()??'Otros',type=current?['gafiTipo']?.toString()??'FIJO',period=current?['gafiPeriodicidad']?.toString()??'MENSUAL';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:Text(current==null?'Nuevo gasto':'Editar gasto'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre del gasto',prefixIcon:Icon(Icons.edit_note_outlined))),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Categoría'),items:const['Arriendo','Servicios','Mano de obra','Internet','Seguridad','Contabilidad','Mantenimiento','Licencias','Otros'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setD(()=>category=v);}),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Tipo'),items:const[DropdownMenuItem(value:'FIJO',child:Text('Fijo · mismo valor')),DropdownMenuItem(value:'VARIABLE',child:Text('Variable · según configuración'))],onChanged:(v){if(v!=null)setD(()=>type=v);}),
        const SizedBox(height:12),
        TextField(controller:value,enabled:type=='FIJO',keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:type=='FIJO'?'Valor':'Valor base',prefixIcon:const Icon(Icons.payments_outlined))),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:period,decoration:const InputDecoration(labelText:'Periodicidad'),items:const{'DIARIO':'Diario','SEMANAL':'Semanal','QUINCENAL':'Quincenal','MENSUAL':'Mensual','ANUAL':'Anual'}.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){if(v!=null)setD(()=>period=v);}),
        const SizedBox(height:12),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Observación')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Guardar'))],
    )));
    name.dispose();value.dispose();note.dispose();if(ok!=true)return;
    final raw=value.text.replaceAll('.','').replaceAll(',','.');
    final body={'sucuId':branch,'gafiNombre':name.text.trim(),'gafiCategoria':category,'gafiValor':double.tryParse(raw)??0,'gafiPeriodicidad':period,'gafiFechaInicio':DateTime.now().toIso8601String().substring(0,10),'gafiEstado':1,'gafiTipo':type,'gafiObservacion':note.text.trim()};
    final api=ref.read(apiClientProvider);
    if(current==null){await api.post<Object?>('/api/v1/gastos-fijos',body,(j)=>j);}else{await api.put<Object?>('/api/v1/gastos-fijos/'+current['gafiId'].toString(),body,(j)=>j);}
    await _load();
  }
  Future<void> _labor()async{
    Map<String,dynamic>? expense;
    for(final e in items){if(e['gafiCategoria']=='Mano de obra'){expense=e;break;}}
    if(expense==null){await _edit();await _load();for(final e in items){if(e['gafiCategoria']=='Mano de obra'){expense=e;break;}}}
    if(expense==null||!mounted)return;
    await showDialog(context:context,builder:(_)=>_LaborDialog(gasto:expense!,palette:ref.read(selectedAppPaletteProvider),api:ref.read(apiClientProvider)));
    await _load();
  }
  @override Widget build(BuildContext context){
    final palette=ref.watch(selectedAppPaletteProvider),q=search.text.trim().toLowerCase();
    final visible=items.where((e){final t=e['gafiTipo']?.toString()??'FIJO';if(filter=='FIJOS'&&t!='FIJO')return false;if(filter=='VARIABLES'&&t!='VARIABLE')return false;if(filter=='MANO_OBRA'&&e['gafiCategoria']!='Mano de obra')return false;return q.isEmpty||((e['gafiNombre']??'').toString()+' '+(e['gafiCategoria']??'').toString()).toLowerCase().contains(q);}).toList();
    double total(String t)=>items.where((e)=>(e['gafiTipo']??'FIJO')==t).fold(0.0,(s,e)=>s+((e['gafiValor']as num?)?.toDouble()??0));
    final fixed=total('FIJO'),variable=total('VARIABLE'),labor=items.where((e)=>e['gafiCategoria']=='Mano de obra').length;
    return Scaffold(backgroundColor:Colors.transparent,body:TechBackground(padding:EdgeInsets.zero,child:RefreshIndicator(onRefresh:_load,color:palette.secondary,child:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:_wrap(_Header(palette:palette,onAdd:()=>_edit(),onLabor:_labor))),
      SliverToBoxAdapter(child:_wrap(_Summary(palette:palette,fixed:fixed,variable:variable,labor:labor,money:money))),
      SliverToBoxAdapter(child:_wrap(_Toolbar(palette:palette,search:search,filter:filter,onSearch:(_)=>setState((){}),onFilter:(v)=>setState(()=>filter=v)))),
      if(loading)const SliverFillRemaining(hasScrollBody:false,child:Center(child:AppLoader()))
      else if(visible.isEmpty)SliverFillRemaining(hasScrollBody:false,child:Center(child:Text('No hay gastos para este filtro.')))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(16,12,16,100),sliver:SliverList.builder(itemCount:visible.length,itemBuilder:(_,i){final e=visible[i],laborRow=e['gafiCategoria']=='Mano de obra';return Padding(padding:const EdgeInsets.only(bottom:10),child:_wrap(_Expense(e,palette,money,()=>_edit(e),laborRow?_labor:null)));}))
    ]))));
  }
  Widget _wrap(Widget w)=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1120),child:Padding(padding:const EdgeInsets.fromLTRB(16,16,16,0),child:w)));
}

class _Header extends StatelessWidget{final AppPalette palette;final VoidCallback onAdd,onLabor;const _Header({required this.palette,required this.onAdd,required this.onLabor});
@override Widget build(BuildContext c)=>Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Gastos fijos',style:TextStyle(color:palette.textPrimary,fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text('Administra gastos fijos, variables y mano de obra.',style:TextStyle(color:palette.textSecondary,fontWeight:FontWeight.w600))])),OutlinedButton.icon(onPressed:onLabor,icon:const Icon(Icons.groups_2_outlined),label:const Text('Mano de obra')),const SizedBox(width:8),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Nuevo gasto'))]);}

class _Summary extends StatelessWidget{final AppPalette palette;final double fixed,variable;final int labor;final NumberFormat money;const _Summary({required this.palette,required this.fixed,required this.variable,required this.labor,required this.money});
@override Widget build(BuildContext c)=>LayoutBuilder(builder:(_,b){final data=[['Fijos',money.format(fixed),Icons.lock_outline],['Variables',money.format(variable),Icons.tune],['Mano de obra','$labor cargos',Icons.groups_2_outlined]];return Row(children:data.map((x)=>Expanded(child:Padding(padding:const EdgeInsets.only(right:10),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:palette.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:palette.border.withOpacity(.7))),child:Row(children:[Icon(x[2]as IconData,color:palette.secondary),const SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x[0]as String,style:TextStyle(color:palette.textSecondary,fontSize:12,fontWeight:FontWeight.w700)),Text(x[1]as String,style:TextStyle(color:palette.textPrimary,fontSize:17,fontWeight:FontWeight.w900))])])))).toList());});}

class _Toolbar extends StatelessWidget{final AppPalette palette;final TextEditingController search;final String filter;final ValueChanged<String> onSearch,onFilter;const _Toolbar({required this.palette,required this.search,required this.filter,required this.onSearch,required this.onFilter});
@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:palette.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:palette.border.withOpacity(.7))),child:Row(children:[Expanded(child:TextField(controller:search,onChanged:onSearch,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar gasto o categoría',border:InputBorder.none))),DropdownButtonHideUnderline(child:DropdownButton<String>(value:filter,onChanged:(v){if(v!=null)onFilter(v);},items:const[DropdownMenuItem(value:'TODOS',child:Text('Todos')),DropdownMenuItem(value:'FIJOS',child:Text('Fijos')),DropdownMenuItem(value:'VARIABLES',child:Text('Variables')),DropdownMenuItem(value:'MANO_OBRA',child:Text('Mano de obra'))]))]));}

class _Expense extends StatelessWidget{final Map<String,dynamic> e;final AppPalette p;final NumberFormat money;final VoidCallback edit;final VoidCallback? labor;const _Expense(this.e,this.p,this.money,this.edit,this.labor);
@override Widget build(BuildContext c){final variable=e['gafiTipo']=='VARIABLE',value=(e['gafiValor']as num?)?.toDouble()??0;return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:p.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:p.border.withOpacity(.7))),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:p.secondary.withOpacity(.1),borderRadius:BorderRadius.circular(14)),child:Icon(labor!=null?Icons.groups_2_outlined:Icons.receipt_long_outlined,color:p.secondary)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e['gafiNombre']?.toString()??'Gasto',style:TextStyle(color:p.textPrimary,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text((e['gafiCategoria']??'Otros').toString()+' · '+(e['gafiPeriodicidad']??'MENSUAL').toString(),style:TextStyle(color:p.textSecondary,fontWeight:FontWeight.w600))])),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:p.secondary.withOpacity(.1),borderRadius:BorderRadius.circular(20)),child:Text(variable?'Variable':'Fijo',style:TextStyle(color:p.secondary,fontWeight:FontWeight.w800))),const SizedBox(width:12),Text(labor!=null?'Por cargo':money.format(value),style:TextStyle(color:p.textPrimary,fontWeight:FontWeight.w900)),IconButton(onPressed:edit,icon:const Icon(Icons.edit_outlined)),if(labor!=null)IconButton(onPressed:labor,icon:const Icon(Icons.tune_outlined))]));}}

class _LaborDialog extends StatefulWidget{final Map<String,dynamic> gasto;final AppPalette palette;final dynamic api;const _LaborDialog({required this.gasto,required this.palette,required this.api});@override State<_LaborDialog> createState()=>_LaborDialogState();}
class _LaborDialogState extends State<_LaborDialog>{
 List<Map<String,dynamic>> cargos=[];Map<String,List<Map<String,dynamic>>> rates={};Map<String,dynamic>? selected;bool loading=true;final role=TextEditingController();final value=TextEditingController();Set<int> days={1,2,3,4,5};DateTime effective=DateTime.now();
 @override void initState(){super.initState();_load();}@override void dispose(){role.dispose();value.dispose();super.dispose();}
 Future<void> _load()async{final id=widget.gasto['gafiId'];final r=await widget.api.get<List<dynamic>>('/api/v1/gastos-fijos/'+id.toString()+'/cargos',(j)=>(j as List?)??const[]);cargos=(r.data??const[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();rates={};for(final c in cargos){final rid=c['gafcId'];final rr=await widget.api.get<List<dynamic>>('/api/v1/gastos-fijos/cargos/'+rid.toString()+'/tarifas',(j)=>(j as List?)??const[]);rates[rid.toString()]=(rr.data??const[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}selected=cargos.isNotEmpty?cargos.first:null;if(mounted)setState(()=>loading=false);}
 Future<void> _addRole()async{final n=role.text.trim();if(n.isEmpty)return;await widget.api.post<Object?>('/api/v1/gastos-fijos/'+widget.gasto['gafiId'].toString()+'/cargos',{'gafcNombre':n,'gafcEstado':1},(j)=>j);role.clear();setState(()=>loading=true);await _load();}
 Future<void> _saveRate()async{if(selected==null||days.isEmpty)return;final amount=double.tryParse(value.text.replaceAll('.','').replaceAll(',','.'));if(amount==null||amount<0)return;final rid=selected!['gafcId'];await widget.api.post<Object?>('/api/v1/gastos-fijos/cargos/'+rid.toString()+'/tarifas',{'diasSemana':days.toList()..sort(),'valor':amount,'vigenciaDesde':DateFormat('yyyy-MM-dd').format(effective)},(j)=>j);value.clear();setState(()=>loading=true);await _load();}
 void preset(List<int> d)=>setState(()=>days={...d});
 @override Widget build(BuildContext c)=>AlertDialog(title:Row(children:[Expanded(child:Text('Mano de obra · '+(widget.gasto['gafiNombre']??'').toString())),IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))]),content:SizedBox(width:900,height:610,child:loading?const Center(child:AppLoader()):Column(children:[
 Row(children:[Expanded(child:Text('Configura cada cargo y sus valores por día.',style:TextStyle(color:widget.palette.textSecondary,fontWeight:FontWeight.w600))),const SizedBox(width:12),SizedBox(width:260,child:TextField(controller:role,decoration:InputDecoration(labelText:'Nuevo cargo',suffixIcon:IconButton(onPressed:_addRole,icon:const Icon(Icons.add_circle_outline)))))]),const SizedBox(height:14),
 Expanded(child:Row(children:[SizedBox(width:250,child:ListView(children:cargos.map((c){final active=selected?['gafcId']==c['gafcId'];return Card(color:active?widget.palette.secondary.withOpacity(.1):null,child:ListTile(onTap:()=>setState(()=>selected=c),leading:const Icon(Icons.person_outline),title:Text(c['gafcNombre']??''),trailing:const Icon(Icons.chevron_right)));}).toList())),const VerticalDivider(width:24),
 Expanded(child:selected==null?const Center(child:Text('Agrega el primer cargo.')):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('Configuración semanal · '+(selected!['gafcNombre']??'').toString(),style:TextStyle(color:widget.palette.textPrimary,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Usa grupos rápidos o selecciona días individuales.',style:TextStyle(color:widget.palette.textSecondary)),const SizedBox(height:12),
 Wrap(spacing:8,children:[ChoiceChip(label:const Text('Lunes - Viernes'),selected:days.length==5&&days.every((x)=>x<=5),onSelected:(_)=>preset([1,2,3,4,5])),ChoiceChip(label:const Text('Sábado - Domingo'),selected:days.length==2&&days.contains(6)&&days.contains(7),onSelected:(_)=>preset([6,7])),ChoiceChip(label:const Text('Todos'),selected:days.length==7,onSelected:(_)=>preset([1,2,3,4,5,6,7]))]),const SizedBox(height:10),
 Wrap(spacing:6,children:List.generate(7,(i){final d=i+1;return FilterChip(label:Text(['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'][i]),selected:days.contains(d),onSelected:(v)=>setState(()=>v?days.add(d):days.remove(d)));})),const SizedBox(height:12),
 Row(children:[Expanded(child:TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor para los días seleccionados',prefixIcon:Icon(Icons.payments_outlined)))),const SizedBox(width:10),FilledButton.icon(onPressed:_saveRate,icon:const Icon(Icons.save_outlined),label:const Text('Aplicar'))]),const SizedBox(height:16),
 Expanded(child:_RatesList(rates:rates[selected!['gafcId'].toString()]??const[],palette:widget.palette,money:NumberFormat.currency(locale:'es_CO',symbol:r'$',decimalDigits:0)))
 ]))]))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cerrar'))]);
}
}
class _RatesList extends StatelessWidget{final List<Map<String,dynamic>> rates;final AppPalette palette;final NumberFormat money;const _RatesList({required this.rates,required this.palette,required this.money});
@override Widget build(BuildContext c){const names=['','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];return ListView.separated(itemCount:rates.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(_,i){final r=rates[i],d=(r['gafdDiaSemana']as num?)?.toInt()??0,v=(r['gafdValor']as num?)?.toDouble()??0;return Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),decoration:BoxDecoration(color:palette.background.withOpacity(.35),borderRadius:BorderRadius.circular(12)),child:Row(children:[Expanded(child:Text(names[d],style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.w700))),Text(money.format(v),style:TextStyle(color:palette.textPrimary,fontWeight:FontWeight.w900)),const SizedBox(width:12),Text(r['gafdVigenciaDesde']?.toString()??'',style:TextStyle(color:palette.textSecondary,fontSize:11))]));});}}
