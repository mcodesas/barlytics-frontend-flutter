import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/file_download_helper.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../data/intelligence_api.dart';
import '../domain/intelligence_result_format.dart';

/// No data from the language model is used as a report cell.
/// Every format is fetched again from Commerce under the current role and branch.
class IntelligenceExportCard extends ConsumerStatefulWidget {
  const IntelligenceExportCard({super.key,required this.branch,required this.plan, this.disabled=false});
  final int branch;
  final Map<String,dynamic> plan;
  final bool disabled;
  @override
  ConsumerState<IntelligenceExportCard> createState()=>_IntelligenceExportCardState();
}

class _IntelligenceExportCardState extends ConsumerState<IntelligenceExportCard>{
  bool busy=false;
  int generation=0;
  String? status;
  Map<String,dynamic>? dataset;
  String? label,value;
  int page=0;
  String get resource=>(widget.plan['query'] as Map?)?['resource']?.toString()??'';
  bool _active(int g)=>mounted&&generation==g&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void _reset(){
    generation++;
    if(mounted)setState((){busy=false;status=null;dataset=null;label=null;value=null;page=0;});
  }
  @override
  void didUpdateWidget(covariant IntelligenceExportCard oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.branch!=widget.branch||oldWidget.plan!=widget.plan)_reset();
  }
  @override
  void dispose(){generation++;super.dispose();}
  Future<void> _request(String format) async {
    if(busy||widget.disabled||ref.read(branchScopeProvider).activeBranchId!=widget.branch)return;
    final g=++generation;
    setState((){busy=true;status=null;dataset=null;label=null;value=null;page=0;});
    try{
      final result=await ref.read(intelligenceApiProvider).exportData(widget.branch,{
        'format':format,'query':widget.plan['query'],
      });
      if(!_active(g))return;
      if(result['format']!=format||result['branchId']!=widget.branch||result['rowCount'] is! int||result['partial'] is! bool)
        throw const FormatException('Reporte inválido');
      final count=result['rowCount'] as int;
      final partial=result['partial']==true;
      if(count<0||count>500)throw const FormatException('Límite de reporte inválido');
      if(format=='chart'||format=='table'||format=='pdf'){
        final columns=_columns(result),rows=_rows(result);
        if(columns.length>80||rows.length!=count||rows.any((r)=>r.length!=columns.length))throw const FormatException('Datos inconsistentes');
        if(format=='chart'||format=='table'){
          final numeric=_numericColumns(columns,rows);
          final categories=columns.where((c)=>!numeric.contains(c)&&!IntelligenceResultFormat.identifier(c)).toList();
          setState((){dataset=result;value=numeric.contains('total')?'total':numeric.firstOrNull;label=categories.contains('fecha')?'fecha':categories.firstOrNull??columns.firstOrNull;page=0;});
        }else{
          final bytes=await _pdf(result,columns,rows);
          if(!_active(g))return;
          final saved=await downloadBytesFile(fileName:'intelligence-${widget.branch}${partial?'-parcial':''}.pdf',bytes:bytes,mimeType:'application/pdf');
          if(_active(g))setState(()=>status=saved?'PDF guardado.':'Guardado cancelado.');
        }
      }else{
        final raw=result['contentBase64'];
        if(raw is! String||raw.length>6*1024*1024)throw const FormatException('Archivo inválido');
        final bytes=base64Decode(raw);
        if(!_active(g))return;
        final saved=await downloadBytesFile(fileName:'intelligence-${widget.branch}${partial?'-parcial':''}.$format',bytes:bytes,
          mimeType:format=='xlsx'?'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':'text/csv;charset=utf-8');
        if(_active(g))setState(()=>status=saved?'Archivo guardado.':'Guardado cancelado.');
      }
      if(_active(g)&&partial)setState(()=>status='${status??''} Resultado parcial: $count filas. Acota filtros o solicita otra página.');
    }catch(_){
      if(_active(g))setState(()=>status='No fue posible generar el informe. Verifica permisos, filtros y tamaño. Para informes extensos utiliza Excel o CSV.');
    }finally{if(_active(g))setState(()=>busy=false);}
  }
  static List<String> _columns(Map<String,dynamic> d)=>(d['columns'] as List).cast<String>();
  static List<List<dynamic>> _rows(Map<String,dynamic> d)=>(d['rows'] as List).map((r)=>(r as List).cast<dynamic>()).toList();
  List<String> _numericColumns(List<String> columns,List<List<dynamic>> rows)=>[
    for(int i=0;i<columns.length;i++)if(!IntelligenceResultFormat.identifier(columns[i])&&rows.any((r)=>IntelligenceResultFormat.measure(columns[i],r[i],resource)!=null)&&rows.every((r)=>r[i]==null||IntelligenceResultFormat.measure(columns[i],r[i],resource)!=null))columns[i]
  ];
  static String _cell(dynamic value)=>value?.toString()??'';
  Future<Uint8List> _pdf(Map<String,dynamic> d,List<String> cols,List<List<dynamic>> rows) async {
    // Wide datasets are split horizontally and keep a row reference. Refuse
    // very large cells instead of silently truncating the exported report.
    if(cols.length*rows.length>6000||rows.any((r)=>r.any((v)=>_cell(v).length>250)))throw const FormatException('Usa Excel para datos extensos');
    final doc=pw.Document();
    final groups=math.max(1,(cols.length/6).ceil());
    for(int group=0;group<groups;group++){
      final start=group*6,end=math.min(start+6,cols.length);
      doc.addPage(pw.MultiPage(
        maxPages:150,pageFormat:PdfPageFormat.a4.landscape,
        margin:const pw.EdgeInsets.all(28),
        header:(_)=>pw.Text('BarLytics | Intelligence',style:pw.TextStyle(fontSize:12,fontWeight:pw.FontWeight.bold,color:PdfColors.teal800)),
        footer:(ctx)=>pw.Text('Sucursal ${widget.branch} | Página ${ctx.pageNumber} / ${ctx.pagesCount}',style:const pw.TextStyle(fontSize:9)),
        build:(_)=>[
          pw.SizedBox(height:10),
          pw.Text(d['title'].toString(),style:pw.TextStyle(fontSize:17,fontWeight:pw.FontWeight.bold)),
          pw.Text('Generado: ${d['generatedAt']} | ${rows.length} registros | Bloque ${group+1}/$groups'),
          if(d['partial']==true)pw.Text('Resultado parcial: acota los filtros o solicita otra página.',style:const pw.TextStyle(color:PdfColors.orange800)),
          pw.SizedBox(height:10),
          if(rows.isEmpty)pw.Text('Sin registros coincidentes.')
          else pw.Table.fromTextArray(
            headers:['Fila',...cols.sublist(start,end)],
            data:[for(int i=0;i<rows.length;i++)['${i+1}',...rows[i].sublist(start,end).map(_cell)]],
            headerDecoration:const pw.BoxDecoration(color:PdfColors.teal800),
            headerStyle:pw.TextStyle(color:PdfColors.white,fontSize:9,fontWeight:pw.FontWeight.bold),
            cellStyle:const pw.TextStyle(fontSize:8),cellPadding:const pw.EdgeInsets.all(5),
          ),
        ],
      ));
    }
    return doc.save();
  }
  Widget _pageControls(int count,int size){
    final pages=math.max(1,(count/size).ceil());
    return Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton(tooltip:'Anterior',onPressed:page>0?()=>setState(()=>page--):null,icon:const Icon(Icons.chevron_left)),
      Expanded(child:Text('Página '+(page+1).toString()+' de '+pages.toString(),textAlign:TextAlign.center)),
      IconButton(tooltip:'Siguiente',onPressed:page+1<pages?()=>setState(()=>page++):null,icon:const Icon(Icons.chevron_right)),
    ]);
  }
  Widget _preview(Map<String,dynamic> data){
    final cols=_columns(data),rows=_rows(data);
    if(rows.isEmpty||cols.isEmpty)return const Text('No hay datos para mostrar.');
    const size=12;
    if(data['format']=='table'){
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(rows.length.toString()+' registros disponibles'+(data['partial']==true?' · resultado parcial':'')),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
          columns:[for(final c in cols)DataColumn(label:Text(IntelligenceResultFormat.label(c)))],
          rows:[for(final r in rows.skip(page*size).take(size))DataRow(cells:[
            for(int i=0;i<cols.length;i++)DataCell(Text(IntelligenceResultFormat.cell(cols[i],r[i],resource),maxLines:3,overflow:TextOverflow.ellipsis))
          ])],
        )),
        _pageControls(rows.length,size),
      ]);
    }
    final numeric=_numericColumns(cols,rows);
    if(numeric.isEmpty)return const Text('La consulta no contiene valores numéricos para graficar. Usa una agregación o reporte.');
    if(rows.length==1&&const {'ganancias','reporte_resumen_ejecutivo'}.contains(resource)){
      final keys=['ingresos_periodo','costo_ventas_periodo','ganancia_bruta_periodo','gastos_operativos_periodo','ganancia_neta_estimada_periodo'].where(numeric.contains).toList();
      if(keys.isNotEmpty){
        final points=keys.map((k)=>(label:IntelligenceResultFormat.label(k),value:IntelligenceResultFormat.measure(k,rows.first[cols.indexOf(k)],resource)!,formatted:IntelligenceResultFormat.cell(k,rows.first[cols.indexOf(k)],resource))).toList();
        return _bars(points);
      }
    }
    final selectedValue=numeric.contains(value)?value!:numeric.first,selectedLabel=cols.contains(label)?label!:cols.first;
    final vi=cols.indexOf(selectedValue),li=cols.indexOf(selectedLabel);
    final points=rows.where((r)=>IntelligenceResultFormat.measure(selectedValue,r[vi],resource)!=null).map((r)=>(
      label:IntelligenceResultFormat.cell(selectedLabel,r[li],resource),
      value:IntelligenceResultFormat.measure(selectedValue,r[vi],resource)!,
      formatted:IntelligenceResultFormat.cell(selectedValue,r[vi],resource),
    )).toList();
    final scale=points.fold<double>(0,(max,r)=>math.max(max,r.value.toDouble().abs()));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      DropdownButtonFormField<String>(value:selectedLabel,isExpanded:true,decoration:const InputDecoration(labelText:'Categoría'),
        items:[for(final c in cols)DropdownMenuItem(value:c,child:Text(IntelligenceResultFormat.label(c),overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState((){label=v;page=0;})),
      DropdownButtonFormField<String>(value:selectedValue,isExpanded:true,decoration:const InputDecoration(labelText:'Indicador'),
        items:[for(final c in numeric)DropdownMenuItem(value:c,child:Text(IntelligenceResultFormat.label(c),overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState((){value=v;page=0;})),
      const SizedBox(height:8),
      _bars(points.skip(page*size).take(size).toList(),scale:scale),
      _pageControls(points.length,size),
      Text(points.length.toString()+' valores disponibles. Escala común en todas las páginas'+(data['partial']==true?' · resultado parcial':'')+'.'),
    ]);
  }
  Widget _bars(List<({String label,num value,String formatted})> points,{double? scale}){
    final maxValue=scale??points.fold<double>(0,(max,r)=>math.max(max,r.value.toDouble().abs()));
    final theme=Theme.of(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      for(final r in points)...[
        Row(children:[Expanded(child:Text(r.label,maxLines:2,overflow:TextOverflow.ellipsis)),const SizedBox(width:8),Flexible(child:Text(r.formatted,textAlign:TextAlign.end,style:const TextStyle(fontWeight:FontWeight.w600)))]),
        const SizedBox(height:4),
        LayoutBuilder(builder:(context,box){
          final n=r.value.toDouble();
          final width=maxValue==0?0.0:box.maxWidth/2*(n.abs()/maxValue);
          return SizedBox(height:14,child:Stack(children:[
            Positioned(left:box.maxWidth/2,top:0,bottom:0,child:Container(width:1,color:theme.dividerColor)),
            Positioned(left:n<0?box.maxWidth/2-width:box.maxWidth/2,top:1,bottom:1,width:width,
              child:ColoredBox(color:n<0?theme.colorScheme.error:theme.colorScheme.primary)),
          ]));
        }),
        const SizedBox(height:8),
      ],
    ]);
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)_reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)_reset();});
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Explorar resultados',style:TextStyle(fontWeight:FontWeight.bold)),
      const Text('Cada generación consulta datos vigentes y comprueba tus permisos.'),
      const SizedBox(height:8),
      Wrap(spacing:6,runSpacing:6,children:[
        for(final item in const [('xlsx','Excel',Icons.table_view),('csv','CSV',Icons.grid_on),('pdf','PDF',Icons.picture_as_pdf),('chart','Gráfica',Icons.bar_chart),('table','Tabla',Icons.list_alt)])
          OutlinedButton.icon(onPressed:busy||widget.disabled?null:()=>_request(item.$1),icon:Icon(item.$3),label:Text(item.$2)),
      ]),
      if(busy)const LinearProgressIndicator(),
      if(status!=null)Text(status!),
      if(dataset!=null)ConstrainedBox(constraints:const BoxConstraints(maxHeight:350),child:SingleChildScrollView(child:_preview(dataset!))),
    ])));
  }
}
