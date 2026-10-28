import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_visual_kit.dart';

enum ShareNetwork { whatsapp, facebook, instagram, tiktok, x, threads, telegram, linkedin, pinterest, reddit, email }

String shareLabel(ShareNetwork n) => switch(n) {
  ShareNetwork.whatsapp=>'WhatsApp', ShareNetwork.facebook=>'Facebook',
  ShareNetwork.instagram=>'Instagram', ShareNetwork.tiktok=>'TikTok',
  ShareNetwork.x=>'X', ShareNetwork.threads=>'Threads',
  ShareNetwork.telegram=>'Telegram', ShareNetwork.linkedin=>'LinkedIn',
  ShareNetwork.pinterest=>'Pinterest', ShareNetwork.reddit=>'Reddit',
  ShareNetwork.email=>'Correo',
};

IconData shareIcon(ShareNetwork n) => switch(n) {
  ShareNetwork.whatsapp=>Icons.chat_outlined, ShareNetwork.facebook=>Icons.people_outline,
  ShareNetwork.instagram=>Icons.camera_alt_outlined, ShareNetwork.tiktok=>Icons.music_note_outlined,
  ShareNetwork.x=>Icons.alternate_email, ShareNetwork.threads=>Icons.forum_outlined,
  ShareNetwork.telegram=>Icons.send_outlined, ShareNetwork.linkedin=>Icons.work_outline,
  ShareNetwork.pinterest=>Icons.push_pin_outlined, ShareNetwork.reddit=>Icons.groups_outlined,
  ShareNetwork.email=>Icons.email_outlined,
};

bool shareByCopy(ShareNetwork n)=>n==ShareNetwork.instagram||
    n==ShareNetwork.tiktok||n==ShareNetwork.threads;

Uri shareDestination(ShareNetwork n,String link,String title) {
  final message='Te invito a '+title;
  switch(n) {
    case ShareNetwork.whatsapp:return Uri.https('wa.me','/',{'text':message+'\n'+link});
    case ShareNetwork.facebook:return Uri.https('www.facebook.com','/sharer/sharer.php',{'u':link});
    case ShareNetwork.telegram:return Uri.https('t.me','/share/url',{'url':link,'text':message});
    case ShareNetwork.x:return Uri.https('twitter.com','/intent/tweet',{'url':link,'text':message});
    case ShareNetwork.linkedin:return Uri.https('www.linkedin.com','/sharing/share-offsite/',{'url':link});
    case ShareNetwork.pinterest:return Uri.https('www.pinterest.com','/pin/create/button/',{'url':link,'description':title});
    case ShareNetwork.reddit:return Uri.https('www.reddit.com','/submit',{'url':link,'title':title});
    case ShareNetwork.email:return Uri(scheme:'mailto',query:'subject='+Uri.encodeComponent(title)+'&body='+Uri.encodeComponent(message+'\n'+link));
    case ShareNetwork.instagram:return Uri.https('www.instagram.com','/');
    case ShareNetwork.tiktok:return Uri.https('www.tiktok.com','/');
    case ShareNetwork.threads:return Uri.https('www.threads.net','/');
  }
}

/// Contacto de ayuda exclusivo del evento, nunca un número global fijo.
Uri? helpWhatsappLink(String? raw,String eventName,String venue) {
  var number=raw?.trim()??'';
  if(number.isEmpty)return null;
  final uri=Uri.tryParse(number);
  if(uri!=null&&uri.hasScheme) {
    if(uri.scheme!='https'||!{'wa.me','api.whatsapp.com','www.api.whatsapp.com',
      'whatsapp.com','www.whatsapp.com'}.contains(uri.host.toLowerCase()))return null;
    number=uri.host.toLowerCase()=='wa.me'
      ?(uri.pathSegments.where((x)=>x.isNotEmpty).firstOrNull??'')
      :(uri.queryParameters['phone']??'');
  }
  number=number.replaceAll(RegExp(r'[\s()+-]'),'');
  if(RegExp(r'^3[0-9]{9}$').hasMatch(number))number='57'+number;
  if(!RegExp(r'^[0-9]{8,15}$').hasMatch(number))return null;
  final question='Hola, tengo una duda sobre '+eventName+
      (venue.isEmpty?'':' en '+venue)+'. ¿Podrían ayudarme?';
  return Uri.https('wa.me','/'+number,{'text':question});
}

