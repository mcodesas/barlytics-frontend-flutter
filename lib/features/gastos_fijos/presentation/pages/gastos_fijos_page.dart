import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/providers/core_providers.dart';
import 'package:intl/intl.dart';

class GastosFijosPage extends ConsumerStatefulWidget {
  const GastosFijosPage({super.key});
  @override ConsumerState<GastosFijosPage> createState()=>_GastosFijosPageState();
}
class _GastosFijosPageState extends ConsumerState<GastosFijosPage> {
  List<Map<String,dynamic>> items=[]; bool loading=true;
  @override void initState(){super.initState(); WidgetsBinding.instance.addPostFrameCallback((_)=>_load());}
  Future<void> _load() async {
    final id=ref.read(branchScopeProvider).activeBranchId; if(id==null){setState(()=>loading=false);return;}
    setState(()=>loading=true);
    final response=await ref.read(apiClientProvider).get<List<dynamic>>('/api/v1/gastos-fijos/sucursal/$id',(j)=>(j as List? ?? const []));
    if(mounted)setState((){items=(response.data ?? const <dynamic>[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();loading=false;});
  }
  Future<void> _edit([Map<String,dynamic>? current]) async {
    final id=ref.read(branchScopeProvider).activeBranchId;if(id==null)return;
    final name=TextEditingController(text:current?['gafiNombre']?.toString() ?? ''');
    final value=TextEditingController(text:current?['gafiValor']?.toString() ?? ''');
    final note=TextEditingController(text:current?['gafiObservacion']?.toString() ?? ''');
    String category=current?['gafiCategoria']?.toString() ?? 'Otros';
    String periodicity=current?['gafiPeriodicidad']?.toString() ?? 'MENSUAL';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:Text(current==null?'Nuevo gasto fijo':'Modificar gasto fijo'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre · Ej. Arriendo')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Categoría'),items:const ['Arriendo','Servicios','Mano de obra','Internet','Seguridad','Contabilidad','Mantenimiento','Licencias','Otros'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>category=v!)),
        const SizedBox(height:10),
        TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:periodicity,decoration:const InputDecoration(labelText:'Periodicidad'),items:const {'DIARIO':'Diario','SEMANAL':'Semanal','QUINCENAL':'Quincenal','MENSUAL':'Mensual','ANUAL':'Anual'}.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>periodicity=v!)),
        const SizedBox(height:10),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Observación')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Guardar'))],
    )));
    if(ok!=true)return;
    final raw=value.text.replaceAll('.','').replaceAll(',','.');
    final body={'sucuId':id,'gafiNombre':name.text.trim(),'gafiCategoria':category,'gafiValor':double.tryParse(raw)??0,'gafiPeriodicidad':periodicity,'gafiFechaInicio':DateTime.now().toIso8601String().substring(0,10),'gafiEstado':1,'gafiObservacion':note.text.trim()};
    final api=ref.read(apiClientProvider);
    if(current==null) await api.post<Object?>('/api/v1/gastos-fijos',body,(j)=>j);
    else await api.put<Object?>('/api/v1/gastos-fijos/${current['gafiId']}',body,(j)=>j);
    await _load();
  }
  @override Widget build(BuildContext context){
    final palette=ref.watch(selectedAppPaletteProvider);
    return Scaffold(backgroundColor:palette.background,floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('Agregar gasto')),
      body:SafeArea(child:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(20),children:[
        Text('Gastos fijos',style:TextStyle(color:palette.textPrimary,fontSize:28,fontWeight:FontWeight.w900)),
        const SizedBox(height:6),Text('Costos recurrentes usados para calcular la utilidad neta del negocio.',style:TextStyle(color:palette.textSecondary,fontWeight:FontWeight.w600)),
        const SizedBox(height:20),
        if(loading) const Center(child:CircularProgressIndicator()) else if(items.isEmpty) const Center(child:Padding(padding:EdgeInsets.all(40),child:Text('Aún no hay gastos fijos registrados.'))) else
        ...items.map((x)=>Card(child:ListTile(leading:const Icon(Icons.receipt_long_rounded),title:Text(x['gafiNombre']?.toString()??'Gasto',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${x['gafiCategoria']} · ${x['gafiPeriodicidad']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(NumberFormat.currency(locale: 'es_CO', symbol: r',style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(onPressed:()=>_edit(x),icon:const Icon(Icons.edit_outlined))])))),
      ]))),
    );
  }
}
, decimalDigits: 0).format((x['gafiValor'] as num?)?.toDouble() ?? 0),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(onPressed:()=>_edit(x),icon:const Icon(Icons.edit_outlined))])))),
      ]))),
    );
  }
}
