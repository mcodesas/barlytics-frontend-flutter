import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';

class IntelligenceMemoryCard extends ConsumerStatefulWidget {
  const IntelligenceMemoryCard({super.key,required this.branch});
  final int branch;
  @override
  ConsumerState<IntelligenceMemoryCard> createState()=>_MemoryState();
}

class _MemoryState extends ConsumerState<IntelligenceMemoryCard>{
  bool busy=false,loaded=false,expanded=false,history=false,notesEnabled=false,editing=false;
  int generation=0;
  String? error,editId;
  List<Map<String,dynamic>> notes=[];
  final title=TextEditingController(),content=TextEditingController();
  bool active(int g)=>mounted&&g==generation&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  @override
  void dispose(){generation++;title.dispose();content.dispose();super.dispose();}
  void reset(){
    generation++;
    if(mounted)setState((){busy=false;loaded=false;history=false;notesEnabled=false;notes=[];editing=false;editId=null;error=null;title.clear();content.clear();});
  }
  Future<void> run(Future<Map<String,dynamic>> Function(IntelligenceApi) fn) async{
    if(busy||!mounted||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final g=++generation;
    setState((){busy=true;error=null;});
    try{
      final data=await fn(ref.read(intelligenceApiProvider));
      if(!active(g))return;
      final settings=data['settings'] as Map;
      final items=(data['notes'] as List).whereType<Map>().map((n)=>Map<String,dynamic>.from(n)).toList();
      setState((){history=settings['recallHistory']==true;notesEnabled=settings['recallNotes']==true;notes=items;loaded=true;editing=false;editId=null;title.clear();content.clear();});
    }catch(_){if(active(g))setState(()=>error='No se pudo completar la operación. Revisa los permisos y la conexión. No se confirmó ningún cambio.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> load()=>run((api)=>api.memory(widget.branch));
  Future<void> configure({required bool h,required bool n,bool reset=false})=>run((api)=>api.configureMemory(widget.branch,recallHistory:h,recallNotes:n,resetHistory:reset));
  void edit([Map<String,dynamic>? note]){
    setState((){editing=true;editId=note?['id']?.toString();title.text=note?['title']?.toString()??'';content.text=note?['content']?.toString()??'';});
  }
  Future<void> save() async{
    final t=title.text.trim(),c=content.text.trim(),id=editId;
    if(t.isEmpty||c.isEmpty){setState(()=>error='Completa el título y la nota.');return;}
    await run((api)=>api.saveMemory(widget.branch,t,c,noteId:id));
  }
  Future<void> confirmDelete(String id) async{
    final g=generation;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Eliminar nota'),content:const Text('Esta nota dejará de estar disponible para Intelligence. No se borrarán las conversaciones donde se mencionó.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Eliminar'))]));
    if(ok==true&&active(g))await run((api)=>api.deleteMemory(widget.branch,id));
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)reset();});
    return Card(child:ExpansionTile(
      leading:const Icon(Icons.psychology_outlined),
      title:const Text('Memoria contextual'),
      subtitle:const Text('Preferencias privadas y referencias anteriores'),
      onExpansionChanged:(open){setState(()=>expanded=open);if(open&&!loaded)load();},
      childrenPadding:const EdgeInsets.all(12),children:[
        if(busy)const LinearProgressIndicator(),
        if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        if(!loaded&&!busy)TextButton(onPressed:load,child:const Text('Cargar configuración')),
        if(loaded)...[
          const Text('Solo para tu usuario y esta sucursal. Nunca guardes contraseñas, información de tarjetas, datos personales de terceros ni credenciales. Las notas no conceden permisos ni sustituyen una consulta actual.'),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Recuperar preguntas de otras conversaciones'),
            subtitle:const Text('Solo preguntas nuevas desde la activación, hasta 90 días. No recupera respuestas comerciales.'),
            value:history,onChanged:busy||editing?null:(v)=>configure(h:v,n:notesEnabled)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Usar mis notas guardadas'),
            subtitle:const Text('Recupera las notas relacionadas con la pregunta actual.'),
            value:notesEnabled,onChanged:busy||editing?null:(v)=>configure(h:history,n:v)),
          TextButton(onPressed:busy||editing?null:()=>configure(h:history,n:notesEnabled,reset:true),child:const Text('Reiniciar referencias históricas')),
          const Text('Reiniciar impide recuperar preguntas anteriores a este momento; no elimina el historial de chat.'),
          const Divider(),
          Row(children:[const Expanded(child:Text('Mis notas',style:TextStyle(fontWeight:FontWeight.bold))),
            IconButton(tooltip:'Añadir nota',onPressed:busy||editing||notes.length>=30?null:()=>edit(),icon:const Icon(Icons.add))]),
          if(notes.isEmpty&&!editing)const Text('No tienes notas guardadas.'),
          if(editing)...[
            TextField(controller:title,maxLength:100,enabled:!busy,decoration:const InputDecoration(labelText:'Título')),
            TextField(controller:content,maxLength:600,maxLines:3,enabled:!busy,decoration:const InputDecoration(labelText:'Preferencia o contexto (una sola línea)')),
            Wrap(spacing:8,children:[
              FilledButton(onPressed:busy?null:save,child:const Text('Guardar')),
              TextButton(onPressed:busy?null:()=>setState((){editing=false;editId=null;title.clear();content.clear();}),child:const Text('Cancelar')),
            ]),
          ],
          for(final note in notes)ListTile(contentPadding:EdgeInsets.zero,title:Text(note['title'].toString()),subtitle:Text(note['content'].toString()),
            trailing:Wrap(children:[
              IconButton(tooltip:'Editar nota',onPressed:busy||editing?null:()=>edit(note),icon:const Icon(Icons.edit_outlined)),
              IconButton(tooltip:'Eliminar nota',onPressed:busy||editing?null:()=>confirmDelete(note['id'].toString()),icon:const Icon(Icons.delete_outline)),
            ])),
        ],
      ],
    ));
  }
}