/// Usa primero el WhatsApp del evento y después el móvil de su sucursal.
/// Nunca utiliza un contacto fijo de BarLytics ni de otra sede.
Uri? eventWhatsappHelpLink(Map<String,dynamic> event){
  final title=event['titulo']?.toString()??'Evento';
  final venue=event['sucursal']?.toString()??'';
  final configured=helpWhatsappLink(event['whatsapp']?.toString(),title,venue);
  if(configured!=null)return configured;
  final digits=(event['telefono']?.toString().trim()??'')
    .replaceAll(RegExp(r'[\s()+-]'),'');
  if(!RegExp(r'^(?:57)?3[0-9]{9}$').hasMatch(digits))return null;
  return helpWhatsappLink(digits,title,venue);
}

class EventShareSheet extends StatelessWidget {
  const EventShareSheet({super.key,required this.event,required this.link});
  final Map<String,dynamic> event;
  final String link;
  EventPagePalette get colors=>EventPagePalette.fromHex(
    event['colorPrimario']?.toString(),event['colorFondo']?.toString(),
    event['colorTexto']?.toString(),event['colorTarjeta']?.toString(),
    event['colorBorde']?.toString(),event['colorCarta']?.toString());
  Color readable(Color text,Color surface)=>
    EventPagePalette.readable(text,surface);
  void notify(BuildContext context,String value) {
    if(context.mounted)ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(
        backgroundColor:colors.surface,
        behavior:SnackBarBehavior.floating,
        content:Text(value,style:TextStyle(color:colors.onSurface))));
  }
  Future<bool> copy(BuildContext context)async{
    try{await Clipboard.setData(ClipboardData(text:link));
      notify(context,'Enlace copiado');return true;
    }catch(_){notify(context,'No fue posible copiar');return false;}
  }
  Future<void> open(BuildContext context,Uri target,String label)async {
    try{
      if(!await launchUrl(target,mode:LaunchMode.externalApplication)) {
        notify(context,'No se pudo abrir '+label);
      }
    }catch(_){notify(context,'No se pudo abrir '+label);}
  }
  Future<void> share(BuildContext context,ShareNetwork network)async {
    if(shareByCopy(network)){
      if(!await copy(context))return;
      if(!context.mounted)return;
    }
    await open(context,shareDestination(network,link,
      event['titulo']?.toString()??'Evento'),shareLabel(network));
  }
  @override Widget build(BuildContext context){
    final p=colors;
    final fg=readable(p.text,p.surface);
    final itemFg=readable(p.text,p.surfaceSoft);
    final border=EventPagePalette.contrast(p.border,p.surfaceSoft)<1.4
      ?itemFg.withOpacity(.3):p.border;
    final title=event['titulo']?.toString()??'Evento';
    final venue=event['sucursal']?.toString()??'';
    final help=eventWhatsappHelpLink(event);
    return Container(
      constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.86),
      decoration:BoxDecoration(color:p.surface,
        borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),
        border:Border.all(color:p.border)),
      child:SingleChildScrollView(
        padding:EdgeInsets.fromLTRB(22,13,22,MediaQuery.paddingOf(context).bottom+22),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Center(child:Container(width:48,height:4,decoration:BoxDecoration(
            color:p.accentOnSurface,borderRadius:BorderRadius.circular(4)))),
          const SizedBox(height:22),
          Text('Compartir este evento',style:TextStyle(color:fg,
            fontSize:23,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          Text(title+(venue.isEmpty?'':' · '+venue),
            maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:fg.withOpacity(.8))),
          const SizedBox(height:16),
          Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
            color:p.surfaceSoft,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:border)),
            child:SelectableText(link,style:TextStyle(color:itemFg,fontSize:12))),
          const SizedBox(height:12),
          FilledButton.icon(onPressed:()=>copy(context),
            icon:const Icon(Icons.copy_outlined),label:const Text('Copiar enlace'),
            style:FilledButton.styleFrom(backgroundColor:p.accent,
              foregroundColor:p.onAccent,padding:const EdgeInsets.all(15))),
          const SizedBox(height:22),
          Text('Compartir en redes sociales',style:TextStyle(
            color:fg,fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:11),
          LayoutBuilder(builder:(context,box){
            final count=box.maxWidth>=500?4:box.maxWidth>=330?3:2;
            final width=(box.maxWidth-9*(count-1))/count;
            return Wrap(spacing:9,runSpacing:9,children:[
              for(final n in ShareNetwork.values)
                SizedBox(width:width,child:Material(
                  color:p.surfaceSoft,borderRadius:BorderRadius.circular(12),
                  child:InkWell(onTap:()=>share(context,n),
                    borderRadius:BorderRadius.circular(12),
                    child:Container(padding:const EdgeInsets.symmetric(
                      vertical:14,horizontal:4),
                      decoration:BoxDecoration(border:Border.all(color:border),
                        borderRadius:BorderRadius.circular(12)),
                      child:Column(children:[
                        Icon(shareIcon(n),color:itemFg,size:22),
                        const SizedBox(height:7),
                        Text(shareLabel(n),maxLines:1,overflow:TextOverflow.ellipsis,
                          style:TextStyle(color:itemFg,fontSize:11,
                            fontWeight:FontWeight.w800)),
                      ]),
                    ),
                  ),
                )),
            ]);
          }),
          const SizedBox(height:12),
          Text('Instagram, TikTok y Threads: copiamos el enlace y abrimos la red para pegarlo.',
            style:TextStyle(color:fg.withOpacity(.75),fontSize:12)),
          if(help!=null)...[
            const SizedBox(height:18),
            Divider(color:p.border),
            OutlinedButton.icon(
              onPressed:()=>open(context,help,'WhatsApp'),
              icon:const Icon(Icons.support_agent_outlined),
              label:const Text('¿Dudas? Escríbenos por WhatsApp'),
              style:OutlinedButton.styleFrom(foregroundColor:fg,
                side:BorderSide(color:p.border),
                padding:const EdgeInsets.symmetric(vertical:13))),
          ],
        ]),
      ),
    );
  }
}

