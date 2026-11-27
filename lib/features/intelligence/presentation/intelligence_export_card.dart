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
  bool _active(int g)=>mounted&&generation==g&&ref.read(branchScopeProvider).activeBranchId==widget.branch;
  void _reset(){
    generation++;
    if(mounted)setState((){busy=false;status=null;dataset=null;label=null;value=null;});
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
    setState((){busy=true;status=null;dataset=null;label=null;value=null;});
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
          final categories=columns.where((c)=>!numeric.contains(c)).toList();
          setState(()=>{dataset=result,value=numeric.firstOrNull,label=categories.firstOrNull??columns.firstOrNull});
        }else{
          final bytes=await _pdf(result,columns,rows);
          if(!_active(g))return;
          final saved=await downloadBytesFile(fileName:'intelligence-${widget.branch}.pdf',bytes:bytes,mimeType:'application/pdf');
          if(_active(g))setState(()=>status=saved?'PDF guardado.':'Guardado cancelado.');
        }
      }else{
        final raw=result['contentBase64'];
        if(raw is! String||raw.length>6*1024*1024)throw const FormatException('Archivo inválido');
        final bytes=base64Decode(raw);
        if(!_active(g))return;
        final saved=await downloadBytesFile(fileName:'intelligence-${widget.branch}.$format',bytes:bytes,
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
  static List<String> _numericColumns(List<String> columns,List<List<dynamic>> rows)=>[
    for(int i=0;i<columns.length;i++)if(rows.any((r)=>r[i] is num&&(r[i] as num).isFinite)&&rows.every((r)=>r[i]==null||(r[i] is num&&(r[i] as num).isFinite)))columns[i]
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
  Widget _preview(Map<String,dynamic> data){
    final cols=_columns(data),rows=_rows(data);
    if(rows.isEmpty||cols.isEmpty)return const Text('No hay datos para mostrar.');
    if(data['format']=='table')return SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      columns:[for(final c in cols)DataColumn(label:Text(c))],
      rows:[for(final r in rows.take(20))DataRow(cells:[for(final v in r)DataCell(Text(_cell(v),maxLines:3,overflow:TextOverflow.ellipsis))])],
    ));
    final numeric=_numericColumns(cols,rows);
    if(numeric.isEmpty)return const Text('La consulta no contiene valores numéricos para graficar. Usa una agregación o reporte.');
    final selectedValue=value??numeric.first,selectedLabel=label??cols.first;
    final vi=cols.indexOf(selectedValue),li=cols.indexOf(selectedLabel);
    final points=rows.where((r)=>r[vi] is num).take(20).toList();
    final scale=points.fold<double>(0,(max,r)=>math.max(max,(r[vi] as num).toDouble().abs()));
    final theme=Theme.of(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      DropdownButtonFormField<String>(value:selectedLabel,isExpanded:true,decoration:const InputDecoration(labelText:'Categoría'),
        items:[for(final c in cols)DropdownMenuItem(value:c,child:Text(c,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>label=v)),
      DropdownButtonFormField<String>(value:selectedValue,isExpanded:true,decoration:const InputDecoration(labelText:'Valor'),
        items:[for(final c in numeric)DropdownMenuItem(value:c,child:Text(c,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>value=v)),
      const SizedBox(height:8),
      for(final r in points)...[
        Text('${_cell(r[li])} · ${_cell(r[vi])}',maxLines:2,overflow:TextOverflow.ellipsis),
        LayoutBuilder(builder:(context,box){
          final n=(r[vi] as num).toDouble();
          final width=scale==0?0.0:box.maxWidth/2*(n.abs()/scale);
          return SizedBox(height:13,child:Stack(children:[
            Positioned(left:box.maxWidth/2,top:0,bottom:0,child:Container(width:1,color:theme.dividerColor)),
            Positioned(left:n<0?box.maxWidth/2-width:box.maxWidth/2,top:1,bottom:1,width:width,
              child:ColoredBox(color:n<0?theme.colorScheme.error:theme.colorScheme.primary)),
          ]));
        }),
        const SizedBox(height:5),
      ],
      Text('Primeras ${points.length} filas numéricas; no se agrupan ni se alteran los valores.'),
    ]);
  }
  @override
  Widget build(BuildContext context){
    ref.listen(selectedRolesProvider,(old,next){if(old!=next)_reset();});
    ref.listen(branchScopeProvider,(old,next){if(old?.activeBranchId!=next.activeBranchId)_reset();});
    final requested=widget.plan['format'];
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Informe Intelligence',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('Consulta: ${(widget.plan['query'] as Map?)?['resource']??''} · Formato solicitado: $requested'),
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
