import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';

class _Line {
  _Line({String product='',String quantity='',this.unit='UNKNOWN',this.evidence='',this.priceText=''}):
    product=TextEditingController(text:product),quantity=TextEditingController(text:quantity);
  final TextEditingController product,quantity;
  String unit;
  final String evidence,priceText;
  void dispose(){product.dispose();quantity.dispose();}
}

/// Edits only local candidates; the parent prepares the authoritative server draft.
class IntelligencePurchaseReview extends ConsumerStatefulWidget {
  const IntelligencePurchaseReview({super.key,required this.branch,required this.source,required this.onPrepare});
  final int branch;
  final String source;
  final Future<void> Function(Map<String,dynamic>) onPrepare;
  @override
  ConsumerState<IntelligencePurchaseReview> createState()=>_ReviewState();
}

class _ReviewState extends ConsumerState<IntelligencePurchaseReview>{
  final supplier=TextEditingController(),reference=TextEditingController(),fragment=TextEditingController();
  final lines=<_Line>[];
  bool busy=false,checked=false,available=false,loaded=false;
  String? error;
  int generation=0;
  @override
  void initState(){
    super.initState();
    fragment.text=widget.source.length<=4000?widget.source:'';
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)_options();});
  }
  bool active(int g)=>mounted&&g==generation&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void clearLines(){for(final line in lines){line.dispose();}lines.clear();}
  @override
  void dispose(){generation++;clearLines();supplier.dispose();reference.dispose();fragment.dispose();super.dispose();}
  void reset(){
    generation++;
    if(mounted)setState((){clearLines();supplier.clear();reference.clear();fragment.clear();busy=false;checked=false;available=false;loaded=false;error='Cambió el alcance. Cierra la revisión y vuelve a abrir el documento.';});
  }
  Future<void> _options() async {
    if(busy)return;
    final g=++generation;
    setState(()=>busy=true);
    try{
      final value=await ref.read(intelligenceApiProvider).purchaseAvailable(widget.branch);
      if(active(g))setState((){available=value;loaded=true;});
    }catch(_){if(active(g))setState(()=>error='No se pudieron comprobar los permisos.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> extract() async{
    if(busy||!available)return;
    final text=fragment.text.trim();
    if(text.isEmpty||text.length>4000){setState(()=>error='Selecciona hasta 4000 caracteres del documento.');return;}
    final g=++generation;
    setState((){busy=true;checked=false;error=null;});
    try{
      final r=await ref.read(intelligenceApiProvider).extractPurchase(widget.branch,text);
      if(!active(g))return;
      final result=(r['lines'] as List).whereType<Map>().toList();
      if(result.length>6)throw const FormatException('Demasiadas filas');
      if(lines.length+result.length>30)throw const FormatException('Máximo 30 filas');
      setState((){
        if(supplier.text.isEmpty)supplier.text=r['supplier']?.toString()??'';
        if(reference.text.isEmpty)reference.text=r['reference']?.toString()??'';
        for(final row in result){
          final unit=row['unit']?.toString()??'UNKNOWN';
          lines.add(_Line(product:row['product']?.toString()??'',quantity:row['quantity']?.toString()??'',
            unit:const ['UNITS','PACKS','UNKNOWN'].contains(unit)?unit:'UNKNOWN',evidence:row['evidence']?.toString()??'',priceText:row['priceText']?.toString()??''));
        }
        if(result.isEmpty)error='No se identificaron líneas fiables. Puedes añadirlas manualmente.';
      });
    }catch(_){if(active(g))setState(()=>error='No se obtuvo una extracción verificable. Usa un fragmento menor o añade filas manualmente.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Future<void> prepare() async{
    if(busy||!available||!checked||lines.isEmpty)return;
    final rows=<Map<String,dynamic>>[];
    if(supplier.text.trim().isEmpty){setState(()=>error='Indica el nombre exacto del proveedor en BarLytics.');return;}
    for(final l in lines){
      final q=num.tryParse(l.quantity.text.trim().replaceAll(',','.'));
      if(l.product.text.trim().isEmpty||q==null||!q.isFinite||q<=0||l.unit=='UNKNOWN'){
        setState(()=>error='Verifica el nombre, cantidad y presentación de todos los renglones.');return;
      }
      rows.add({'product':l.product.text.trim(),'quantity':q,'unit':l.unit});
    }
    final g=++generation;setState((){busy=true;error=null;});
    try{
      await widget.onPrepare({'documentPurchase':{'supplier':supplier.text.trim(),'reference':reference.text.trim(),'lines':rows}});
      if(active(g))setState(()=>checked=false);
    }catch(_){if(active(g))setState(()=>error='No se preparó el pedido. Comprueba los nombres exactos, productos duplicados, presentaciones y costos configurados.');}
    finally{if(active(g))setState(()=>busy=false);}
  }
  Widget field(TextEditingController c,String label,int max,{bool number=false})=>TextField(
    controller:c,maxLength:max,enabled:!busy,onChanged:(_){if(checked)setState(()=>checked=false);},
    keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
    decoration:InputDecoration(labelText:label,counterText:''));
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)reset();});
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Preparar pedido desde documento',style:TextStyle(fontWeight:FontWeight.bold)),
      const Text('No es una importación de factura fiscal. Verifica todos los renglones originales. El pedido usa los costos registrados en BarLytics, no los importes impresos.'),
      if(busy)const LinearProgressIndicator(),
      if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(loaded&&!available)const Text('Tu rol no tiene todos los permisos de pedidos, proveedores, productos y precios.'),
      if(available)...[
        ExpansionTile(title:const Text('Texto original extraído'),children:[
          SelectableText(widget.source),
        ]),
        if(widget.source.length>4000)const Text('Copia un fragmento de hasta 4000 caracteres. Procesa todos los fragmentos y revisa que no falten renglones.'),
        TextField(controller:fragment,maxLength:4000,maxLines:4,enabled:!busy,decoration:const InputDecoration(labelText:'Fragmento para interpretar')),
        OutlinedButton.icon(onPressed:busy?null:extract,icon:const Icon(Icons.auto_awesome),label:const Text('Detectar renglones (máximo 6 por fragmento)')),
        field(supplier,'Proveedor: nombre exacto en BarLytics',160),
        field(reference,'Referencia del documento (opcional)',100),
        for(final entry in lines.asMap().entries)...[
          const Divider(),
          Row(children:[Expanded(child:Text('Renglón ${entry.key+1}',style:const TextStyle(fontWeight:FontWeight.bold))),
            IconButton(onPressed:busy?null:()=>setState((){lines.removeAt(entry.key).dispose();checked=false;}),icon:const Icon(Icons.delete_outline))]),
          if(entry.value.evidence.isNotEmpty)SelectableText('Origen: ${entry.value.evidence}'),
          if(entry.value.priceText.isNotEmpty)Text('Importe impreso (verificar si es unitario o total): ${entry.value.priceText}'),
          field(entry.value.product,'Nombre exacto del producto',160),
          field(entry.value.quantity,'Cantidad',20,number:true),
          DropdownButtonFormField<String>(value:entry.value.unit,decoration:const InputDecoration(labelText:'Tipo de cantidad'),
            items:const [DropdownMenuItem(value:'UNKNOWN',child:Text('Por verificar')),DropdownMenuItem(value:'UNITS',child:Text('Unidades base')),DropdownMenuItem(value:'PACKS',child:Text('Presentaciones de compra'))],
            onChanged:busy?null:(v)=>setState((){entry.value.unit=v??'UNKNOWN';checked=false;})),
        ],
        TextButton.icon(onPressed:busy||lines.length>=30?null:()=>setState((){lines.add(_Line());checked=false;}),icon:const Icon(Icons.add),label:const Text('Añadir renglón manual')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:checked,onChanged:busy?null:(v)=>setState(()=>checked=v==true),
          title:const Text('Revisé el documento completo, nombres, cantidades y presentaciones.')),
        FilledButton(onPressed:busy||!checked||lines.isEmpty?null:prepare,child:const Text('Preparar vista previa del pedido')),
      ],
    ])));
  }
}
