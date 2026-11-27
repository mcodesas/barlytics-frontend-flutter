import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';

class IntelligenceCatalogSyncCard extends ConsumerStatefulWidget {
  const IntelligenceCatalogSyncCard({super.key,required this.branch,this.initiallyExpanded=false});
  final int branch;
  final bool initiallyExpanded;
  @override
  ConsumerState<IntelligenceCatalogSyncCard> createState()=>_SyncState();
}
class _SyncState extends ConsumerState<IntelligenceCatalogSyncCard>{
  final search=TextEditingController();
  List<Map<String,dynamic>> branches=[],products=[];
  final selected=<int>{};
  int? target;
  String mode='COPY_MISSING';
  bool busy=false,loaded=false,available=false,partial=false;
  int generation=0;
  Map<String,dynamic>? comparison,draft;
  String? message;
  @override
  void initState(){
    super.initState();
    if(widget.initiallyExpanded)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)load();});
  }
  @override
  void dispose(){generation++;search.dispose();super.dispose();}
  bool active(int g)=>mounted&&generation==g&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void reset(){
    generation++;
    if(mounted)setState((){busy=false;loaded=false;available=false;branches=[];products=[];selected.clear();target=null;comparison=null;draft=null;message='Cambió el alcance; vuelve a cargar.';});
  }
  List<Map<String,dynamic>> maps(dynamic v)=>(v as List).whereType<Map>().map((r)=>Map<String,dynamic>.from(r)).toList();
  Map<String,dynamic> selection()=>{'targetBranchId':target,'mode':mode,'productIds':selected.toList()..sort()};
  Future<void> run(Future<void> Function(IntelligenceApi,int) work)async{
    if(busy||!mounted||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final g=++generation;setState((){busy=true;message=null;});
    try{await work(ref.read(intelligenceApiProvider),g);}
    catch(_){if(active(g))setState(()=>message='No se confirmó el resultado. Comprueba permisos y estado; no se reintentará automáticamente.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> load()=>run((api,g)async{
    if(draft!=null)return;
    final r=await api.catalogSyncOptions(widget.branch,search:search.text);
    if(!active(g))return;
    setState((){
      available=r['available']==true;loaded=true;comparison=null;selected.clear();
      branches=available?maps(r['branches']):[];products=available?maps(r['products']):[];
      partial=r['partial']==true;
      if(!branches.any((b)=>b['id']==target))target=null;
    });
  });
  Future<void> compare()=>run((api,g)async{
    if(target==null||selected.isEmpty||draft!=null)return;
    final r=await api.catalogSyncCompare(widget.branch,selection());
    if(active(g))setState(()=>comparison=r);
  });
  Future<void> prepare()=>run((api,g)async{
    if(target==null||selected.isEmpty||comparison==null||draft!=null)return;
    final r=await api.prepareAction(widget.branch,{'catalogSync':selection()});
    if(!active(g))return;
    if(r['draftId'] is! String||r['catalogSync'] is! Map)throw const FormatException('Borrador inválido');
    setState(()=>draft=r);
  });
  Future<void> resolve(bool confirm)=>run((api,g)async{
    final id=draft?['draftId'];if(id is! String)return;
    final r=confirm?await api.confirmAction(widget.branch,id):await api.cancelAction(widget.branch,id);
    if(!active(g))return;
    if(r['draftId']!=id||r['status']!=(confirm?'APPLIED':'CANCELLED'))throw const FormatException('Resultado no confirmado');
    setState((){draft=null;comparison=null;selected.clear();message=confirm?'Sincronización confirmada. Ejecución: ${r['syncRunId']??'consulta el historial oficial'}.':'Borrador cancelado.';});
  });
  Widget summary(Map data){
    final rows=maps(data['products']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Origen: ${data['sourceBranch']} · destino: ${data['targetBranchId']}'),
      Text('Crear: ${data['creates']} · actualizar: ${data['updates']} · omitir: ${data['skips']}'),
      for(final row in rows)ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(row['name'].toString()),
        subtitle:Text('Acción: ${row['action']}\nCosto origen: ${row['sourceCost']??'No registrado'} · destino: ${row['targetCost']??'No registrado'}\nPrecio venta destino: ${row['targetSale']??'No registrado'}')),
      const Text('No copia inventario, precios de venta, imágenes ni vencimiento de origen. Los productos nuevos pueden requerir precio de venta. Los conflictos y productos no elegibles se omiten.'),
    ]);
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)reset();});
    final locked=busy||draft!=null;
    return Card(child:ExpansionTile(initiallyExpanded:widget.initiallyExpanded,title:const Text('Sincronización entre sucursales'),
      leading:const Icon(Icons.sync_alt),subtitle:const Text('Comparar catálogo y costos sin cambiar inventario'),
      onExpansionChanged:(open){if(open&&!loaded&&!busy)load();},childrenPadding:const EdgeInsets.all(12),children:[
        if(busy)const LinearProgressIndicator(),
        if(message!=null)Text(message!),
        if(!loaded&&!busy)TextButton(onPressed:load,child:const Text('Cargar opciones')),
        if(loaded&&!available)const Text('No tienes permisos para sincronizar catálogos.'),
        if(available)...[
          if(branches.isEmpty)const Text('No hay otra sucursal con los permisos necesarios.'),
          DropdownButtonFormField<int>(value:target,isExpanded:true,decoration:const InputDecoration(labelText:'Sucursal destino'),
            items:[for(final b in branches)DropdownMenuItem(value:(b['id'] as num).toInt(),child:Text(b['name'].toString()))],
            onChanged:locked?null:(v)=>setState((){target=v;comparison=null;})),
          DropdownButtonFormField<String>(value:mode,isExpanded:true,decoration:const InputDecoration(labelText:'Modo'),
            items:const [DropdownMenuItem(value:'COPY_MISSING',child:Text('Copiar solo faltantes')),DropdownMenuItem(value:'SYNCHRONIZE',child:Text('Sincronizar información y costo'))],
            onChanged:locked?null:(v)=>setState((){mode=v??'COPY_MISSING';comparison=null;})),
          TextField(controller:search,maxLength:120,enabled:!locked,decoration:const InputDecoration(labelText:'Buscar productos del origen')),
          OutlinedButton(onPressed:locked?null:load,child:const Text('Buscar (reinicia selección)')),
          if(partial)const Text('Se muestran 100 productos; acota la búsqueda.'),
          Text('Seleccionados: ${selected.length}/20'),
          ConstrainedBox(constraints:const BoxConstraints(maxHeight:240),child:SingleChildScrollView(child:Column(children:[
            for(final p in products)CheckboxListTile(dense:true,title:Text(p['name'].toString()),value:selected.contains((p['id'] as num).toInt()),
              onChanged:locked?null:(v){final id=(p['id'] as num).toInt();setState((){if(v==true){if(selected.length<20)selected.add(id);}else{selected.remove(id);}comparison=null;});}),
          ]))),
          FilledButton(onPressed:locked||target==null||selected.isEmpty?null:compare,child:const Text('Comparar catálogos')),
          if(comparison!=null&&draft==null)...[
            summary(comparison!),
            OutlinedButton(onPressed:busy||((comparison!['creates'] as num)+(comparison!['updates'] as num))==0?null:prepare,child:const Text('Preparar borrador')),
          ],
          if(draft!=null)...[
            const Divider(),const Text('Vista previa definitiva · confirma solo después de revisar',style:TextStyle(fontWeight:FontWeight.bold)),
            summary(draft!['catalogSync'] as Map),
            Text('El borrador vence en ${draft!['expiresInSeconds']} segundos desde su creación.'),
            Wrap(spacing:8,children:[
              TextButton(onPressed:busy?null:()=>resolve(false),child:const Text('Cancelar borrador')),
              FilledButton(onPressed:busy?null:()=>resolve(true),child:const Text('Confirmar sincronización')),
            ]),
          ],
        ],
      ]));
  }
}
