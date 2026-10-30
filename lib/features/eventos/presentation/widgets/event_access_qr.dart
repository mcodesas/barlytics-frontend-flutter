/// Extrae únicamente el token de una entrada INDIVIDUAL.
/// El QR principal de una reserva no autoriza el acceso a todo el grupo.
String? extractEventEntryToken(String? raw) {
  final input=(raw??'').trim();
  if(input.isEmpty||input.length>2048)return null;
  final uuid=RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if(uuid.hasMatch(input))return input.toLowerCase();
  final uri=Uri.tryParse(input);
  if(uri==null||!uri.hasScheme||uri.scheme!='https')return null;
  final host=uri.host.toLowerCase();
  if(host!='barlytics.com.co'&&host!='www.barlytics.com.co')return null;
  // Los QR del correo enlazan a /#/evento/entrada/{token}.
  final path=uri.fragment.startsWith('/')?uri.fragment:uri.path;
  final match=RegExp(
    r'^/evento/entrada/([0-9a-fA-F-]{36})/?(?:\?.*)?$',
  ).firstMatch(path);
  final token=match?.group(1);
  return token!=null&&uuid.hasMatch(token)?token.toLowerCase():null;
}