Future<void> showEventShareSheet(
    BuildContext context,Map<String,dynamic> event,String link)=>
  showModalBottomSheet<void>(context:context,isScrollControlled:true,
    useSafeArea:true,showDragHandle:false,
    backgroundColor:Colors.transparent,
    constraints:const BoxConstraints(maxWidth:660),
    builder:(context){
      final p=EventPagePalette.fromHex(
        event['colorPrimario']?.toString(),event['colorFondo']?.toString(),
        event['colorTexto']?.toString(),event['colorTarjeta']?.toString(),
        event['colorBorde']?.toString(),event['colorCarta']?.toString());
      return EventPaletteScope(
        palette:p,
        child:Theme(
          data:(p.surface.computeLuminance()>.18
            ?ThemeData.light(useMaterial3:true)
            :ThemeData.dark(useMaterial3:true)).copyWith(
            colorScheme:p.surface.computeLuminance()>.18
              ?ColorScheme.light(primary:p.accent,onPrimary:p.onAccent,
                  surface:p.surface,onSurface:p.onSurface)
              :ColorScheme.dark(primary:p.accent,onPrimary:p.onAccent,
                  surface:p.surface,onSurface:p.onSurface),
            textTheme:Theme.of(context).textTheme.apply(
              bodyColor:p.onSurface,displayColor:p.onSurface),
          ),
          child:EventShareSheet(event:event,link:link),
        ),
      );
    });
