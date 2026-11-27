import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';

class IntelligenceForecastCard extends ConsumerStatefulWidget {
  const IntelligenceForecastCard({super.key,required this.branch,this.initialPlan});
  final int branch;
  final Map<String,dynamic>? initialPlan;
  @override
  ConsumerState<IntelligenceForecastCard> createState()=>_ForecastState();
}

class _ForecastState extends ConsumerState<IntelligenceForecastCard>{
  static const names={'SALES':'Pronóstico de ventas','STOCK':'Riesgo de agotamiento','FINANCE':'Escenario de ganancias','PRICE':'Escenario de margen bruto'};
  final margin=TextEditingController(text:'30');
  List<String> available=[];
  String? kind,error;
  int horizon=7,generation=0;
  bool busy=false,loaded=false,expanded=false;
  Map<String,dynamic>? result;
  @override
  void initState(){
    super.initState();
    expanded=widget.initialPlan!=null;
    final plan=widget.initialPlan;
    if(plan!=null){
      kind=plan['kind']?.toString();
      final h=plan['horizon'];if(h is int&&h>=1&&h<=30)horizon=h;
      if(plan['margin'] is num)margin.text=plan['margin'].toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&expanded)_options();});
  }
  @override
  void dispose(){generation++;margin.dispose();super.dispose();}
  bool active(int g)=>mounted&&generation==g&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void reset(){
    generation++;
    if(mounted)setState((){available=[];kind=null;result=null;error=null;loaded=false;busy=false;});
    if(mounted&&expanded)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_options();});
  }
  Future<void> _options() async{
    if(busy||!mounted||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final g=++generation;setState((){busy=true;error=null;});
    try{
      final r=await ref.read(intelligenceApiProvider).forecastOptions(widget.branch);
      if(!active(g))return;
      setState((){
        available=(r['available'] as List).whereType<String>().where(names.containsKey).toList();
        if(!available.contains(kind))kind=available.firstOrNull;
        loaded=true;
      });
    }catch(_){if(active(g))setState(()=>error='No fue posible verificar las opciones autorizadas.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> _calculate() async{
    final selected=kind;
    if(busy||selected==null||!available.contains(selected)||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final m=num.tryParse(margin.text.replaceAll(',','.'));
    if(selected=='PRICE'&&(m==null||!m.isFinite||m<1||m>90)){setState(()=>error='El margen debe estar entre 1 y 90%.');return;}
    final g=++generation;setState((){busy=true;error=null;result=null;});
    try{
      final r=await ref.read(intelligenceApiProvider).forecast(widget.branch,{'kind':selected,'horizon':horizon,if(selected=='PRICE')'margin':m});
      if(!active(g))return;
      if(r['kind']!=selected||r['branchId']!=widget.branch||r['rows'] is! List)throw const FormatException('Resultado inválido');
      setState(()=>result=r);
    }catch(_){if(active(g))setState(()=>error='No se pudo calcular. Revisa permisos, disponibilidad e histórico suficiente.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Widget _data(Map<String,dynamic> r){
    final rows=(r['rows'] as List).whereType<Map>().toList();
    final colors=Theme.of(context).colorScheme;
    final sales=r['kind']=='SALES';
    final max=sales?rows.fold<double>(0,(v,row)=>math.max(v,(row['escenario_alto'] as num).toDouble())):0.0;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(r['kind']!='PRICE')Text('Periodo: ${r['start']} a ${r['end']}'),
      if(r['totalEstimado']!=null)Text('Total estimado: ${r['totalEstimado']}',style:Theme.of(context).textTheme.titleMedium),
      if(r['holdoutWapePercent']!=null)Text('Error retrospectivo WAPE: ${r['holdoutWapePercent']}% (menor es mejor; no garantiza precisión futura).'),
      if(r['kind']=='SALES'&&r['holdoutWapePercent']==null)const Text('Error retrospectivo no calculable por falta de ventas en la ventana de validación.'),
      if(r['partial']==true)const Text('Resultado parcial: se muestran hasta 100 productos.'),
      if(r['excludedProducts']!=null)Text('Productos sin condiciones para calcular: ${r['excludedProducts']}'),
      if(rows.isEmpty)const Text('No hay registros elegibles para este escenario.'),
      if(sales)for(final row in rows)...[
        Text('${row['fecha']} · ${row['estimado']}'),
        LinearProgressIndicator(value:max<=0?0.0:((row['estimado'] as num).toDouble()/max).clamp(0.0,1.0).toDouble(),color:colors.primary),
        Text('Escenarios: ${row['escenario_bajo']} – ${row['escenario_alto']}',style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:6),
      ] else if(rows.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        columns:[for(final k in rows.first.keys)DataColumn(label:Text(k.toString().replaceAll('_',' ')))],
        rows:[for(final row in rows)DataRow(cells:[for(final k in rows.first.keys)DataCell(Text(row[k]?.toString()??''))])],
      )),
      const SizedBox(height:8),
      Text(r['method']?.toString()??''),
      Text(r['limitations']?.toString()??'',style:Theme.of(context).textTheme.bodySmall),
      const Text('Solo análisis. No modifica inventario, precios ni pedidos.'),
    ]);
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)reset();});
    return Card(child:ExpansionTile(
      initiallyExpanded:widget.initialPlan!=null,
      leading:const Icon(Icons.query_stats),
      title:const Text('Intelligence predictivo'),
      subtitle:const Text('Pronósticos y escenarios comerciales'),
      onExpansionChanged:(open){setState(()=>expanded=open);if(open&&!loaded)_options();},
      childrenPadding:const EdgeInsets.all(12),children:[
        if(busy)const LinearProgressIndicator(),
        if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        if(!loaded&&!busy)TextButton(onPressed:_options,child:const Text('Cargar opciones')),
        if(loaded&&available.isEmpty)const Text('No tienes permisos para estos análisis.'),
        if(loaded&&available.isNotEmpty)...[
          DropdownButtonFormField<String>(value:kind,isExpanded:true,decoration:const InputDecoration(labelText:'Análisis'),
            items:[for(final k in available)DropdownMenuItem(value:k,child:Text(names[k]!))],
            onChanged:busy?null:(v)=>setState((){kind=v;result=null;error=null;})),
          if(kind!='PRICE')...[
            Text('Horizonte: $horizon días'),
            Slider(value:horizon.toDouble(),min:1,max:30,divisions:29,label:'$horizon días',onChanged:busy?null:(v)=>setState((){horizon=v.round();result=null;})),
          ]else TextField(controller:margin,enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Margen bruto objetivo (%)')),
          FilledButton.icon(onPressed:busy?null:_calculate,icon:const Icon(Icons.analytics_outlined),label:const Text('Calcular escenario')),
        ],
        if(result!=null)ConstrainedBox(constraints:const BoxConstraints(maxHeight:440),child:SingleChildScrollView(child:_data(result!))),
      ],
    ));
  }
}
