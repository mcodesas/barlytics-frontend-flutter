import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';

class IntelligenceAlertsCard extends ConsumerStatefulWidget {
  const IntelligenceAlertsCard({super.key,required this.branch,this.initiallyExpanded=false});
  final int branch;
  final bool initiallyExpanded;
  @override
  ConsumerState<IntelligenceAlertsCard> createState()=>_IntelligenceAlertsCardState();
}

class _IntelligenceAlertsCardState extends ConsumerState<IntelligenceAlertsCard> with WidgetsBindingObserver{
  static const names={'STOCK':'Stock bajo o negativo','EXPIRY':'Productos próximos a vencer','CASH':'Diferencias de caja',
    'ORDERS':'Pedidos pendientes','COUNT':'Diferencias del último conteo físico','FINANCE':'Ganancias, ingresos y gastos'};
  static const descriptions={'STOCK':'Último saldo operativo, sin mezclar conteos físicos.',
    'EXPIRY':'Productos activos con existencias y fecha de vencimiento.',
    'CASH':'Arqueos con diferencias de los últimos 30 días.',
    'ORDERS':'Pedidos confirmados que siguen pendientes de recepción.',
    'COUNT':'Diferencias históricas al contar, no pérdidas confirmadas.',
    'FINANCE':'Compara dos periodos completos de siete días.'};
  Set<String> available={},enabled={};
  List<Map<String,dynamic>> categories=[];
  final expiry=TextEditingController(text:'7'),orders=TextEditingController(text:'3'),
    cash=TextEditingController(text:'0'),decline=TextEditingController(text:'20');
  bool busy=false,editing=false,loaded=false,expanded=false,foreground=true;
  int generation=0;
  String? error;
  Timer? timer;
  @override
  void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    expanded=widget.initiallyExpanded;
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&expanded)_load(finance:true);});
    timer=Timer.periodic(const Duration(minutes:2),(_){
      if(mounted&&expanded&&foreground&&!editing&&!busy&&ModalRoute.of(context)?.isCurrent!=false)_load();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){foreground=state==AppLifecycleState.resumed;}
  @override
  void dispose(){generation++;timer?.cancel();WidgetsBinding.instance.removeObserver(this);expiry.dispose();orders.dispose();cash.dispose();decline.dispose();super.dispose();}
  bool active(int g)=>mounted&&g==generation&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void reset(){
    generation++;
    if(mounted)setState((){busy=false;editing=false;loaded=false;available={};enabled={};categories=[];error=null;});
    if(mounted&&expanded)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_load(finance:true);});
  }
  void readSettings(Map<String,dynamic> response){
    final settings=Map<String,dynamic>.from(response['settings'] as Map);
    available=(response['available'] as List).whereType<String>().where(names.containsKey).toSet();
    enabled=(settings['enabled'] as List).whereType<String>().where(available.contains).toSet();
    expiry.text=settings['expiryDays'].toString();orders.text=settings['orderDays'].toString();
    cash.text=settings['cashDifference'].toString();decline.text=settings['declinePercent'].toString();
  }
  Future<void> _load({bool finance=false}) async{
    if(busy||editing||!mounted||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final g=++generation;setState((){busy=true;error=null;});
    try{
      final result=await ref.read(intelligenceApiProvider).alerts(widget.branch,includeFinance:finance);
      if(!active(g))return;
      final next=(result['categories'] as List).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
      setState((){
        readSettings(result);
        final previousFinance=categories.where((c)=>c['rule']=='FINANCE').toList();
        categories=next;
        if(!finance&&enabled.contains('FINANCE')&&available.contains('FINANCE'))categories.addAll(previousFinance);
        loaded=true;
      });
    }catch(_){
      if(active(g)){
        setState((){categories=[];error='No se pudieron verificar las alertas. No significa que no existan incidencias.';});
        try{
          final config=await ref.read(intelligenceApiProvider).alertSettings(widget.branch);
          if(active(g))setState((){readSettings(config);loaded=true;});
        }catch(_){if(active(g))setState(()=>loaded=false);}
      }
    }
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> _save() async{
    if(busy)return;
    final exp=int.tryParse(expiry.text),ord=int.tryParse(orders.text),diff=num.tryParse(cash.text.replaceAll(',','.')),dec=num.tryParse(decline.text.replaceAll(',','.'));
    if(exp==null||exp<0||exp>30||ord==null||ord<1||ord>365||diff==null||!diff.isFinite||diff<0||diff>1000000000||dec==null||!dec.isFinite||dec<1||dec>100){
      setState(()=>error='Revisa los límites de la configuración.');return;
    }
    final g=++generation;setState((){busy=true;error=null;});
    try{
      final r=await ref.read(intelligenceApiProvider).saveAlertSettings(widget.branch,{'enabled':enabled.toList()..sort(),
        'expiryDays':exp,'orderDays':ord,'cashDifference':diff,'declinePercent':dec});
      if(!active(g))return;
      setState((){readSettings(r);editing=false;categories=[];});
    }catch(_){if(active(g))setState(()=>error='No se guardó la configuración. Comprueba los permisos y los valores.');}
    finally{if(active(g))setState(()=>busy=false);}
    if(active(g)&&!editing)await _load(finance:true);
  }
  Widget field(TextEditingController controller,String label)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(
    controller:controller,enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)reset();});
    final colors=Theme.of(context).colorScheme;
    final total=categories.fold<int>(0,(n,c)=>n+((c['findings'] as List?)?.length??0));
    return Card(child:ExpansionTile(
      initiallyExpanded:widget.initiallyExpanded,
      onExpansionChanged:(open){setState(()=>expanded=open);if(open&&!loaded)_load(finance:true);},
      leading:Icon(Icons.notifications_active_outlined,color:colors.primary),
      title:const Text('Alertas de Intelligence'),
      subtitle:Text(error!=null?'Revisión no confirmada':loaded?'$total hallazgos mostrados · Sucursal ${widget.branch}':'Monitoreo configurable por usuario'),
      childrenPadding:const EdgeInsets.all(12),children:[
        if(busy)const LinearProgressIndicator(),
        if(error!=null)Text(error!,style:TextStyle(color:colors.error)),
        if(!loaded&&!busy)TextButton(onPressed:()=>_load(finance:true),child:const Text('Cargar alertas')),
        if(loaded&&!editing) ...[
          Wrap(spacing:8,children:[
            OutlinedButton.icon(onPressed:busy?null:()=>_load(finance:true),icon:const Icon(Icons.refresh),label:const Text('Actualizar todo')),
            OutlinedButton.icon(onPressed:busy?null:()=>setState(()=>editing=true),icon:const Icon(Icons.settings_outlined),label:const Text('Configurar')),
          ]),
          if(enabled.isEmpty)const Text('Activa las reglas permitidas para empezar el monitoreo.'),
          for(final c in categories)...[
            const Divider(),
            Text(names[c['rule']]??'Alerta',style:const TextStyle(fontWeight:FontWeight.bold)),
            Text('Revisado: ${c['checkedAt']}'),
            if(c['partial']==true)const Text('Resultado parcial: hay más hallazgos disponibles en el módulo correspondiente.'),
            if((c['findings'] as List).isEmpty)const Text('Sin hallazgos para los límites configurados en esta revisión.'),
            for(final item in (c['findings'] as List).whereType<Map>())
              ListTile(dense:true,contentPadding:EdgeInsets.zero,
                leading:Icon(item['severity']=='CRITICAL'?Icons.error_outline:Icons.warning_amber_rounded,
                  color:item['severity']=='CRITICAL'?colors.error:colors.tertiary),
                title:Text(item['title'].toString()),
                subtitle:Text('Valor: ${item['value']} · Referencia: ${item['reference']}\n${item['detail']}')),
          ],
          const Text('Las alertas no cambian el inventario, la caja ni los pedidos. Las financieras se actualizan al abrir o pulsar Actualizar todo.'),
        ],
        if(editing)...[
          for(final rule in names.keys.where(available.contains))
            SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(names[rule]!),subtitle:Text(descriptions[rule]!),
              value:enabled.contains(rule),onChanged:busy?null:(v)=>setState((){if(v){enabled.add(rule);}else{enabled.remove(rule);}})),
          if(available.contains('EXPIRY'))field(expiry,'Días antes del vencimiento (0–30)'),
          if(available.contains('ORDERS'))field(orders,'Antigüedad del pedido en días (1–365)'),
          if(available.contains('CASH'))field(cash,'Diferencia absoluta mínima de caja'),
          if(available.contains('FINANCE'))field(decline,'Variación financiera mínima (%)'),
          Wrap(spacing:8,children:[
            FilledButton(onPressed:busy?null:_save,child:const Text('Guardar preferencias')),
            TextButton(onPressed:busy?null:(){setState(()=>editing=false);_load(finance:true);},child:const Text('Cancelar')),
          ]),
        ],
      ],
    ));
  }
}
