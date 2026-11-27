import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantScreenContextProvider=Provider<AssistantScreenContextRegistry>((ref)=>AssistantScreenContextRegistry());
typedef ScreenContextReader=String? Function(String module,int branch);
class AssistantScreenContextRegistry {
  final Map<Object,ScreenContextReader> _readers={};
  void register(Object owner,ScreenContextReader reader)=>_readers[owner]=reader;
  void unregister(Object owner)=>_readers.remove(owner);
  String resolve(String module,int branch){
    if(module.isEmpty||module.contains('/'))return module;
    for(final reader in _readers.values.toList().reversed){
      final candidate=reader(module,branch);
      if(candidate!=null&&candidate.startsWith('$module/')&&candidate.length<=120&&RegExp(r'^[a-zA-Z0-9_/-]+$').hasMatch(candidate))return candidate;
    }
    return module;
  }
  static String? catalog(String module,{int? productId,int? typeId,int? brandId,String? status}){
    if(!const {'productos','precios'}.contains(module))return null;
    final segments=<String>[module];
    if(module=='productos'&&productId!=null&&productId>0)segments.addAll(['producto','$productId']);
    if(typeId!=null&&typeId>0)segments.addAll(['tipo','$typeId']);
    if(brandId!=null&&brandId>0)segments.addAll(['marca','$brandId']);
    if(module=='precios'&&const {'all','withPrice','withoutPrice','changed'}.contains(status))segments.addAll(['estado',status!]);
    return segments.length>1?segments.join('/'):null;
  }
  static String? count(String module,String status){
    if(module!='inventario'||!const {'pendientes','registrados','todos'}.contains(status))return null;
    return '$module/estado/$status';
  }
  static String? period(String module,String report,DateTime start,DateTime end){
    if(module!=report&&module!='reportes')return null;
    if(start.isAfter(end)||!RegExp(r'^[a-z_]{1,48}$').hasMatch(report))return null;
    String day(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    return '$module/reporte/$report/desde/${day(start)}/hasta/${day(end)}';
  }
  static String? sale(String module,int? saleId,int? accountId,{int? tableId}){
    if(!const {'mesero','ventas'}.contains(module)||saleId==null||saleId<=0)return null;
    return '$module/venta/$saleId${accountId!=null&&accountId>0?'/cuenta/$accountId':''}${tableId!=null&&tableId>0?'/mesa/$tableId':''}';
  }
}
