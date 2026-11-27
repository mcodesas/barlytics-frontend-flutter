import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/user_menu_provider.dart';
import '../data/intelligence_api.dart';
import 'intelligence_chat.dart';
import 'intelligence_export_card.dart';
import 'intelligence_alerts_card.dart';
import 'intelligence_forecast_card.dart';
import 'intelligence_memory_card.dart';
import 'intelligence_catalog_sync_card.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';

final _workspaceCatalog=FutureProvider.autoDispose.family<Map<String,dynamic>,int>((ref,branch) async {
  return ref.watch(intelligenceApiProvider).workspaceCatalog(branch);
});

class IntelligenceWorkspacePage extends ConsumerWidget {
  const IntelligenceWorkspacePage({super.key});
  @override
  Widget build(BuildContext context,WidgetRef ref){
    final menu=ref.watch(userMenuProvider);
    final branch=ref.watch(branchScopeProvider).activeBranchId;
    return menu.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(_,__)=>const Center(child:Text('No fue posible comprobar tus permisos.')),
      data:(items){
        if(!items.any((item)=>item.keyName=='intelligence')){
          return const Center(child:Text('No tienes permiso para acceder a Intelligence.'));
        }
        if(branch==null)return const Center(child:Text('Selecciona una sucursal.'));
        return _Workspace(key:ValueKey(branch),branch:branch);
      });
  }
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({super.key,required this.branch});
  final int branch;
  @override
  ConsumerState<_Workspace> createState()=>_WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace>{
  String? _resource,_field,_filterField;
  String _operation='list',_operator='eq';
  final _filter=TextEditingController();
  final _search=TextEditingController();
  bool _busy=false;
  String? _answer;
  Map<String,dynamic>? _exportPlan;
  int _generation=0;
  @override
  void dispose(){_filter.dispose();_search.dispose();super.dispose();}
  List<String> _strings(dynamic x)=>x is List?x.whereType<String>().toList():<String>[];
  Future<void> _query() async {
    final resource=_resource;
    if(resource==null||_busy)return;
    if(_operation!='list'&&_operation!='count'&&_field==null)return;
    final generation=++_generation;
    setState((){_busy=true;_answer=null;_exportPlan=null;});
    try{
      final plan=<String,dynamic>{'resource':resource,'operation':_operation,'limit':30,
        if(_operation!='list'&&_operation!='count')'field':_field,
        if(_filterField!=null&&_filter.text.trim().isNotEmpty)
          'filters':[{'field':_filterField,'operator':_operator,'value':_filter.text.trim()}]};
      final result=await ref.read(intelligenceApiProvider).workspaceQuery(widget.branch,plan);
      if(mounted&&generation==_generation&&ref.read(branchScopeProvider).activeBranchId==widget.branch)setState((){_answer=result['answer']?.toString()??'Sin respuesta.';_exportPlan={'format':'table','query':Map<String,dynamic>.from(plan)..remove('limit')};});
    }catch(_){if(mounted&&generation==_generation)setState(()=>_answer='No se pudo realizar la consulta. Verifica tus permisos y filtros.');}
    finally{if(mounted&&generation==_generation)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next){_generation++;setState((){_resource=null;_field=null;_filterField=null;_operation='list';_answer=null;_exportPlan=null;_exportPlan=null;_busy=false;});}});
    final data=ref.watch(_workspaceCatalog(widget.branch));
    return data.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(_,__)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('No fue posible cargar los recursos autorizados.'),
        TextButton(onPressed:()=>ref.invalidate(_workspaceCatalog(widget.branch)),child:const Text('Reintentar'))])),
      data:(value){
        final resources=(value['resources'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
        final selected=resources.where((r)=>r['name']==_resource).firstOrNull;
        final columns=_strings(selected?['columns']);
        final numeric=_strings(selected?['numeric']);
        final search=_search.text.toLowerCase().trim();
        final shown=resources.where((r)=>r['name']==_resource||'${r['name']} ${r['description']}'.toLowerCase().contains(search)).toList();
        return ListView(padding:const EdgeInsets.all(16),children:[
          Row(children:[
            Icon(Icons.auto_awesome,color:Theme.of(context).colorScheme.primary,size:32),
            const SizedBox(width:12),Expanded(child:Text('Intelligence',style:Theme.of(context).textTheme.headlineSmall)),
            IconButton(tooltip:'Actualizar catálogo',onPressed:_busy?null:(){setState((){_resource=null;_field=null;_filterField=null;_answer=null;_exportPlan=null;_operation='list';});ref.invalidate(_workspaceCatalog(widget.branch));},icon:const Icon(Icons.refresh)),
          ]),
          const SizedBox(height:8),
          const Text('Consulta los datos de tu negocio, según los permisos de tu usuario y la sucursal seleccionada.'),
          const SizedBox(height:12),
          Align(alignment:Alignment.centerLeft,child:Builder(builder:(anchorContext)=>FilledButton.icon(onPressed:()=>showIntelligenceChat(anchorContext),icon:const Icon(Icons.chat_bubble_outline),label:const Text('Abrir asistente Intelligence')))),
          const SizedBox(height:16),
          IntelligenceAlertsCard(key:ValueKey('alerts-${widget.branch}'),branch:widget.branch,initiallyExpanded:true),
          const SizedBox(height:16),
          IntelligenceForecastCard(key:ValueKey('forecast-${widget.branch}'),branch:widget.branch),
          const SizedBox(height:16),
          IntelligenceCatalogSyncCard(key:ValueKey('catalog-sync-${widget.branch}'),branch:widget.branch),
          const SizedBox(height:16),
          IntelligenceMemoryCard(key:ValueKey('memory-${widget.branch}'),branch:widget.branch),
          const SizedBox(height:16),
          Text('${resources.length} recursos autorizados',style:Theme.of(context).textTheme.titleMedium),
          if(value['schemaTableCount']!=null)Text('Tablas físicas autorizadas y disponibles: ${value['authorizedPhysicalTables']} / ${value['schemaTableCount']} descubiertas. La diferencia incluye recursos sin permiso o sin política validada.'),
          if(resources.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('No tienes recursos de consulta disponibles.')),
          if(resources.isNotEmpty)...[
            const SizedBox(height:12),
            TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Buscar tabla o recurso',prefixIcon:Icon(Icons.search))),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              isExpanded:true,value:selected?['name'] as String?,
              decoration:const InputDecoration(labelText:'Recurso autorizado'),
              items:[for(final r in shown)DropdownMenuItem(value:r['name'] as String,child:Text('${r['name']} — ${r['description']}',overflow:TextOverflow.ellipsis))],
              onChanged:_busy?null:(v)=>setState((){_resource=v;_field=null;_filterField=null;_operation='list';_answer=null;_exportPlan=null;}),
            ),
            if(selected!=null)...[
              const SizedBox(height:8),
              Text('Campos disponibles: ${columns.join(', ')}'),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(value:_operation,decoration:const InputDecoration(labelText:'Operación'),
                items:[for(final op in ['list','count',if(numeric.isNotEmpty)...['sum','avg','min','max']])DropdownMenuItem(value:op,child:Text(const {'list':'Listar registros','count':'Contar','sum':'Sumar','avg':'Promedio','min':'Mínimo','max':'Máximo'}[op]!))],
                onChanged:_busy?null:(v)=>setState((){_operation=v!;_field=null;_answer=null;_exportPlan=null;})),
              if(_operation!='list'&&_operation!='count')DropdownButtonFormField<String>(value:_field,decoration:const InputDecoration(labelText:'Campo numérico'),items:[for(final f in numeric)DropdownMenuItem(value:f,child:Text(f))],onChanged:_busy?null:(v)=>setState(()=>_field=v)),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(value:_filterField,decoration:const InputDecoration(labelText:'Campo para filtrar (opcional)'),items:[const DropdownMenuItem<String>(value:null,child:Text('Sin filtro')),for(final f in columns)DropdownMenuItem(value:f,child:Text(f))],onChanged:_busy?null:(v)=>setState(()=>_filterField=v)),
              if(_filterField!=null)...[
                DropdownButtonFormField<String>(value:_operator,decoration:const InputDecoration(labelText:'Comparación'),items:[for(final op in ['eq','ne','contains'])DropdownMenuItem(value:op,child:Text(const {'eq':'Igual','ne':'Diferente','contains':'Contiene'}[op]!))],onChanged:_busy?null:(v)=>setState(()=>_operator=v!)),
                TextField(controller:_filter,enabled:!_busy,decoration:const InputDecoration(labelText:'Valor del filtro')),
              ],
              const SizedBox(height:16),
              Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:_busy||(_operation!='list'&&_operation!='count'&&_field==null)?null:_query,icon:const Icon(Icons.search),label:const Text('Consultar'))),
              if(_busy)const LinearProgressIndicator(),
              if(_answer!=null)Card(child:Padding(padding:const EdgeInsets.all(16),child:SelectableText(_answer!))),
              if(_exportPlan!=null)IntelligenceExportCard(branch:widget.branch,plan:_exportPlan!,disabled:_busy),
            ],
          ],
        ]);
      });
  }
}
