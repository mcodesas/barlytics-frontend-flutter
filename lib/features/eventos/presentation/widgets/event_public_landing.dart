import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_visual_kit.dart';
import 'event_photo_viewer.dart';

/// Landing pública real (sin datos demostrativos ni dependencias del shell privado).
/// Toda la información proviene del evento, sucursal, mesas y catálogo del API.
class EventPublicLanding extends StatefulWidget {
  EventPublicLanding({
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
  bool get autoAssignOnly=>bySeat&&widget.event['seleccionarMesa']==false;
  EventPagePalette get palette=>EventPagePalette.fromHex(
    getText('colorPrimario'),getText('colorFondo'),getText('colorTexto'),
    getText('colorTarjeta'),getText('colorBorde'),getText('colorCarta'));
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
  void startReservation(){
    if(autoAssignOnly){
      _openAutomaticBooking();
    }else{
      jump(_bookingKey);
    }
  }

  Future<void> _openAutomaticBooking()async{
    final limit=automaticMax;
    if(limit<1){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No hay puestos disponibles para este evento.')));
      return;
    }
    var quantity=widget.seats.clamp(1,limit).toInt();
    final quantityInput=TextEditingController(text:quantity.toString());
    final formKey=GlobalKey<FormState>();
    final unit=price(widget.event['precio']);
    final pricePerSeat=widget.event['precioPorPuesto']==true;
    final payment=widget.event['medioPago']=='MERCADOPAGO';
    try{
      final accepted=await showDialog<bool>(
        context:context,
        builder:(dialogContext)=>StatefulBuilder(
          builder:(dialogContext,rebuild){
            void changeQuantity(int next){
              if(next<1||next>limit)return;
              rebuild((){
                quantity=next;
                quantityInput.text=next.toString();
              });
            }
            return AlertDialog(
              backgroundColor:palette.surface,
              shape:RoundedRectangleBorder(
                borderRadius:BorderRadius.circular(19)),
              title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Reservar puestos',
                  style:TextStyle(color:palette.text,fontWeight:FontWeight.w900)),
                const SizedBox(height:6),
                Text('Selecciona cuántos puestos necesitas. La mesa se asigna automáticamente.',
                  style:TextStyle(color:palette.muted,fontSize:12,fontWeight:FontWeight.normal)),
              ]),
              content:SizedBox(width:430,child:SingleChildScrollView(
                child:Form(key:formKey,child:Column(
                  mainAxisSize:MainAxisSize.min,
                  crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  Text('Cantidad de puestos',style:TextStyle(
                    color:palette.text,fontWeight:FontWeight.w800)),
                  const SizedBox(height:11),
                  Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                    IconButton.outlined(
                      tooltip:'Quitar un puesto',
                      onPressed:quantity<=1?null:()=>changeQuantity(quantity-1),
                      icon:const Icon(Icons.remove)),
                    const SizedBox(width:12),
                    SizedBox(width:96,child:TextFormField(
                      controller:quantityInput,
                      textAlign:TextAlign.center,
                      keyboardType:TextInputType.number,
                      inputFormatters:[FilteringTextInputFormatter.digitsOnly],
                      style:TextStyle(color:palette.text,fontSize:23,
                        fontWeight:FontWeight.w900),
                      onChanged:(value){
                        final parsed=int.tryParse(value);
                        if(parsed!=null)rebuild(()=>quantity=parsed);
                      },
                      validator:(value){
                        final n=int.tryParse(value??'');
                        if(n==null||n<1||n>limit){
                          return 'De 1 a $limit';
                        }
                        return null;
                      },
                    )),
                    const SizedBox(width:12),
                    IconButton.outlined(
                      tooltip:'Agregar un puesto',
                      onPressed:quantity>=limit?null:()=>changeQuantity(quantity+1),
                      icon:const Icon(Icons.add)),
                  ]),
                  const SizedBox(height:9),
                  Text('Hasta $limit puestos en una mesa disponible.',
                    textAlign:TextAlign.center,
                    style:TextStyle(color:palette.muted,fontSize:12)),
                  const SizedBox(height:16),
                  Container(
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:palette.surfaceSoft,
                      borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:palette.border)),
                    child:Column(children:[
                      Row(children:[
                        Expanded(child:Text(pricePerSeat?'Precio por puesto':'Precio de reserva',
                          style:TextStyle(color:palette.muted))),
                        Text(currency(unit),style:TextStyle(color:palette.text)),
                      ]),
                      const SizedBox(height:9),
                      Row(children:[
                        Expanded(child:Text('Total a pagar',
                          style:TextStyle(color:palette.text,fontWeight:FontWeight.w800))),
                        Text(currency(pricePerSeat?unit*quantity:unit),
                          style:TextStyle(color:brand,fontSize:19,fontWeight:FontWeight.w900)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height:17),
                  Text('Datos para la reserva',style:TextStyle(
                    color:palette.text,fontWeight:FontWeight.w800)),
                  const SizedBox(height:10),
                  TextFormField(
                    controller:widget.name,
                    maxLength:140,
                    textCapitalization:TextCapitalization.words,
                    decoration:const InputDecoration(labelText:'Nombre completo *',
                      prefixIcon:Icon(Icons.person_outline)),
                    validator:(v)=>(v?.trim().isEmpty??true)?'Ingresa tu nombre':null,
                  ),
                  const SizedBox(height:8),
                  TextFormField(
                    controller:widget.email,
                    maxLength:220,
                    keyboardType:TextInputType.emailAddress,
                    decoration:const InputDecoration(labelText:'Correo electrónico *',
                      prefixIcon:Icon(Icons.email_outlined)),
                    validator:(v){
                      final text=v?.trim()??'';
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                        ?null:'Ingresa un correo válido';
                    },
                  ),
                  const SizedBox(height:8),
                  TextFormField(
                    controller:widget.phone,
                    maxLength:40,
                    keyboardType:TextInputType.phone,
                    decoration:const InputDecoration(labelText:'Teléfono / WhatsApp',
                      prefixIcon:Icon(Icons.phone_outlined)),
                  ),
                  if(widget.event['medioPago']=='MANUAL')...[
                    const SizedBox(height:9),
                    Text('La reserva quedará pendiente de revisión del establecimiento.',
                      style:TextStyle(color:palette.muted,fontSize:12)),
                  ],
                ]))),
              ),
              actions:[
                TextButton(
                  onPressed:()=>Navigator.pop(dialogContext,false),
                  child:const Text('Cancelar')),
                FilledButton.icon(
                  onPressed:widget.busy?null:(){
                    if(!(formKey.currentState?.validate()??false))return;
                    final count=int.tryParse(quantityInput.text);
                    if(count==null||count<1||count>limit)return;
                    widget.onSelectTable(-1);
                    widget.onSeatsChanged(count);
                    Navigator.pop(dialogContext,true);
                  },
                  icon:Icon(payment?Icons.payment_outlined:Icons.check_circle_outline),
                  label:Text(payment?'Continuar al pago':'Confirmar reserva'),
                  style:FilledButton.styleFrom(
                    backgroundColor:brand,foregroundColor:onBrand),
                ),
              ],
            );
          },
        ),
      );
      if(accepted==true&&mounted)widget.onBook([]);
    }finally{
      quantityInput.dispose();
    }
  }

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
    if(c!=null)Scrollable.ensureVisible(c,duration:Duration(milliseconds:450),
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
      Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:1320),
        child:Padding(padding:EdgeInsets.symmetric(horizontal:wide?24:14,vertical:20),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            _opening(wide),
            SizedBox(height:17),
            _intro(wide),
            SizedBox(height:17),
            _bookingArea(wide),
            SizedBox(height:17),
            _catalog(),
            SizedBox(height:27),
            _footer(wide),
          ])))),
    ]);
    return EventPaletteScope(
      palette:palette,
      child:Theme(
      data:(palette.canvas.computeLuminance()>.38
        ?ThemeData.light(useMaterial3:true)
        :ThemeData.dark(useMaterial3:true)).copyWith(
        colorScheme:palette.canvas.computeLuminance()>.38
          ?ColorScheme.light(primary:brand,onPrimary:onBrand,
              surface:palette.surface,onSurface:palette.text)
          :ColorScheme.dark(primary:brand,onPrimary:onBrand,
              surface:palette.surface,onSurface:palette.text),
        inputDecorationTheme:InputDecorationTheme(
          filled:true,fillColor:palette.surfaceSoft,
          labelStyle:TextStyle(color:palette.muted),
          hintStyle:TextStyle(color:palette.muted),
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
            color:palette.heroShade.withOpacity(.60))),
          RefreshIndicator(onRefresh:widget.onRefresh,
            child:ListView(children:[content])),
        ]),
        bottomNavigationBar:wide?null:SafeArea(top:false,
          child:Container(
            padding:EdgeInsets.all(10),
            decoration:BoxDecoration(color:palette.surface,
              border:Border(top:BorderSide(color:palette.border))),
            child:FilledButton.icon(
              onPressed:startReservation,
              icon:Icon(Icons.confirmation_number_outlined),
              label:Text(bySeat?'Reservar puestos':'Reservar mesa'),
              style:FilledButton.styleFrom(backgroundColor:brand,
                foregroundColor:onBrand,
                padding:EdgeInsets.all(15))),
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
      Positioned.fill(child:ColoredBox(color:Colors.transparent)),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(
          begin:Alignment.centerLeft,end:Alignment.centerRight,
          colors:[palette.heroShade.withOpacity(.74),
            palette.heroShade.withOpacity(.40),
            palette.heroShade.withOpacity(.09),
            Colors.transparent])))),
      Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:1320),
        child:Padding(
          padding:EdgeInsets.symmetric(horizontal:wide?27:19,vertical:18),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _nav(wide),
            SizedBox(height:wide?63:48),
            EventPill(icon:Icons.local_activity_outlined,
              label:'EVENTO ESPECIAL · RESERVAS ABIERTAS',
              color:brand),
            SizedBox(height:14),
            ConstrainedBox(constraints:BoxConstraints(maxWidth:wide?840:480),
              child:Text(getText('titulo','Evento especial'),
                maxLines:3,overflow:TextOverflow.ellipsis,
                style:TextStyle(
                  fontWeight:FontWeight.w900,height:1.02,
                  letterSpacing:-1,
                  color:palette.text,fontSize:wide?56:38))),
            SizedBox(height:13),
            if(getText('descripcion').isNotEmpty)
              ConstrainedBox(constraints:BoxConstraints(maxWidth:650),
                child:Text(getText('descripcion'),
                  maxLines:3,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:palette.text,
                    fontSize:15,height:1.55))),
            SizedBox(height:19),
            Wrap(spacing:9,runSpacing:9,children:[
              EventPill(icon:Icons.event_outlined,label:time(widget.event['inicio'])),
              EventPill(icon:Icons.schedule_outlined,
                label:'Hasta '+time(widget.event['fin'])),
              EventPill(icon:Icons.location_on_outlined,
                label:getText('sucursal','Lugar del evento')),
              EventPill(icon:Icons.sell_outlined,
                label:price(widget.event['precio'])==0?'Entrada gratis':
                  (widget.event['precioPorPuesto']==true?'Por puesto · ':'Por mesa · ')+
                  currency(widget.event['precio']),color:brand),
            ]),
            SizedBox(height:20),
            Wrap(spacing:10,runSpacing:10,children:[
              FilledButton.icon(onPressed:startReservation,
                icon:Icon(Icons.event_seat_outlined),
                label:Text('Reservar ahora'),
                style:FilledButton.styleFrom(backgroundColor:brand,
                  foregroundColor:onBrand,
                  padding:EdgeInsets.symmetric(horizontal:25,vertical:17))),
              OutlinedButton.icon(onPressed:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
                icon:Icon(Icons.directions_outlined),
                label:Text('Cómo llegar')),
              OutlinedButton.icon(onPressed:widget.onShare,
                icon:Icon(Icons.share_outlined),
                label:Text('Compartir')),
            ]),
            SizedBox(height:26),
          ]),
        ),
      )),
    ]),
  );

  Widget _nav(bool wide) => Row(children:[
    Container(width:82,height:82,clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(color:palette.surfaceSoft,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:palette.border)),
      child:eventPhoto(widget.event['logo'])==null
        ?Icon(Icons.storefront_outlined,color:brand,size:40)
        :EventArtwork(source:widget.event['logo'],height:82,width:82,
          fit:BoxFit.cover,borderRadius:0)),
    SizedBox(width:11),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(getText('sucursal','Establecimiento'),
        softWrap:true,
        style:TextStyle(color:palette.text,
          fontWeight:FontWeight.w900,fontSize:wide?28:22)),
      Text('Eventos y reservas',
        style:TextStyle(color:palette.muted,fontSize:12)),
    ])),
    if(wide)...[
      if(eventPhoto(widget.event['imagen'])!=null)
        TextButton(onPressed:()=>jump(_posterKey),child:Text('Afiche')),
      TextButton(onPressed:()=>jump(_galleryKey),child:Text('El lugar')),
      TextButton(onPressed:()=>jump(_menuKey),child:Text('La carta')),
      TextButton(onPressed:()=>jump(_locationKey),child:Text('Ubicación')),
      SizedBox(width:8),
      OutlinedButton.icon(onPressed:startReservation,
        icon:Icon(Icons.event_seat_outlined,size:17),
        label:Text('Reservar ahora')),
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
           onPressed:expand,icon:Icon(Icons.fullscreen),
           label:Text('Ver completo')):null),
       SizedBox(height:16),
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
               padding:EdgeInsets.all(9),
               decoration:BoxDecoration(color:palette.surface,
                  borderRadius:BorderRadius.circular(11)),
               child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(Icons.zoom_in,color:brand),
                  SizedBox(width:6),
                 Text('Ampliar afiche',
                   style:TextStyle(color:palette.text,fontSize:12)),
               ]))),
           ]),
         );
         if(!wide)return photo;
         return Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
           Expanded(flex:6,child:photo),SizedBox(width:23),
           Expanded(flex:4,child:Column(
             crossAxisAlignment:CrossAxisAlignment.start,children:[
               EventPill(icon:Icons.star_outline,
                 label:'AFICHE OFICIAL',color:brand),
               SizedBox(height:16),
               Text(getText('titulo'),style:TextStyle(
                 color:palette.text,fontWeight:FontWeight.w900,
                 fontSize:29,height:1.1)),
               SizedBox(height:17),
               EventMetric(icon:Icons.calendar_month_outlined,
                 label:'Fecha',value:time(widget.event['inicio'])),
               SizedBox(height:13),
               EventMetric(icon:Icons.location_on_outlined,
                 label:'Lugar',value:getText('sucursal')),
               SizedBox(height:19),
               Text('Acércate para leer todos los detalles del afiche.',
                 style:TextStyle(color:palette.muted,
                   fontSize:13,height:1.5)),
               SizedBox(height:13),
               FilledButton.icon(onPressed:expand,
                 icon:Icon(Icons.fullscreen_outlined),
                 style:FilledButton.styleFrom(
                   backgroundColor:brand,
                    foregroundColor:onBrand),
                 label:Text('Abrir afiche')),
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
    EventSectionHeading(icon:Icons.auto_awesome_outlined,
      title:'Sobre el evento',subtitle:'Toda la información de esta experiencia'),
    SizedBox(height:16),
    Text(getText('descripcion','Una experiencia especial para compartir.'),
      style:TextStyle(color:palette.text,fontSize:15,height:1.75)),
    SizedBox(height:17),
    Wrap(spacing:9,runSpacing:9,children:[
      EventPill(icon:Icons.event_outlined,label:time(widget.event['inicio'])),
      EventPill(icon:Icons.place_outlined,label:getText('sucursal')),
      EventPill(icon:Icons.payments_outlined,
        label:currency(widget.event['precio']),color:brand),
    ]),
   ],
  ));
  if(poster==null)return intro;
  if(!wide)return Column(children:[poster,SizedBox(height:13),intro]);
  return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:7,child:poster),
    SizedBox(width:16),
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
       SizedBox(height:15),
       if(venue.isEmpty)Container(height:220,alignment:Alignment.center,
         decoration:BoxDecoration(color:palette.surfaceSoft,
            borderRadius:BorderRadius.circular(12)),
         child:Text('Próximamente: fotos del lugar',
           style:TextStyle(color:palette.muted)))
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
                 Positioned(bottom:9,right:9,
                   child:Icon(Icons.zoom_in,color:palette.text,size:27)),
               ]),
             )),
         ]);
       }),
       if(venue.isNotEmpty)...[
         SizedBox(height:14),
         OutlinedButton.icon(
           onPressed:()=>showEventPhotoViewer(context,
             images:venue.cast<Object?>(),
             labels:List.generate(venue.length,
               (i)=>'Fotografía del lugar '+(i+1).toString())),
           icon:Icon(Icons.fullscreen_outlined),
           label:Text('Ver galería en pantalla completa')),
       ],
     ]));
   final mapPreview=venue.isNotEmpty?venue.first:widget.event['imagen'];
   final place=EventPanel(child:Column(
     key:_locationKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.location_on_outlined,
         title:'Nuestra ubicación',
         subtitle:'Encuentra cómo llegar al establecimiento.'),
       SizedBox(height:14),
       _locationPhoto(mapPreview),
       SizedBox(height:17),
       _locationInfo(),
     ]));
   if(!wide)return Column(children:[
     photos,SizedBox(height:12),place,
   ]);
   // Galería y mapa con enlaces sociales en columnas equilibradas.
   return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(flex:7,child:photos),
     SizedBox(width:16),
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
         gradient:LinearGradient(
           begin:Alignment.bottomCenter,end:Alignment.topCenter,
           colors:[palette.heroShade.withOpacity(.90),Colors.transparent])))),
     Positioned(left:12,bottom:12,right:12,child:Row(children:[
       Icon(Icons.location_on,color:brand),
       SizedBox(width:7),
       Expanded(child:Text('Vista del lugar · Abrir en Google Maps',
         style:TextStyle(color:palette.text,
           fontWeight:FontWeight.w800,fontSize:12))),
       Icon(Icons.open_in_new,color:palette.text,size:17),
     ])),
   ]),
 );

 Widget _locationInfo()=>Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(getText('sucursal','Lugar del evento'),
       style:TextStyle(color:palette.text,
         fontWeight:FontWeight.w800,fontSize:18)),
     SizedBox(height:7),
     Text(getText('direccion','Dirección del lugar'),
       style:TextStyle(color:palette.muted,fontSize:13)),
     SizedBox(height:16),
     OutlinedButton.icon(
       onPressed:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
       icon:Icon(Icons.directions_outlined),
       label:Text('Ver ubicación en Google Maps')),
     SizedBox(height:23),
     Text('Síguenos en redes sociales',
       style:TextStyle(color:palette.text,
        fontWeight:FontWeight.w800,fontSize:14)),
     SizedBox(height:11),
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
  if(items.isEmpty)return Text('Próximamente enlaces sociales del lugar',
   style:TextStyle(color:palette.muted,fontSize:12));
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
   if(autoAssignOnly){
     return EventPanel(child:Column(
       key:_bookingKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
         EventSectionHeading(icon:Icons.event_seat_outlined,
           title:'Reserva tus puestos',
           subtitle:'Selecciona la cantidad y continúa al pago sin elegir mesa'),
         const SizedBox(height:14),
         Text('BarLytics encontrará automáticamente una mesa con suficientes puestos libres.',
           style:TextStyle(color:palette.muted,fontSize:14)),
         const SizedBox(height:15),
         EventPill(icon:Icons.event_seat_outlined,
           label:automaticMax>0?
             'Hasta $automaticMax puestos disponibles en una mesa':
             'Sin puestos disponibles'),
         const SizedBox(height:17),
         FilledButton.icon(
           onPressed:automaticMax<1||widget.busy?null:startReservation,
           icon:const Icon(Icons.add_circle_outline),
           label:const Text('Reservar puestos'),
           style:FilledButton.styleFrom(backgroundColor:brand,
             foregroundColor:onBrand,padding:const EdgeInsets.symmetric(
               horizontal:22,vertical:16))),
       ],
     ));
   }
   final content=EventPanel(child:Column(
     key:_bookingKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.table_restaurant_outlined,
         title:bySeat?'Reserva por puestos':'Reserva tu mesa',
         subtitle:bySeat?'Reserva varios puestos o asigna mesa automáticamente.':'La mesa se reserva completa.'),
       SizedBox(height:14),
       Wrap(spacing:12,runSpacing:9,children:[
         EventPill(icon:Icons.circle,color:EventColors.success,
           label:'Disponible'),
         EventPill(icon:Icons.circle,color:EventColors.warning,label:'Apartada'),
       ]),
       SizedBox(height:14),
       if(bySeat&&automaticMax>0)...[
         SwitchListTile.adaptive(
          value:automatic,contentPadding:EdgeInsets.zero,
          title:Text('Asignar mesa automáticamente',
           style:TextStyle(color:palette.text,fontWeight:FontWeight.w800)),
          subtitle:Text('Elige cuántos puestos quieres; encontraremos mesa disponible.'),
          onChanged:(v)=>setState((){
           automatic=v;chosenChairs.clear();
           if(v)widget.onSelectTable(-1);
          })),
         SizedBox(height:8),
       ],
       if(tables.isEmpty)
         Padding(padding:EdgeInsets.all(32),
           child:Center(child:Text('Por ahora no hay mesas habilitadas.',
             style:TextStyle(color:palette.muted))))
       else GridView.builder(
         itemCount:tables.length,
         shrinkWrap:true,physics:NeverScrollableScrollPhysics(),
         gridDelegate:SliverGridDelegateWithMaxCrossAxisExtent(
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
                   color:chosen?brand:palette.border)),
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
                       icon:Icon(Icons.zoom_in,size:19))),
                   if(chosen)Positioned(right:8,top:8,
                     child:CircleAvatar(radius:15,backgroundColor:brand,
                       child:Icon(Icons.check,color:onBrand,size:18))),
                   if(!available)Positioned.fill(child:Container(color:Colors.black45)),
                 ])),
                 Padding(padding:EdgeInsets.fromLTRB(10,8,10,10),
                   child:Row(children:[
                     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                       Text('Mesa '+(t['numero']??id).toString(),
                         style:TextStyle(color:palette.text,
                           fontWeight:FontWeight.w800,fontSize:13)),
                       SizedBox(height:4),
                       Text(bySeat?
                         free.toString()+' de '+capacity.toString()+' puestos libres':
                         capacity.toString()+' puestos',
                         style:TextStyle(color:palette.muted,fontSize:11)),
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
     content,SizedBox(height:13),_reservationSummary(),
   ]);
   return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(flex:7,child:content),
     SizedBox(width:13),
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
       EventSectionHeading(icon:Icons.confirmation_number_outlined,
         title:'Tu reserva',subtitle:'Completa tus datos para confirmar'),
       SizedBox(height:15),
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
                 Positioned(right:3,bottom:3,child:Icon(
                   Icons.zoom_in,color:palette.text,size:18)),
             ]),
           ),
           SizedBox(width:11),
           Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
             Text('Mesa '+(t['numero']??'').toString(),
               style:TextStyle(color:palette.text,
                 fontWeight:FontWeight.w800)),
             SizedBox(height:5),
             Text(capacity.toString()+' puestos disponibles',
               style:TextStyle(color:EventColors.success,fontSize:12)),
           ])),
         ]),
       ]else if(automatic&&bySeat)
         EventPill(icon:Icons.auto_awesome,
          label:'La mesa se asignará automáticamente')
       else EventPill(icon:Icons.touch_app_outlined,
         label:'Selecciona una mesa o asignación automática'),
       Divider(color:palette.border,height:29),
       Row(children:[
         Expanded(child:Text('Cantidad de puestos',
           style:TextStyle(color:palette.muted,fontSize:12))),
         IconButton.outlined(
           onPressed:(widget.selectedTable==null&&!automatic)||widget.seats<=1
             ?null:()=>setState((){
              chosenChairs.clear();widget.onSeatsChanged(widget.seats-1);
             }),
           icon:Icon(Icons.remove,size:17)),
         Padding(padding:EdgeInsets.symmetric(horizontal:10),
           child:Text(widget.seats.toString(),
             style:TextStyle(color:palette.text,
               fontWeight:FontWeight.w800,fontSize:17))),
         IconButton.outlined(
           onPressed:(widget.selectedTable==null&&!automatic)||widget.seats>=capacity
             ?null:()=>setState((){
              chosenChairs.clear();widget.onSeatsChanged(widget.seats+1);
             }),
           icon:Icon(Icons.add,size:17)),
       ]),
       if(selectSeats&&!automatic&&t!=null)...[
         SizedBox(height:13),
         Text('Selecciona tus sillas',
           style:TextStyle(color:palette.text,fontWeight:FontWeight.w800)),
         SizedBox(height:10),
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
         SizedBox(height:7),
         Text(chosenChairs.length.toString()+' de '+widget.seats.toString()+' sillas',
           style:TextStyle(color:chosenChairs.length==widget.seats?
             EventColors.success:EventColors.warning,fontSize:12)),
       ],
       SizedBox(height:12),
       Row(children:[
         Expanded(child:Text(
           widget.event['precioPorPuesto']==true?'Precio por puesto':'Precio por mesa',
           style:TextStyle(color:palette.muted,fontSize:12))),
         Text(currency(unit),style:TextStyle(color:palette.text)),
       ]),
       Divider(color:palette.border,height:23),
       Row(children:[
         Expanded(child:Text('Total a pagar',style:TextStyle(
           color:palette.text,fontWeight:FontWeight.w800))),
         Text(currency(total),style:TextStyle(color:brand,
           fontWeight:FontWeight.w900,fontSize:20)),
       ]),
       SizedBox(height:20),
       Text('Tus datos',style:TextStyle(
         color:palette.text,fontWeight:FontWeight.w800)),
       SizedBox(height:11),
       TextField(controller:widget.name,
         textCapitalization:TextCapitalization.words,
         decoration:InputDecoration(
           labelText:'Nombre completo *',prefixIcon:Icon(Icons.person_outline))),
       SizedBox(height:10),
       TextField(controller:widget.email,
         keyboardType:TextInputType.emailAddress,
         decoration:InputDecoration(
           labelText:'Correo electrónico *',prefixIcon:Icon(Icons.email_outlined))),
       SizedBox(height:10),
       TextField(controller:widget.phone,
         keyboardType:TextInputType.phone,
         decoration:InputDecoration(
           labelText:'Teléfono / WhatsApp',prefixIcon:Icon(Icons.phone_outlined))),
       SizedBox(height:16),
       if(widget.event['medioPago']=='MANUAL')
         Padding(padding:EdgeInsets.only(bottom:12),
           child:Text('La reserva quedará pendiente de aprobación del establecimiento.',
             style:TextStyle(color:brand,fontSize:12))),
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
           padding:EdgeInsets.symmetric(vertical:17)))),
       SizedBox(height:9),
       Center(child:Text('Reserva segura y protegida',
         style:TextStyle(color:palette.muted,fontSize:11))),
     ],
   ));
 }


 Widget _catalog(){
   // Productos, nombres, categorías, fotos y precios vienen exclusivamente de
   // widget.event['carta'], construido desde commerce.evento_productos.
   final selected=products;
   if(selected.isEmpty)return EventPanel(child:Column(
     key:_menuKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.menu_book_outlined,title:'La carta del evento',
         subtitle:'Productos seleccionados del catálogo del establecimiento'),
       SizedBox(height:15),
       Text('Todavía no hay productos seleccionados para este evento.',
         style:TextStyle(color:palette.muted)),
     ]));

   final categories=<String,List<Map<String,dynamic>>>{};
   for(final product in selected){
     final type=product['tipo']?.toString().trim()??'';
     categories.putIfAbsent(type.isEmpty?'Nuestra selección':type,()=>[]).add(product);
   }
   // Conservar orden de selección. Repetir el título cuando una categoría
   // continúa en la siguiente hoja; nunca intercalar productos inventados.
   final pages=<List<MapEntry<String,List<Map<String,dynamic>>>>>[];
   var current=<MapEntry<String,List<Map<String,dynamic>>>>[];
   var count=0;
   for(final category in categories.entries){
     var position=0;
     while(position<category.value.length){
       if(count==8){
         pages.add(current);
         current=<MapEntry<String,List<Map<String,dynamic>>>>[];
         count=0;
       }
       final portion=category.value.skip(position).take(8-count).toList();
       current.add(MapEntry(category.key,portion));
       count+=portion.length;
       position+=portion.length;
     }
   }
   if(current.isNotEmpty)pages.add(current);

   final paper=palette.menuPaper,ink=palette.menuInk;
   final rule=palette.menuBorder;
   final venueName=getText('sucursal',getText('empresa','Establecimiento')).trim();
   final company=getText('empresa').trim();
   final subtitle=getText('titulo',company.isNotEmpty?company:'Carta del evento');
   final label=venueName.isEmpty?'Establecimiento':venueName;

   Widget productRow(Map<String,dynamic> product,double width){
     final description=product['descripcion']?.toString().trim()??'';
     final name=(product['nombre']??'').toString().trim();
     final shownPrice=product['precio']==null
       ?'Consultar precio':'\$'+currency(product['precio']).replaceFirst('COP ','');
     return Padding(
       padding:EdgeInsets.symmetric(vertical:width<390?9:11,horizontal:3),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Expanded(child:Text(name.toUpperCase(),maxLines:2,
             overflow:TextOverflow.ellipsis,
             style:TextStyle(fontFamily:'Georgia',fontSize:width<390?12:14,
               fontWeight:FontWeight.w900,color:ink,height:1.32))),
           SizedBox(width:10),
           Text(shownPrice,textAlign:TextAlign.end,
             style:TextStyle(fontFamily:'Georgia',fontSize:width<390?12:14,
               fontWeight:FontWeight.w900,color:ink)),
         ]),
         if(description.isNotEmpty)...[
           SizedBox(height:6),
           Text(description,maxLines:5,overflow:TextOverflow.ellipsis,
             style:TextStyle(fontFamily:'Georgia',
               fontSize:width<390?11:12,color:ink,height:1.45)),
         ],
       ]),
     );
   }

   Widget menuSheet(List<MapEntry<String,List<Map<String,dynamic>>>> sections,
     int index,double width){
     final compact=width<410;
     return SizedBox(width:width,child:DecoratedBox(
       decoration:BoxDecoration(color:paper,
         border:Border.all(color:rule,width:1.5),
         boxShadow:[BoxShadow(color:Colors.black.withOpacity(.24),
           blurRadius:17,offset:Offset(0,7))]),
       child:Padding(padding:EdgeInsets.all(compact?6:10),
         child:DecoratedBox(
           decoration:BoxDecoration(border:Border.all(
             color:rule.withOpacity(.74),width:.85)),
           child:Padding(
             padding:EdgeInsets.fromLTRB(compact?14:27,compact?22:31,
               compact?14:27,20),
             child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
               Text(label.toUpperCase(),textAlign:TextAlign.center,
                 maxLines:2,overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontFamily:'Georgia',
                   fontWeight:FontWeight.w500,fontSize:compact?23:31,
                   letterSpacing:compact?2:4,color:ink)),
               SizedBox(height:6),
               Text(subtitle.toUpperCase(),maxLines:2,
                 textAlign:TextAlign.center,overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontFamily:'Georgia',
                   fontSize:compact?9:10,letterSpacing:1.8,color:ink)),
               SizedBox(height:16),
               Center(child:SizedBox(width:175,
                 child:Divider(color:rule,thickness:1))),
               SizedBox(height:24),
               for(final section in sections)...[
                 Text('NUESTRA SELECCIÓN',textAlign:TextAlign.center,
                   style:TextStyle(fontFamily:'Georgia',fontSize:10,
                     letterSpacing:.8,color:ink)),
                 SizedBox(height:5),
                 Text(section.key,textAlign:TextAlign.center,
                   style:TextStyle(fontFamily:'Georgia',
                     fontStyle:FontStyle.italic,fontSize:compact?22:27,color:ink)),
                 SizedBox(height:12),
                 Row(children:[
                   Expanded(child:Container(height:1,color:rule)),
                   Padding(padding:EdgeInsets.symmetric(horizontal:7),
                     child:Icon(Icons.diamond_outlined,color:rule,size:12)),
                   Expanded(child:Container(height:1,color:rule)),
                 ]),
                 SizedBox(height:9),
                 if(sections.length>1&&section!=sections.first&&
                    section.value.length<=4&&!compact)
               LayoutBuilder(builder:(context,bounds){
                 final widthItem=(bounds.maxWidth-14)/2;
                 return Wrap(spacing:14,runSpacing:5,children:[
                   for(final product in section.value)
                     SizedBox(width:widthItem,child:productRow(product,widthItem)),
                 ]);
               })
             else for(final product in section.value)...[
               productRow(product,width),
               Divider(height:1,thickness:.55,color:rule),
             ],
                 SizedBox(height:25),
               ],
               SizedBox(height:22),
               Divider(color:rule,height:12),
               Text(getText('titulo','Carta del evento'),
                 textAlign:TextAlign.center,maxLines:2,
                 overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontFamily:'Georgia',color:ink,fontSize:11)),
               SizedBox(height:6),
               Text(label+' · '+(index+1).toString()+' / '+pages.length.toString(),
                 textAlign:TextAlign.center,maxLines:2,
                 overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontFamily:'Georgia',fontSize:10,color:ink)),
             ]),
           ),
         ),
       ),
     ));
   }

   return EventPanel(child:Column(
     key:_menuKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.menu_book_outlined,
         title:'La carta del evento',
         subtitle:selected.length.toString()+' productos seleccionados · '+
           pages.length.toString()+' hojas generadas desde el catálogo'),
       SizedBox(height:18),
       LayoutBuilder(builder:(context,space){
         final paired=space.maxWidth>=910;
         final width=paired?(space.maxWidth-20)/2:space.maxWidth;
         return Wrap(spacing:20,runSpacing:20,children:[
           for(var i=0;i<pages.length;i++)menuSheet(pages[i],i,width),
         ]);
       }),
     ]));
 }

 Widget _footer(bool wide)=>Container(
   padding:EdgeInsets.symmetric(horizontal:15,vertical:18),
   decoration:BoxDecoration(border:Border(
     top:BorderSide(color:palette.border))),
   child:Wrap(spacing:20,runSpacing:12,
     alignment:WrapAlignment.spaceBetween,children:[
       Text(getText('sucursal'),style:TextStyle(color:palette.text,
         fontWeight:FontWeight.w900,fontSize:16)),
       Text(getText('direccion'),
         style:TextStyle(color:palette.muted,fontSize:12)),
       if(getText('telefono').isNotEmpty)
         Text(getText('telefono'),
           style:TextStyle(color:palette.muted,fontSize:12)),
     ]),
 );
}
