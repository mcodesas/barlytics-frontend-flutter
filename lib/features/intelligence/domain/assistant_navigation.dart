import '../../navigation/data/models/user_menu_item.dart';

/// Only authorized menu entries can become destinations. No raw model URLs.
class AssistantNavigation {
  static String normalize(String text){
    var s=text.toLowerCase();
    const accents={'á':'a','é':'e','í':'i','ó':'o','ú':'u','ü':'u','ñ':'n'};
    for(final entry in accents.entries){s=s.replaceAll(entry.key,entry.value);}
    return s.replaceAll(RegExp(r'[^a-z0-9]+'),' ').trim();
  }
  static String? requestedDestination(String text){
    final cleaned=normalize(text);
    final match=RegExp(r'^(?:por favor )?(?:abre|abrir|abreme|ir a|ve a|llevame a|entra a|ingresa a|navega a|abram e|quiero abrir|quiero ir a) (.+)$').firstMatch(cleaned);
    if(match==null)return null;
    return match.group(1)!.replaceFirst(RegExp(r'^(?:el |la |los |las )?(?:modulo|menu|opcion|pantalla) (?:de )?'),'')
      .replaceFirst(RegExp(r'^(el|la|los|las) '),'').replaceFirst(RegExp(r' por favor$'),'').trim();
  }
  static UserMenuItem? resolve(String target,Iterable<UserMenuItem> allowed){
    final key=normalize(target);
    final matches=allowed.where((item){
      return item.path.startsWith('/')&&!item.path.startsWith('//')&&
        !item.path.contains('://')&&!item.path.contains('?')&&!item.path.contains('#')&&
        (normalize(item.title)==key||normalize(item.keyName)==key||normalize(item.path)==key);
    }).toList();
    final unique={for(final item in matches)item.path:item};
    return unique.length==1?unique.values.single:null;
  }
  static UserMenuItem? resolveKey(String key,Iterable<UserMenuItem> allowed){
    final matches=allowed.where((item)=>item.keyName==key&&item.path.startsWith('/')&&
      !item.path.startsWith('//')&&!item.path.contains('://')&&!item.path.contains('?')&&!item.path.contains('#')).toList();
    final unique={for(final item in matches)item.path:item};
    return unique.length==1?unique.values.single:null;
  }
  /// A detail/edit screen may contribute a numeric record reference, but never
  /// a public token, arbitrary segment or query string. Backend reauthorizes it.
  static String context(String route,Iterable<UserMenuItem> allowed){
    final key=module(route,allowed);
    if(key.isEmpty)return '';
    final path=Uri.tryParse(route)?.path??'';
    final item=resolveKey(key,allowed);
    if(item==null||!path.startsWith('${item.path}/'))return key;
    final suffix=path.substring(item.path.length+1);
    if(RegExp(r'^(?:nuevo|[1-9][0-9]{0,17}(?:/editar)?)$').hasMatch(suffix)){
      final result='$key/$suffix';
      if(result.length<=120)return result;
    }
    return key;
  }
  static String module(String route,Iterable<UserMenuItem> allowed){
    // Only the route path (no query parameters, IDs or user data).
    final path=Uri.tryParse(route)?.path??'';
    final candidates=allowed.where((item)=>path==item.path||
      (item.path!='/'&&item.path.isNotEmpty&&path.startsWith('${item.path}/'))).toList()
      ..sort((a,b)=>b.path.length.compareTo(a.path.length));
    if(candidates.isNotEmpty)return candidates.first.keyName;
    if(path=='/home')return 'home';
    if(path.startsWith('/mesero/')){
      const aliases={'/mesero/productos':'mesero_productos','/mesero/historial':'historial_ventas','/mesero/cierre-caja':'cierre_caja','/mesero/resumen':'mesero'};
      final key=aliases[path];
      if(key!=null&&allowed.any((item)=>item.keyName==key))return key;
    }
    return '';
  }
}
