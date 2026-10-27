import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_visual_kit.dart';
import 'event_photo_viewer.dart';

/// Landing pública real (sin datos demostrativos ni dependencias del shell privado).
/// Toda la información proviene del evento, sucursal, mesas y catálogo del API.
class EventPublicLanding extends StatefulWidget {
  const EventPublicLanding({
    super.key,
    required this.event,
    required this.selectedTable,
    required this.seats,
    required this.busy,
    required this.name,
    required this.email,
    required this.phone,
    required this.onSelectTable,
    required this.onSeatsChanged,
    required this.onBook,
    required this.onShare,
    required this.onRefresh,
  });
  final Map<String,dynamic> event;
  final int? selectedTable;
  final int seats;
  final bool busy;
  final TextEditingController name,email,phone;
  final ValueChanged<int> onSelectTable,onSeatsChanged;
  final void Function(List<int>) onBook;
  final VoidCallback onShare;
  final Future<void> Function() onRefresh;

  @override
  State<EventPublicLanding> createState()=>_EventPublicLandingState();
}

class _EventPublicLandingState extends State<EventPublicLanding> {
  final _bookingKey=GlobalKey();
  final _menuKey=GlobalKey();
  final _locationKey=GlobalKey();
  final _galleryKey=GlobalKey();
  final _posterKey=GlobalKey();
  final chosenChairs=<int>{};
  bool automatic=false;
  bool get bySeat=>widget.event['modoReserva']=='PUESTOS';
  bool get selectSeats=>bySeat&&widget.event['seleccionarSillas']==true;
  EventPagePalette get palette=>EventPagePalette.fromHex(
    getText('colorPrimario'),getText('colorFondo'));
  Color get brand=>palette.accent;
  Color get onBrand=>palette.onAccent;
  Color get backdrop=>palette.canvas;
  List<int> get usedSeats{
   final list=tables.where((t)=>number(t['id'])==widget.selectedTable);
   if(list.isEmpty)return [];
   return (list.first['sillasOcupadas'] as List? ??[]).map(number).toList();
  }
  int get automaticMax=>tables.fold<int>(0,(n,t){
   final free=number(t['disponibles']);
   return free>n?free:n;
  });
  void reserve(){
   if(selectSeats&&!automatic&&widget.selectedTable!=null &&
     chosenChairs.length!=widget.seats){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
     content:Text('Selecciona '+widget.seats.toString()+' sillas')));
    return;
   }
   final chairs=chosenChairs.toList()..sort();
   widget.onBook(automatic?[]:chairs);
  }


  String getText(String key,[String fallback='']) =>
    widget.event[key]?.toString() ?? fallback;

  List<Map<String,dynamic>> get tables =>
    (widget.event['mesas'] as List? ?? [])
      .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();

  /// La API publica devuelve exclusivamente los productos asociados en
  /// commerce.evento_productos. Las hojas no contienen datos demostrativos.
  List<Map<String,dynamic>> get products {
    final rows=(widget.event['carta'] as List? ?? [])
      .whereType<Map>().map((e)=>Map<String,dynamic>.from(e))
      .where((p)=>number(p['id'])>0 &&
        (p['nombre']?.toString().trim().isNotEmpty??false)).toList();
    rows.sort((a,b){
      final orderA=number(a['orden']),orderB=number(b['orden']);
      final compare=orderA.compareTo(orderB);
      return compare!=0?compare:number(a['id']).compareTo(number(b['id']));
    });
    return rows;
  }

  List<String> get venue =>
    (widget.event['fotosLugar'] as List? ?? []).whereType<String>().toList();

  int number(Object? raw) => int.tryParse(raw?.toString()??'')??0;
  double price(Object? raw) => double.tryParse(raw?.toString()??'')??0;
  String currency(Object? raw) => NumberFormat.currency(
    locale:'es_CO',symbol:'COP ',decimalDigits:0).format(price(raw));
  String time(Object? raw){
    final v=DateTime.tryParse(raw?.toString()??'');
    if(v==null)return 'Horario por confirmar';
    return DateFormat('EEE d MMM yyyy · h:mm a','es_CO').format(v);
  }

  void jump(GlobalKey key){
    final c=key.currentContext;
    if(c!=null)Scrollable.ensureVisible(c,duration:const Duration(milliseconds:450),
      curve:Curves.easeInOut,alignment:.06);
  }

  Future<void> openMap()async{
    final uri=Uri.tryParse(getText('ubicacionGoogleMaps'));
    if(uri==null||uri.scheme!='https')return;
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=940;
    final bg=venue.isNotEmpty?venue.first:widget.event['imagen'];
    final content=Column(children:[
      _hero(bg,wide),
      Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1320),
        child:Padding(padding:EdgeInsets.symmetric(horizontal:wide?24:14,vertical:20),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            _opening(wide),
            const SizedBox(height:17),
            _intro(wide),
            const SizedBox(height:17),
            _bookingArea(wide),
            const SizedBox(height:17),
            _catalog(),
            const SizedBox(height:27),
            _footer(wide),
          ])))),
    ]);
    return EventPaletteScope(
      palette:palette,
      child:Theme(
      data:ThemeData.dark(useMaterial3:true).copyWith(
        colorScheme:ColorScheme.dark(primary:brand,
          onPrimary:onBrand,surface:palette.surface),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,fillColor:palette.surfaceSoft,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(11)),
          enabledBorder:OutlineInputBorder(
            borderRadius:BorderRadius.circular(11),
            borderSide:BorderSide(color:palette.border)),
        ),
      ),
      child:Scaffold(
        backgroundColor:backdrop,
        // La fotografía permanece anclada al viewport; únicamente se
        // desplaza el contenido del evento, incluso en pantallas móviles.
        body:Stack(children:[
          Positioned.fill(child:RepaintBoundary(
            child:eventPhoto(bg)==null
              ?ColoredBox(color:backdrop)
              :Image(image:eventPhoto(bg)!,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>ColoredBox(color:backdrop)),
          )),
          Positioned.fill(child:ColoredBox(
            color:palette.heroShade.withOpacity(.73))),
          RefreshIndicator(onRefresh:widget.onRefresh,
            child:ListView(children:[content])),
        ]),
        bottomNavigationBar:wide?null:SafeArea(top:false,
          child:Container(
            padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:palette.surface,
              border:Border(top:BorderSide(color:palette.border))),
            child:FilledButton.icon(
              onPressed:()=>jump(_bookingKey),
              icon:const Icon(Icons.confirmation_number_outlined),
              label:Text(bySeat?'Reservar puestos':'Reservar mesa'),
              style:FilledButton.styleFrom(backgroundColor:brand,
                foregroundColor:onBrand,
                padding:const EdgeInsets.all(15))),
          )),
      ),
      ),
    );
  }

  Widget _hero(Object? image,bool wide) => Container(
    constraints:BoxConstraints(minHeight:wide?490:490),
    child:Stack(children:[
      // La fotografía está en el fondo fijo de toda la pantalla.
      // El encabezado deja verla sin duplicarla ni desplazarla.
      const Positioned.fill(child:ColoredBox(color:Colors.transparent)),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(
          begin:Alignment.centerLeft,end:Alignment.centerRight,
          colors:[palette.heroShade.withOpacity(.57),
            palette.heroShade.withOpacity(.35),
            palette.heroShade.withOpacity(.16),
            Colors.transparent])))),
      Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1320),
        child:Padding(
          padding:EdgeInsets.symmetric(horizontal:wide?27:19,vertical:18),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _nav(wide),
            SizedBox(height:wide?63:48),
            EventPill(icon:Icons.local_activity_outlined,
              label:'EVENTO ESPECIAL · RESERVAS ABIERTAS',
              color:EventColors.gold),
            const SizedBox(height:14),
            ConstrainedBox(constraints:BoxConstraints(maxWidth:wide?840:480),
              child:Text(getText('titulo','Evento especial'),
                maxLines:3,overflow:TextOverflow.ellipsis,
                style:TextStyle(
                  fontWeight:FontWeight.w900,height:1.02,
                  letterSpacing:-1,
                  color:EventColors.text,fontSize:wide?56:38))),
            const SizedBox(height:13),
            if(getText('descripcion').isNotEmpty)
              ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),
                child:Text(getText('descripcion'),
                  maxLines:3,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:EventColors.text,
                    fontSize:15,height:1.55))),
            const SizedBox(height:19),
            Wrap(spacing:9,runSpacing:9,children:[
              EventPill(icon:Icons.event_outlined,label:time(widget.event['inicio'])),
              EventPill(icon:Icons.schedule_outlined,
                label:'Hasta '+time(widget.event['fin'])),
              EventPill(icon:Icons.location_on_outlined,
                label:getText('sucursal','Lugar del evento')),
              EventPill(icon:Icons.sell_outlined,
                label:price(widget.event['precio'])==0?'Entrada gratis':
                  (widget.event['precioPorPuesto']==true?'Por puesto · ':'Por mesa · ')+
                  currency(widget.event['precio']),color:EventColors.gold),
            ]),
            const SizedBox(height:20),
            Wrap(spacing:10,runSpacing:10,children:[
              FilledButton.icon(onPressed:()=>jump(_bookingKey),
                icon:const Icon(Icons.event_seat_outlined),
                label:const Text('Reservar ahora'),
                style:FilledButton.styleFrom(backgroundColor:brand,
                  foregroundColor:onBrand,
                  padding:const EdgeInsets.symmetric(horizontal:25,vertical:17))),
              OutlinedButton.icon(onPressed:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
                icon:const Icon(Icons.directions_outlined),
                label:const Text('Cómo llegar')),
              OutlinedButton.icon(onPressed:widget.onShare,
                icon:const Icon(Icons.share_outlined),
                label:const Text('Compartir')),
            ]),
            const SizedBox(height:26),
          ]),
        ),
      )),
    ]),
  );

  Widget _nav(bool wide) => Row(children:[
    Container(width:82,height:82,clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(color:palette.surfaceSoft,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:EventColors.border)),
      child:eventPhoto(widget.event['logo'])==null
        ?Icon(Icons.storefront_outlined,color:brand,size:40)
        :EventArtwork(source:widget.event['logo'],height:82,width:82,
          fit:BoxFit.cover,borderRadius:0)),
    const SizedBox(width:11),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(getText('sucursal','Establecimiento'),
        softWrap:true,
        style:TextStyle(color:EventColors.text,
          fontWeight:FontWeight.w900,fontSize:wide?28:22)),
      const Text('Eventos y reservas',
        style:TextStyle(color:EventColors.muted,fontSize:12)),
    ])),
    if(wide)...[
      if(eventPhoto(widget.event['imagen'])!=null)
        TextButton(onPressed:()=>jump(_posterKey),child:const Text('Afiche')),
      TextButton(onPressed:()=>jump(_galleryKey),child:const Text('El lugar')),
      TextButton(onPressed:()=>jump(_menuKey),child:const Text('La carta')),
      TextButton(onPressed:()=>jump(_locationKey),child:const Text('Ubicación')),
      const SizedBox(width:8),
      OutlinedButton.icon(onPressed:()=>jump(_bookingKey),
        icon:const Icon(Icons.event_seat_outlined,size:17),
        label:const Text('Reservar ahora')),
    ]else IconButton(onPressed:widget.onShare,
      tooltip:'Compartir evento',
      icon:Icon(Icons.share_outlined,color:brand)),
  ]);


 Widget _poster(bool wide){
   final image=widget.event['imagen'];
   final expand=()=>showEventPhotoViewer(context,
     images:[image],labels:['Afiche oficial · '+getText('titulo')]);
   return EventPanel(child:Column(
     key:_posterKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.campaign_outlined,
         title:'Afiche oficial del evento',
         subtitle:'La portada principal del evento, también en redes sociales.',
         trailing:wide?OutlinedButton.icon(
           onPressed:expand,icon:const Icon(Icons.fullscreen),
           label:const Text('Ver completo')):null),
       const SizedBox(height:16),
       LayoutBuilder(builder:(context,layout){
         final photo=InkWell(
           onTap:expand,borderRadius:BorderRadius.circular(15),
           child:Stack(children:[
             Container(
               decoration:BoxDecoration(
                 color:palette.canvas,
                  border:Border.all(color:palette.border),
                 borderRadius:BorderRadius.circular(15)),
               child:EventArtwork(
                 source:image,width:double.infinity,
                 height:MediaQuery.sizeOf(context).width>=940?690:500,
                  fit:BoxFit.contain)),
             Positioned(bottom:12,right:12,child:Container(
               padding:const EdgeInsets.all(9),
               decoration:BoxDecoration(color:palette.surface,
                  borderRadius:BorderRadius.circular(11)),
               child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(Icons.zoom_in,color:brand),
                  SizedBox(width:6),
                 Text('Ampliar afiche',
                   style:TextStyle(color:EventColors.text,fontSize:12)),
               ]))),
           ]),
         );
         if(!wide)return photo;
         return Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
           Expanded(flex:6,child:photo),const SizedBox(width:23),
           Expanded(flex:4,child:Column(
             crossAxisAlignment:CrossAxisAlignment.start,children:[
               const EventPill(icon:Icons.star_outline,
                 label:'AFICHE OFICIAL',color:EventColors.gold),
               const SizedBox(height:16),
               Text(getText('titulo'),style:const TextStyle(
                 color:EventColors.text,fontWeight:FontWeight.w900,
                 fontSize:29,height:1.1)),
               const SizedBox(height:17),
               EventMetric(icon:Icons.calendar_month_outlined,
                 label:'Fecha',value:time(widget.event['inicio'])),
               const SizedBox(height:13),
               EventMetric(icon:Icons.location_on_outlined,
                 label:'Lugar',value:getText('sucursal')),
               const SizedBox(height:19),
               const Text('Acércate para leer todos los detalles del afiche.',
                 style:TextStyle(color:EventColors.muted,
                   fontSize:13,height:1.5)),
               const SizedBox(height:13),
               FilledButton.icon(onPressed:expand,
                 icon:const Icon(Icons.fullscreen_outlined),
                 style:FilledButton.styleFrom(
                   backgroundColor:brand,
                    foregroundColor:onBrand),
                 label:const Text('Abrir afiche')),
             ],
           )),
         ]);
       }),
     ],
   ));
 }

 Widget _opening(bool wide){
  final poster=eventPhoto(widget.event['imagen'])==null?null:_poster(false);
  final intro=EventPanel(child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    const EventSectionHeading(icon:Icons.auto_awesome_outlined,
      title:'Sobre el evento',subtitle:'Toda la información de esta experiencia'),
    const SizedBox(height:16),
    Text(getText('descripcion','Una experiencia especial para compartir.'),
      style:const TextStyle(color:EventColors.text,fontSize:15,height:1.75)),
    const SizedBox(height:17),
    Wrap(spacing:9,runSpacing:9,children:[
      EventPill(icon:Icons.event_outlined,label:time(widget.event['inicio'])),
      EventPill(icon:Icons.place_outlined,label:getText('sucursal')),
      EventPill(icon:Icons.payments_outlined,
        label:currency(widget.event['precio']),color:EventColors.gold),
    ]),
   ],
  ));
  if(poster==null)return intro;
  if(!wide)return Column(children:[poster,const SizedBox(height:13),intro]);
  return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:7,child:poster),
    const SizedBox(width:16),
    Expanded(flex:5,child:intro),
  ]);
 }

 Widget _intro(bool wide) {
   final photos=EventPanel(child:Column(
     key:_galleryKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.collections_outlined,
         title:'Conoce el lugar',
         subtitle:'Fotografías reales del establecimiento',
         trailing:venue.isEmpty?null:
           Icon(Icons.zoom_in,color:brand)),
       const SizedBox(height:15),
       if(venue.isEmpty)Container(height:220,alignment:Alignment.center,
         decoration:BoxDecoration(color:palette.surfaceSoft,
            borderRadius:BorderRadius.circular(12)),
         child:const Text('Próximamente: fotos del lugar',
           style:TextStyle(color:EventColors.muted)))
       else LayoutBuilder(builder:(context,layout){
         final columns=venue.length>1&&layout.maxWidth>=500?2:1;
         final width=(layout.maxWidth-(columns-1)*10)/columns;
         return Wrap(spacing:10,runSpacing:10,children:[
           for(var i=0;i<venue.length;i++)
             SizedBox(width:width,child:InkWell(
               borderRadius:BorderRadius.circular(12),
               onTap:()=>showEventPhotoViewer(context,
                 images:venue.cast<Object?>(),
                 labels:List.generate(venue.length,
                   (j)=>'Fotografía del lugar '+(j+1).toString()),
                 initialIndex:i),
               child:Stack(children:[
                 EventArtwork(source:venue[i],width:width,
                   height:venue.length==1?405:venue.length==2?320:215),
                 const Positioned(bottom:9,right:9,
                   child:Icon(Icons.zoom_in,color:EventColors.text,size:27)),
               ]),
             )),
         ]);
       }),
       if(venue.isNotEmpty)...[
         const SizedBox(height:14),
         OutlinedButton.icon(
           onPressed:()=>showEventPhotoViewer(context,
             images:venue.cast<Object?>(),
             labels:List.generate(venue.length,
               (i)=>'Fotografía del lugar '+(i+1).toString())),
           icon:const Icon(Icons.fullscreen_outlined),
           label:const Text('Ver galería en pantalla completa')),
       ],
     ]));
   final mapPreview=venue.isNotEmpty?venue.first:widget.event['imagen'];
   final place=EventPanel(child:Column(
     key:_locationKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       const EventSectionHeading(icon:Icons.location_on_outlined,
         title:'Nuestra ubicación',
         subtitle:'Encuentra cómo llegar al establecimiento.'),
       const SizedBox(height:14),
       _locationPhoto(mapPreview),
       const SizedBox(height:17),
       _locationInfo(),
     ]));
   if(!wide)return Column(children:[
     photos,const SizedBox(height:12),place,
   ]);
   // Galería y mapa con enlaces sociales en columnas equilibradas.
   return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(flex:7,child:photos),
     const SizedBox(width:16),
     Expanded(flex:5,child:place),
   ]);
 }

 Widget _locationPhoto(Object? image) => InkWell(
   onTap:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
   borderRadius:BorderRadius.circular(13),
   child:Stack(children:[
     EventArtwork(source:image,width:double.infinity,
       height:MediaQuery.sizeOf(context).width>=940?250:200,
       emptyIcon:Icons.map_outlined),
     Positioned.fill(child:Container(
       decoration:BoxDecoration(
         borderRadius:BorderRadius.circular(13),
         gradient:const LinearGradient(
           begin:Alignment.bottomCenter,end:Alignment.topCenter,
           colors:[Color(0xE3061925),Colors.transparent])))),
     Positioned(left:12,bottom:12,right:12,child:Row(children:[
       Icon(Icons.location_on,color:brand),
       const SizedBox(width:7),
       const Expanded(child:Text('Vista del lugar · Abrir en Google Maps',
         style:TextStyle(color:EventColors.text,
           fontWeight:FontWeight.w800,fontSize:12))),
       const Icon(Icons.open_in_new,color:EventColors.text,size:17),
     ])),
   ]),
 );

 Widget _locationInfo()=>Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(getText('sucursal','Lugar del evento'),
       style:const TextStyle(color:EventColors.text,
         fontWeight:FontWeight.w800,fontSize:18)),
     const SizedBox(height:7),
     Text(getText('direccion','Dirección del lugar'),
       style:const TextStyle(color:EventColors.muted,fontSize:13)),
     const SizedBox(height:16),
     OutlinedButton.icon(
       onPressed:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
       icon:const Icon(Icons.directions_outlined),
       label:const Text('Ver ubicación en Google Maps')),
     const SizedBox(height:23),
     const Text('Síguenos en redes sociales',
       style:TextStyle(color:EventColors.text,
        fontWeight:FontWeight.w800,fontSize:14)),
     const SizedBox(height:11),
     _socialLinks(),
   ],
 );


 Widget _socialLinks(){
  final items=<({String label,String url,IconData icon})>[
   if(getText('instagram').isNotEmpty)
    (label:'Instagram',url:getText('instagram'),icon:Icons.camera_alt_outlined),
   if(getText('facebook').isNotEmpty)
    (label:'Facebook',url:getText('facebook'),icon:Icons.people_alt_outlined),
   if(getText('tiktok').isNotEmpty)
    (label:'TikTok',url:getText('tiktok'),icon:Icons.music_note_outlined),
   if(getText('whatsapp').isNotEmpty)
    (label:'WhatsApp',url:getText('whatsapp'),icon:Icons.chat_outlined),
  ];
  if(items.isEmpty)return const Text('Próximamente enlaces sociales del lugar',
   style:TextStyle(color:EventColors.muted,fontSize:12));
  return Wrap(spacing:9,runSpacing:9,children:[
   for(final item in items)
    OutlinedButton.icon(
     onPressed:()async{
      final link=Uri.tryParse(item.url);
      if(link!=null&&link.scheme=='https')
       await launchUrl(link,mode:LaunchMode.externalApplication);
     },
     icon:Icon(item.icon,size:17,color:brand),
     label:Text(item.label)),
  ]);
 }

 Widget _bookingArea(bool wide){
   final content=EventPanel(child:Column(
     key:_bookingKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.table_restaurant_outlined,
         title:bySeat?'Reserva por puestos':'Reserva tu mesa',
         subtitle:bySeat?'Reserva varios puestos o asigna mesa automáticamente.':'La mesa se reserva completa.'),
       const SizedBox(height:14),
       Wrap(spacing:12,runSpacing:9,children:[
         const EventPill(icon:Icons.circle,color:EventColors.success,
           label:'Disponible'),
         EventPill(icon:Icons.circle,color:EventColors.warning,label:'Apartada'),
       ]),
       const SizedBox(height:14),
       if(bySeat&&automaticMax>0)...[
         SwitchListTile.adaptive(
          value:automatic,contentPadding:EdgeInsets.zero,
          title:const Text('Asignar mesa automáticamente',
           style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
          subtitle:const Text('Elige cuántos puestos quieres; encontraremos mesa disponible.'),
          onChanged:(v)=>setState((){
           automatic=v;chosenChairs.clear();
           if(v)widget.onSelectTable(-1);
          })),
         const SizedBox(height:8),
       ],
       if(tables.isEmpty)
         const Padding(padding:EdgeInsets.all(32),
           child:Center(child:Text('Por ahora no hay mesas habilitadas.',
             style:TextStyle(color:EventColors.muted))))
       else GridView.builder(
         itemCount:tables.length,
         shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
         gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
           maxCrossAxisExtent:215,mainAxisExtent:184,
           crossAxisSpacing:10,mainAxisSpacing:10),
         itemBuilder:(context,index){
           final t=tables[index],id=number(t['id']);
           final available=t['estado']=='DISPONIBLE';
           final chosen=widget.selectedTable==id&&!automatic;
           final capacity=number(t['capacidad'])>0?number(t['capacidad']):6;
           final free=number(t['disponibles']);
           return InkWell(
             onTap:available?()=>setState((){
              automatic=false;chosenChairs.clear();widget.onSelectTable(id);
             }):null,
             borderRadius:BorderRadius.circular(14),
             child:Container(clipBehavior:Clip.antiAlias,
               decoration:BoxDecoration(
                 color:chosen?brand.withOpacity(.20):palette.surfaceSoft,
                 borderRadius:BorderRadius.circular(14),
                 border:Border.all(
                   width:chosen?2:1,
                   color:chosen?brand:EventColors.border)),
               child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                 Expanded(child:Stack(children:[
                   Positioned.fill(child:EventArtwork(source:t['foto'],
                     height:115,borderRadius:0,emptyIcon:Icons.table_restaurant)),
                   if(eventPhoto(t['foto'])!=null)
                     Positioned(bottom:6,right:6,child:IconButton.filledTonal(
                       tooltip:'Ampliar foto de la mesa',
                       onPressed:()=>showEventPhotoViewer(context,
                         images:[t['foto']],
                         labels:['Mesa '+(t['numero']??id).toString()]),
                       icon:const Icon(Icons.zoom_in,size:19))),
                   if(chosen)Positioned(right:8,top:8,
                     child:CircleAvatar(radius:15,backgroundColor:brand,
                       child:Icon(Icons.check,color:onBrand,size:18))),
                   if(!available)Positioned.fill(child:Container(color:Colors.black45)),
                 ])),
                 Padding(padding:const EdgeInsets.fromLTRB(10,8,10,10),
                   child:Row(children:[
                     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                       Text('Mesa '+(t['numero']??id).toString(),
                         style:const TextStyle(color:EventColors.text,
                           fontWeight:FontWeight.w800,fontSize:13)),
                       const SizedBox(height:4),
                       Text(bySeat?
                         free.toString()+' de '+capacity.toString()+' puestos libres':
                         capacity.toString()+' puestos',
                         style:const TextStyle(color:EventColors.muted,fontSize:11)),
                     ])),
                     Icon(available?Icons.check_circle:Icons.lock_outline,
                       color:available?EventColors.success:EventColors.warning,size:17),
                   ])),
               ]),
             ),
           );
         },
       ),
     ]));
   if(!wide)return Column(children:[
     content,const SizedBox(height:13),_reservationSummary(),
   ]);
   return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(flex:7,child:content),
     const SizedBox(width:13),
     Expanded(flex:3,child:_reservationSummary()),
   ]);
 }

 Widget _reservationSummary(){
   final selected=tables.where((t)=>number(t['id'])==widget.selectedTable).toList();
   final t=selected.isEmpty?null:selected.first;
   final capacity=automatic?automaticMax:
     t==null?0:bySeat?number(t['disponibles']):
     number(t['capacidad'])>0?number(t['capacidad']):6;
   final unit=price(widget.event['precio']);
   final total=widget.event['precioPorPuesto']==true
     ?unit*widget.seats:unit;
   return EventPanel(child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
       const EventSectionHeading(icon:Icons.confirmation_number_outlined,
         title:'Tu reserva',subtitle:'Completa tus datos para confirmar'),
       const SizedBox(height:15),
       if(t!=null)...[
         Row(children:[
           InkWell(
             onTap:eventPhoto(t['foto'])==null?null:
               ()=>showEventPhotoViewer(context,
                 images:[t['foto']],
                 labels:['Mesa '+(t['numero']??'').toString()]),
             child:Stack(children:[
               EventArtwork(source:t['foto'],width:94,height:74),
               if(eventPhoto(t['foto'])!=null)
                 const Positioned(right:3,bottom:3,child:Icon(
                   Icons.zoom_in,color:EventColors.text,size:18)),
             ]),
           ),
           const SizedBox(width:11),
           Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
             Text('Mesa '+(t['numero']??'').toString(),
               style:const TextStyle(color:EventColors.text,
                 fontWeight:FontWeight.w800)),
             const SizedBox(height:5),
             Text(capacity.toString()+' puestos disponibles',
               style:const TextStyle(color:EventColors.success,fontSize:12)),
           ])),
         ]),
       ]else if(automatic&&bySeat)
         const EventPill(icon:Icons.auto_awesome,
          label:'La mesa se asignará automáticamente')
       else const EventPill(icon:Icons.touch_app_outlined,
         label:'Selecciona una mesa o asignación automática'),
       const Divider(color:EventColors.border,height:29),
       Row(children:[
         const Expanded(child:Text('Cantidad de puestos',
           style:TextStyle(color:EventColors.muted,fontSize:12))),
         IconButton.outlined(
           onPressed:(widget.selectedTable==null&&!automatic)||widget.seats<=1
             ?null:()=>setState((){
              chosenChairs.clear();widget.onSeatsChanged(widget.seats-1);
             }),
           icon:const Icon(Icons.remove,size:17)),
         Padding(padding:const EdgeInsets.symmetric(horizontal:10),
           child:Text(widget.seats.toString(),
             style:const TextStyle(color:EventColors.text,
               fontWeight:FontWeight.w800,fontSize:17))),
         IconButton.outlined(
           onPressed:(widget.selectedTable==null&&!automatic)||widget.seats>=capacity
             ?null:()=>setState((){
              chosenChairs.clear();widget.onSeatsChanged(widget.seats+1);
             }),
           icon:const Icon(Icons.add,size:17)),
       ]),
       if(selectSeats&&!automatic&&t!=null)...[
         const SizedBox(height:13),
         const Text('Selecciona tus sillas',
           style:TextStyle(color:EventColors.text,fontWeight:FontWeight.w800)),
         const SizedBox(height:10),
         Wrap(spacing:7,runSpacing:8,children:[
           for(var n=1;n<=number(t['capacidad']);n++)
             FilterChip(
               label:Text('Silla '+n.toString()),
               selected:chosenChairs.contains(n),
               avatar:Icon(chosenChairs.contains(n)?Icons.check:
                 Icons.event_seat_outlined,size:16),
               onSelected:usedSeats.contains(n)?null:(isChosen)=>setState((){
                 if(isChosen){
                   if(chosenChairs.length<widget.seats)chosenChairs.add(n);
                 }else{chosenChairs.remove(n);}
               }),
             ),
         ]),
         const SizedBox(height:7),
         Text(chosenChairs.length.toString()+' de '+widget.seats.toString()+' sillas',
           style:TextStyle(color:chosenChairs.length==widget.seats?
             EventColors.success:EventColors.warning,fontSize:12)),
       ],
       const SizedBox(height:12),
       Row(children:[
         Expanded(child:Text(
           widget.event['precioPorPuesto']==true?'Precio por puesto':'Precio por mesa',
           style:const TextStyle(color:EventColors.muted,fontSize:12))),
         Text(currency(unit),style:const TextStyle(color:EventColors.text)),
       ]),
       const Divider(color:EventColors.border,height:23),
       Row(children:[
         const Expanded(child:Text('Total a pagar',style:TextStyle(
           color:EventColors.text,fontWeight:FontWeight.w800))),
         Text(currency(total),style:TextStyle(color:brand,
           fontWeight:FontWeight.w900,fontSize:20)),
       ]),
       const SizedBox(height:20),
       const Text('Tus datos',style:TextStyle(
         color:EventColors.text,fontWeight:FontWeight.w800)),
       const SizedBox(height:11),
       TextField(controller:widget.name,
         textCapitalization:TextCapitalization.words,
         decoration:const InputDecoration(
           labelText:'Nombre completo *',prefixIcon:Icon(Icons.person_outline))),
       const SizedBox(height:10),
       TextField(controller:widget.email,
         keyboardType:TextInputType.emailAddress,
         decoration:const InputDecoration(
           labelText:'Correo electrónico *',prefixIcon:Icon(Icons.email_outlined))),
       const SizedBox(height:10),
       TextField(controller:widget.phone,
         keyboardType:TextInputType.phone,
         decoration:const InputDecoration(
           labelText:'Teléfono / WhatsApp',prefixIcon:Icon(Icons.phone_outlined))),
       const SizedBox(height:16),
       if(widget.event['medioPago']=='MANUAL')
         const Padding(padding:EdgeInsets.only(bottom:12),
           child:Text('La reserva quedará pendiente de aprobación del establecimiento.',
             style:TextStyle(color:EventColors.gold,fontSize:12))),
       SizedBox(width:double.infinity,child:FilledButton.icon(
         onPressed:widget.busy||
            (widget.selectedTable==null&&!automatic)||
            (automatic&&automaticMax<widget.seats)?null:reserve,
         icon:Icon(widget.event['medioPago']=='MERCADOPAGO'
           ?Icons.credit_card:Icons.confirmation_number_outlined),
         label:Text(widget.busy?'Procesando...':
           widget.event['medioPago']=='MERCADOPAGO'?'Reservar y pagar':'Confirmar reserva'),
         style:FilledButton.styleFrom(
           backgroundColor:brand,
           foregroundColor:onBrand,
           padding:const EdgeInsets.symmetric(vertical:17)))),
       const SizedBox(height:9),
       const Center(child:Text('Reserva segura y protegida',
         style:TextStyle(color:EventColors.muted,fontSize:11))),
     ],
   ));
 }


 Widget _catalog(){
   final selected=products;
   if(selected.isEmpty){
     return EventPanel(child:Column(
       key:_menuKey,
       crossAxisAlignment:CrossAxisAlignment.start,children:[
         const EventSectionHeading(icon:Icons.menu_book_outlined,
           title:'La carta del evento',
           subtitle:'El menú se construye con los productos seleccionados por el establecimiento.'),
         const SizedBox(height:16),
         Container(
           width:double.infinity,
           padding:const EdgeInsets.symmetric(horizontal:18,vertical:24),
           decoration:BoxDecoration(
             color:palette.surfaceSoft,
             borderRadius:BorderRadius.circular(13)),
           child:const Row(children:[
             Icon(Icons.restaurant_menu_outlined,color:EventColors.muted,size:26),
             SizedBox(width:13),
             Expanded(child:Text(
               'Todavía no se han seleccionado productos para esta carta.',
               style:TextStyle(color:EventColors.muted,fontSize:13))),
           ]),
         ),
       ],
     ));
   }
   const paper=Color(0xFFF3EBDC);
   const ink=Color(0xFF38291F);
   const detail=Color(0xFF916F4D);
   // Cuatro productos por hoja evitan páginas gigantes vacías.
   final pages=<List<Map<String,dynamic>>>[];
   for(var i=0;i<selected.length;i+=4){
     pages.add(selected.skip(i).take(4).toList());
   }
   Widget menuPage(List<Map<String,dynamic>> items,int index,double width){
     return SizedBox(width:width,child:Stack(children:[
       Positioned.fill(left:6,top:7,right:0,bottom:0,child:DecoratedBox(
         decoration:BoxDecoration(
           color:const Color(0xFFCBB89A),
           borderRadius:BorderRadius.circular(13)))),
       Padding(padding:const EdgeInsets.only(right:6,bottom:7),child:Container(
         padding:const EdgeInsets.fromLTRB(17,18,18,17),
         decoration:BoxDecoration(
           color:paper,
           borderRadius:BorderRadius.circular(13),
           // El lomo decorativo no forma parte del BoxBorder redondeado.
           border:Border.all(color:const Color(0xFFD6BE9F)),
           boxShadow:const [BoxShadow(color:Color(0x38000000),
             blurRadius:20,offset:Offset(0,10))]),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
           mainAxisSize:MainAxisSize.min,children:[
           Row(children:[
             const Icon(Icons.auto_stories_outlined,
               color:detail,size:21),
             const SizedBox(width:8),
             Expanded(child:Text(getText('sucursal','Nuestra carta'),
               maxLines:1,overflow:TextOverflow.ellipsis,
               style:const TextStyle(color:ink,
                 fontWeight:FontWeight.w800,fontSize:12))),
             Text((index+1).toString()+' / '+pages.length.toString(),
               style:const TextStyle(color:detail,fontSize:11)),
           ]),
           const SizedBox(height:11),
           const Text('LA CARTA',
             textAlign:TextAlign.center,
             style:TextStyle(color:ink,fontFamily:'Georgia',
               fontWeight:FontWeight.w900,fontSize:23,letterSpacing:3)),
           const SizedBox(height:3),
           const Text('Una selección para disfrutar',
             textAlign:TextAlign.center,
             style:TextStyle(color:detail,fontSize:12,
               fontStyle:FontStyle.italic)),
           const SizedBox(height:12),
           const Divider(height:1,thickness:1,color:Color(0xFFC9AF8D)),
           const SizedBox(height:7),
           for(final product in items)...[
             Padding(padding:const EdgeInsets.symmetric(vertical:9),
               child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                 InkWell(
                   onTap:eventPhoto(product['imagen'])==null?null:
                     ()=>showEventPhotoViewer(context,
                       images:[product['imagen']],
                       labels:[product['nombre']?.toString()??'Producto']),
                   borderRadius:BorderRadius.circular(10),
                   child:Stack(children:[
                     EventArtwork(source:product['imagen'],
                       width:88,height:82,borderRadius:9,
                       emptyIcon:Icons.restaurant_menu_outlined),
                     if(eventPhoto(product['imagen'])!=null)
                       const Positioned(right:4,bottom:4,
                         child:Icon(Icons.zoom_in,
                           color:Colors.white,size:22)),
                   ]),
                 ),
                 const SizedBox(width:12),
                 Expanded(child:Column(
                   crossAxisAlignment:CrossAxisAlignment.start,children:[
                     Text(product['nombre']?.toString()??'Producto',
                       maxLines:2,overflow:TextOverflow.ellipsis,
                       style:const TextStyle(color:ink,
                         fontFamily:'Georgia',
                         fontWeight:FontWeight.w800,fontSize:15)),
                     if((product['tipo']?.toString()??'').trim().isNotEmpty)
                       Text(product['tipo'].toString(),
                         maxLines:1,overflow:TextOverflow.ellipsis,
                         style:const TextStyle(color:detail,
                           fontSize:10,fontStyle:FontStyle.italic)),
                     if((product['descripcion']?.toString()??'').trim().isNotEmpty)...[
                       const SizedBox(height:4),
                       Text(product['descripcion'].toString(),
                         maxLines:2,overflow:TextOverflow.ellipsis,
                         style:const TextStyle(color:Color(0xFF735E4A),
                           fontSize:11,height:1.45)),
                     ],
                     const SizedBox(height:6),
                     Text(product['precio']==null?'Consultar precio':
                      currency(product['precio']),
                       style:const TextStyle(color:Color(0xFF966336),
                         fontSize:13,fontWeight:FontWeight.w900)),
                   ],
                 )),
               ]),
             ),
             if(product!=items.last)
               const Divider(height:1,color:Color(0x55BDA487)),
           ],
           const SizedBox(height:10),
           const Divider(height:1,thickness:1,color:Color(0xFFC9AF8D)),
           const SizedBox(height:12),
           Text(getText('sucursal','Buen provecho'),
             maxLines:1,overflow:TextOverflow.ellipsis,
             textAlign:TextAlign.center,
             style:const TextStyle(color:detail,fontSize:11,
               fontFamily:'Georgia',fontStyle:FontStyle.italic)),
         ]),
       )),
       // Dibujar lomo separado para conservar esquinas redondeadas válidas.
       const Positioned(left:0,top:0,bottom:7,
         child:IgnorePointer(child:DecoratedBox(
           decoration:BoxDecoration(
             color:Color(0xFFAC885E),
             borderRadius:BorderRadius.only(
               topLeft:Radius.circular(13),
               bottomLeft:Radius.circular(13))),
           child:SizedBox(width:5)))),
     ]));
   }
   return EventPanel(child:Column(
     key:_menuKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.menu_book_outlined,
         title:'La carta del evento',
         subtitle:selected.length.toString()+
          ' productos elegidos por el establecimiento · '+
          pages.length.toString()+' hojas generadas desde su catálogo'),
       const SizedBox(height:19),
       LayoutBuilder(builder:(context,box){
         final sideBySide=box.maxWidth>=830;
         final width=sideBySide
           ?(box.maxWidth-18)/2:box.maxWidth;
         return Wrap(spacing:18,runSpacing:19,children:[
           for(var i=0;i<pages.length;i++)
             menuPage(pages[i],i,width),
         ]);
       }),
     ],
   ));
 }

 Widget _footer(bool wide)=>Container(
   padding:const EdgeInsets.symmetric(horizontal:15,vertical:18),
   decoration:const BoxDecoration(border:Border(
     top:BorderSide(color:EventColors.border))),
   child:Wrap(spacing:20,runSpacing:12,
     alignment:WrapAlignment.spaceBetween,children:[
       Text(getText('sucursal'),style:const TextStyle(color:EventColors.text,
         fontWeight:FontWeight.w900,fontSize:16)),
       Text(getText('direccion'),
         style:const TextStyle(color:EventColors.muted,fontSize:12)),
       if(getText('telefono').isNotEmpty)
         Text(getText('telefono'),
           style:const TextStyle(color:EventColors.muted,fontSize:12)),
     ]),
 );
}
