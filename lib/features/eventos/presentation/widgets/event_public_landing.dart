import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_visual_kit.dart';
import 'event_photo_viewer.dart';
import 'event_share_sheet.dart';

/// Cupo real total del evento; las mesas ocupadas devuelven cero desde el API.
int eventAvailableSeats(Iterable<Map<String,dynamic>> tables){
  return tables.fold<int>(0,(sum,table){
    final raw=int.tryParse(table['disponibles']?.toString()??'0')??0;
    return sum+(raw>0?raw:0);
  });
}

/// Páginas para la carta pública conservando el orden real de la selección.
/// Prioriza categorías completas y solo corta las que no caben en una hoja.
List<List<MapEntry<String,List<T>>>> eventMenuPages<T>(
    Map<String,List<T>> categories,{int pageSize=8}){
  if(pageSize<1)throw ArgumentError.value(pageSize,'pageSize');
  final pages=<List<MapEntry<String,List<T>>>>[];
  var current=<MapEntry<String,List<T>>>[];
  var count=0;
  void finishPage(){
    if(current.isEmpty)return;
    pages.add(current);
    current=<MapEntry<String,List<T>>>[];
    count=0;
  }
  for(final category in categories.entries){
    if(current.isNotEmpty&&category.value.length<=pageSize&&
       count+category.value.length>pageSize)finishPage();
    var position=0;
    while(position<category.value.length){
      if(count>=pageSize)finishPage();
      final portion=category.value.skip(position).take(pageSize-count).toList();
      current.add(MapEntry(category.key,portion));
      count+=portion.length;
      position+=portion.length;
    }
  }
  finishPage();
  return pages;
}

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
  // El cliente puede reservar el cupo total, no sólo el de una mesa.
  int get automaticMax=>eventAvailableSeats(tables);
  void startReservation(){
    if(autoAssignOnly){
      _openAutomaticBooking();
    }else{
      jump(_bookingKey);
    }
  }

  ThemeData _pageTheme(BuildContext context){
    final p=palette;
    final light=p.surface.computeLuminance()>.18;
    final fg=p.onSurface;
    final fieldFg=p.onSurfaceSoft;
    final actionFg=p.accentOnSurface;
    final fieldAccent=p.accentOnSoft;
    final line=EventPagePalette.contrast(p.border,p.surfaceSoft)>=1.55
      ?p.border:Color.lerp(p.surfaceSoft,fieldFg,.38)!;
    final scheme=(light
      ?ColorScheme.light(primary:p.accent,onPrimary:p.onAccent,
        surface:p.surface,onSurface:fg)
      :ColorScheme.dark(primary:p.accent,onPrimary:p.onAccent,
        surface:p.surface,onSurface:fg))
      .copyWith(
        onSurfaceVariant:fieldFg,
        outline:line,
        secondary:p.accent,onSecondary:p.onAccent,
      );
    return (light?ThemeData.light(useMaterial3:true)
                 :ThemeData.dark(useMaterial3:true)).copyWith(
      colorScheme:scheme,
      scaffoldBackgroundColor:p.canvas,
      canvasColor:p.surface,
      textTheme:Theme.of(context).textTheme.apply(
        bodyColor:fg,displayColor:fg),
      iconTheme:IconThemeData(color:fg),
      dialogTheme:DialogThemeData(
        backgroundColor:p.surface,
        surfaceTintColor:Colors.transparent,
        titleTextStyle:TextStyle(color:fg,fontSize:20,
          fontWeight:FontWeight.w900),
        contentTextStyle:TextStyle(color:fg,fontSize:14)),
      textSelectionTheme:TextSelectionThemeData(
        cursorColor:fieldAccent,
        selectionColor:fieldAccent.withOpacity(.24),
        selectionHandleColor:fieldAccent),
      inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:p.surfaceSoft,
        labelStyle:TextStyle(color:fieldFg,fontSize:15,
          fontWeight:FontWeight.w500),
        hintStyle:TextStyle(color:fieldFg,fontSize:15),
        helperStyle:TextStyle(color:fieldFg,fontSize:12),
        counterStyle:TextStyle(color:fieldFg,fontSize:12),
        floatingLabelStyle:TextStyle(color:fieldAccent,fontSize:14,
          fontWeight:FontWeight.w800),
        prefixIconColor:fieldAccent,
        suffixIconColor:fieldAccent,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
        enabledBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(12),
          borderSide:BorderSide(color:line,width:1.2)),
        focusedBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(12),
          borderSide:BorderSide(color:fieldAccent,width:2)),
        errorBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(12),
          borderSide:BorderSide(color:scheme.error)),
        focusedErrorBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(12),
          borderSide:BorderSide(color:scheme.error,width:2)),
      ),
      filledButtonTheme:FilledButtonThemeData(
        style:FilledButton.styleFrom(
          backgroundColor:p.accent,foregroundColor:p.onAccent,
          disabledBackgroundColor:p.surfaceSoft,
          disabledForegroundColor:fieldFg)),
      textButtonTheme:TextButtonThemeData(
        style:TextButton.styleFrom(foregroundColor:actionFg)),
      outlinedButtonTheme:OutlinedButtonThemeData(
        style:OutlinedButton.styleFrom(
          foregroundColor:fg,side:BorderSide(color:p.border))),
      iconButtonTheme:IconButtonThemeData(
        style:IconButton.styleFrom(
          foregroundColor:fieldAccent,
          disabledForegroundColor:fieldFg.withOpacity(.6))),
      switchTheme:SwitchThemeData(
        thumbColor:WidgetStateProperty.resolveWith(
          (states)=>states.contains(WidgetState.selected)?p.onAccent:fg),
        trackColor:WidgetStateProperty.resolveWith(
          (states)=>states.contains(WidgetState.selected)?p.accent:p.surfaceSoft)),
    );
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
        builder:(dialogContext)=>Theme(
          data:_pageTheme(dialogContext),
          child:StatefulBuilder(
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
                Text('Selecciona tus puestos. Pueden distribuirse entre varias mesas.',
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
                      style:TextStyle(color:palette.onSurfaceSoft,fontSize:23,
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
                  Text('Hasta $limit puestos disponibles en el evento; se asignan entre mesas.',
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
                          style:TextStyle(color:palette.onSurfaceSoft))),
                        Text(currency(unit),style:TextStyle(color:palette.onSurfaceSoft)),
                      ]),
                      const SizedBox(height:9),
                      Row(children:[
                        Expanded(child:Text('Total a pagar',
                          style:TextStyle(color:palette.onSurfaceSoft,fontWeight:FontWeight.w800))),
                        Text(currency(pricePerSeat?unit*quantity:unit),
                          style:TextStyle(color:palette.accentOnSoft,fontSize:19,fontWeight:FontWeight.w900)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height:17),
                  Text('Datos para la reserva',style:TextStyle(
                    color:palette.text,fontWeight:FontWeight.w800)),
                  const SizedBox(height:10),
                  TextFormField(
                    style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
                    controller:widget.name,
                    maxLength:140,
                    textCapitalization:TextCapitalization.words,
                    decoration:const InputDecoration(labelText:'Nombre completo *',
                      prefixIcon:Icon(Icons.person_outline)),
                    validator:(v)=>(v?.trim().isEmpty??true)?'Ingresa tu nombre':null,
                  ),
                  const SizedBox(height:8),
                  TextFormField(
                    style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
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
                    style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
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
        )),
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

  Uri? get whatsappUrl => eventWhatsappHelpLink(widget.event);

  Future<void> openSupport()async{
    final url=whatsappUrl;
    if(url==null)return;
    try{
      if(!await launchUrl(url,mode:LaunchMode.externalApplication)&&mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('No fue posible abrir WhatsApp')));
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No fue posible abrir WhatsApp')));
    }
  }

  Future<void> openMap()async{
    final uri=Uri.tryParse(getText('ubicacionGoogleMaps'));
    if(uri==null||uri.scheme!='https')return;
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }


  /// Limpia los marcadores usados al escribir la descripción en el editor
  /// para mostrar un adelanto legible en la portada.
  String get _shortDescription{
    final content=getText('descripcion').replaceAll('*','').trim();
    final lines=content.split(RegExp(r'\n+'))
      .map((line)=>line.trim()).where((line)=>line.isNotEmpty).toList();
    if(lines.isEmpty)return '';
    return lines.firstWhere((line)=>line.length>=55,orElse:()=>lines.first);
  }

  /// Acepta párrafos y negritas Markdown guardados en base de datos.
  /// Evita mostrar los literales ** en el sitio público.
  Widget _descriptionBody(String description){
    final lines=description.replaceAll('\r\n','\n').split('\n');
    final paragraphs=<Widget>[];
    final emphasis=RegExp(r'\*\*([^*]+)\*\*|\*([^*]+)\*');
    for(final raw in lines){
      final value=raw.trim();
      if(value.isEmpty)continue;
      final spans=<InlineSpan>[];
      var end=0;
      for(final match in emphasis.allMatches(value)){
        if(match.start>end)spans.add(TextSpan(text:value.substring(end,match.start)));
        final bold=match.group(1)!=null;
        spans.add(TextSpan(text:match.group(bold?1:2),
          style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.w500,
            fontStyle:bold?FontStyle.normal:FontStyle.italic)));
        end=match.end;
      }
      if(end<value.length)spans.add(TextSpan(text:value.substring(end)));
      paragraphs.add(Padding(
        padding:const EdgeInsets.only(bottom:13),
        child:Text.rich(TextSpan(children:spans),
          style:TextStyle(color:palette.text,fontSize:15,height:1.63)),
      ));
    }
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:paragraphs);
  }

  @override Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=940;
    final bg=venue.isNotEmpty?venue.first:widget.event['imagen'];
    final content=Column(children:[
      _hero(bg,wide),
      Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:1320),
        child:Padding(padding:EdgeInsets.symmetric(horizontal:wide?24:14,vertical:24),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            _opening(wide),
            SizedBox(height:25),
            _intro(wide),
            SizedBox(height:25),
            _bookingArea(wide),
            SizedBox(height:25),
            _catalog(),
            SizedBox(height:27),
            _footer(wide),
          ])))),
    ]);
    return EventPaletteScope(
      palette:palette,
      child:Theme(
      data:_pageTheme(context),
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
            color:palette.heroShade.withOpacity(.46))),
          RefreshIndicator(onRefresh:widget.onRefresh,
            child:ListView(children:[content])),
        ]),
        // WhatsApp es una acción flotante independiente del botón de reserva.
        // En móvil Scaffold sitúa el FAB por encima de bottomNavigationBar.
        floatingActionButton:whatsappUrl==null
          ?null
          :wide
            ?FloatingActionButton.extended(
              heroTag:'evento-whatsapp-ayuda',
              backgroundColor:palette.accent,
              foregroundColor:palette.onAccent,
              onPressed:openSupport,
              tooltip:'Consultar por WhatsApp a '+getText('sucursal'),
              icon:const Icon(Icons.chat_outlined),
              label:const Text('¿Dudas? WhatsApp'))
            :FloatingActionButton(
              heroTag:'evento-whatsapp-ayuda-movil',
              backgroundColor:palette.accent,
              foregroundColor:palette.onAccent,
              onPressed:openSupport,
              tooltip:'¿Dudas? Escríbenos por WhatsApp',
              child:const Icon(Icons.chat_bubble_outline_rounded,size:26)),
        floatingActionButtonLocation:FloatingActionButtonLocation.endFloat,
        bottomNavigationBar:wide?null:SafeArea(top:false,
          child:Container(
            padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:palette.surface,
              border:Border(top:BorderSide(color:palette.border))),
            child:SizedBox(width:double.infinity,
              child:FilledButton.icon(
                onPressed:startReservation,
                icon:const Icon(Icons.confirmation_number_outlined),
                label:Text(bySeat?'Reservar puestos':'Reservar mesa'),
                style:FilledButton.styleFrom(backgroundColor:brand,
                  foregroundColor:onBrand,
                  padding:const EdgeInsets.all(15)))),
          )),
      ),
      ),
    );
  }

  Widget _hero(Object? image,bool wide) => Container(
    constraints:BoxConstraints(minHeight:wide?475:455),
    child:Stack(children:[
      // La fotografía está en el fondo fijo de toda la pantalla.
      // El encabezado deja verla sin duplicarla ni desplazarla.
      Positioned.fill(child:ColoredBox(color:Colors.transparent)),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(
          begin:Alignment.centerLeft,end:Alignment.centerRight,
          colors:[palette.heroShade.withOpacity(.92),
            palette.heroShade.withOpacity(.66),
            palette.heroShade.withOpacity(.18),
            Colors.transparent])))),
      Center(child:ConstrainedBox(
        constraints:BoxConstraints(maxWidth:1320),
        child:Padding(
          padding:EdgeInsets.symmetric(horizontal:wide?27:19,vertical:18),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _nav(wide),
            SizedBox(height:wide?56:42),
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
                  color:palette.heroInk,fontSize:wide?56:38))),
            SizedBox(height:13),
            if(_shortDescription.isNotEmpty)
              ConstrainedBox(constraints:BoxConstraints(maxWidth:680),
                child:Text(_shortDescription,
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:palette.heroInk,
                    fontSize:wide?16:14,height:1.55))),
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
              OutlinedButton.icon(
              style:OutlinedButton.styleFrom(
                foregroundColor:palette.heroInk,
                side:BorderSide(color:palette.heroInk.withOpacity(.72))),
              onPressed:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
                icon:Icon(Icons.directions_outlined),
                label:Text('Cómo llegar')),
              OutlinedButton.icon(
              style:OutlinedButton.styleFrom(
                foregroundColor:palette.heroInk,
                side:BorderSide(color:palette.heroInk.withOpacity(.72))),
              onPressed:widget.onShare,
                icon:Icon(Icons.share_outlined),
                label:Text('Compartir')),
              if(whatsappUrl!=null)
                OutlinedButton.icon(
              style:OutlinedButton.styleFrom(
                foregroundColor:palette.heroInk,
                side:BorderSide(color:palette.heroInk.withOpacity(.72))),
              onPressed:openSupport,
                  icon:Icon(Icons.support_agent_outlined),
                  label:Text('¿Dudas? WhatsApp')),
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
        ?Icon(Icons.storefront_outlined,color:palette.accentOnSoft,size:40)
        :EventArtwork(source:widget.event['logo'],height:82,width:82,
          fit:BoxFit.cover,borderRadius:0)),
    SizedBox(width:11),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(getText('sucursal','Establecimiento'),
        softWrap:true,
        style:TextStyle(color:palette.heroInk,
          fontWeight:FontWeight.w900,fontSize:wide?28:22)),
      Text('Eventos y reservas',
        style:TextStyle(color:palette.heroInk,
          fontSize:13,fontWeight:FontWeight.w600)),
    ])),
    if(wide)...[
      if(eventPhoto(widget.event['imagen'])!=null)
        TextButton(style:TextButton.styleFrom(foregroundColor:palette.heroInk),
        onPressed:()=>jump(_posterKey),child:Text('Afiche')),
      TextButton(style:TextButton.styleFrom(foregroundColor:palette.heroInk),
        onPressed:()=>jump(_galleryKey),child:Text('El lugar')),
      TextButton(style:TextButton.styleFrom(foregroundColor:palette.heroInk),
        onPressed:()=>jump(_menuKey),child:Text('La carta')),
      TextButton(style:TextButton.styleFrom(foregroundColor:palette.heroInk),
        onPressed:()=>jump(_locationKey),child:Text('Ubicación')),
      SizedBox(width:8),
      OutlinedButton.icon(
          style:OutlinedButton.styleFrom(
            foregroundColor:palette.heroInk,
            side:BorderSide(color:palette.heroInk.withOpacity(.72))),
          onPressed:startReservation,
        icon:Icon(Icons.event_seat_outlined,size:17),
        label:Text('Reservar ahora')),
    ]else IconButton(onPressed:widget.onShare,
      tooltip:'Compartir evento',
      icon:Icon(Icons.share_outlined,color:palette.heroInk)),
  ]);


 Widget _poster(bool wide){
   final image=widget.event['imagen'];
   final expand=()=>showEventPhotoViewer(context,eventPalette:palette,
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
                 height:MediaQuery.sizeOf(context).width>=940?590:480,
                  fit:BoxFit.contain)),
             Positioned(bottom:12,right:12,child:Container(
               padding:EdgeInsets.all(9),
               decoration:BoxDecoration(color:palette.surface,
                  borderRadius:BorderRadius.circular(11)),
               child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(Icons.zoom_in,color:palette.accentOnSurface),
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
  final intro=EventPanel(padding:EdgeInsets.all(wide?26:20),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        EventSectionHeading(icon:Icons.auto_awesome_outlined,
          title:'La experiencia',
          subtitle:'Todo lo que necesitas saber antes de reservar'),
        SizedBox(height:19),
        _descriptionBody(getText('descripcion',
          'Una experiencia especial para compartir.')),
        SizedBox(height:10),
        Semantics(
          button:true,
          label:'Abrir reserva del evento',
          child:Material(
            color:palette.surfaceSoft,
            shape:RoundedRectangleBorder(
              borderRadius:BorderRadius.circular(13),
              side:BorderSide(color:palette.border.withOpacity(.55))),
            clipBehavior:Clip.antiAlias,
            child:InkWell(
              onTap:widget.busy?null:startReservation,
              child:Padding(
                padding:EdgeInsets.symmetric(horizontal:14,vertical:15),
                child:Row(children:[
                  Icon(Icons.local_activity_outlined,color:palette.accentOnSoft,size:22),
                  SizedBox(width:11),
                  Expanded(child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(widget.event['precioPorPuesto']==true
                          ?'Valor por persona':'Valor de la reserva',
                        style:TextStyle(color:palette.muted,fontSize:12)),
                      SizedBox(height:3),
                      Text(price(widget.event['precio'])==0
                          ?'Entrada gratuita':currency(widget.event['precio']),
                        style:TextStyle(color:palette.text,
                          fontSize:19,fontWeight:FontWeight.w800)),
                    ])),
                  Text('Reservar',style:TextStyle(
                    color:palette.accentOnSoft,fontSize:12,fontWeight:FontWeight.w800)),
                  SizedBox(width:6),
                  Icon(Icons.arrow_forward_ios_rounded,color:palette.accentOnSoft,size:15),
                ]),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  if(poster==null)return intro;
  if(!wide)return Column(children:[poster,SizedBox(height:17),intro]);
  return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:6,child:poster),
    SizedBox(width:22),
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
           Icon(Icons.zoom_in,color:palette.accentOnSurface)),
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
               onTap:()=>showEventPhotoViewer(context,eventPalette:palette,
                 images:venue.cast<Object?>(),
                 labels:List.generate(venue.length,
                   (j)=>'Fotografía del lugar '+(j+1).toString()),
                 initialIndex:i),
               child:Stack(children:[
                 EventArtwork(source:venue[i],width:width,
                   height:venue.length==1?360:venue.length==2?290:220),
                 Positioned(bottom:9,right:9,
                   child:Container(
                     padding:const EdgeInsets.all(4),
                     decoration:BoxDecoration(
                       color:palette.surface.withOpacity(.94),
                       borderRadius:BorderRadius.circular(30)),
                     child:Icon(Icons.zoom_in,color:palette.accentOnSurface,size:24))),
               ]),
             )),
         ]);
       }),
       if(venue.isNotEmpty)...[
         SizedBox(height:14),
         OutlinedButton.icon(
           onPressed:()=>showEventPhotoViewer(context,eventPalette:palette,
             images:venue.cast<Object?>(),
             labels:List.generate(venue.length,
               (i)=>'Fotografía del lugar '+(i+1).toString())),
           icon:Icon(Icons.fullscreen_outlined),
           label:Text('Ver galería en pantalla completa')),
       ],
     ]));
   // La imagen de ubicación es una fotografía real de la sucursal.
   // Si existe una sola foto, también debe aparecer aquí: no mostrar
   // una tarjeta gris solo por no tener una segunda fotografía.
   final mapPreview=venue.isNotEmpty?venue.last:null;
   final place=EventPanel(child:Column(
     key:_locationKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.location_on_outlined,
         title:'Nuestra ubicación',
         subtitle:'Encuentra cómo llegar al establecimiento.'),
       SizedBox(height:14),
       _locationPhoto(mapPreview),
       SizedBox(height:19),
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

 Widget _locationPhoto(Object? image){
   final hasPhoto=eventPhoto(image)!=null;
   return InkWell(
     onTap:getText('ubicacionGoogleMaps').isEmpty?null:openMap,
     borderRadius:BorderRadius.circular(15),
     child:Container(
       height:MediaQuery.sizeOf(context).width>=940?215:185,
       clipBehavior:Clip.antiAlias,
       decoration:BoxDecoration(
         borderRadius:BorderRadius.circular(15),
         gradient:LinearGradient(
           begin:Alignment.topLeft,end:Alignment.bottomRight,
           colors:[palette.surfaceSoft,
             Color.lerp(palette.surfaceSoft,palette.accent,.15)!]),
         border:Border.all(color:palette.border)),
       child:Stack(children:[
         if(hasPhoto)
           Positioned.fill(child:EventArtwork(source:image,
             height:215,width:double.infinity,borderRadius:0)),
         if(hasPhoto)
           Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
             gradient:LinearGradient(begin:Alignment.bottomCenter,
               end:Alignment.topCenter,colors:[
                 palette.heroShade.withOpacity(.68),Colors.transparent])))),
         if(!hasPhoto)
           Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
             Icon(Icons.place_outlined,color:palette.accentOnSoft,size:37),
             const SizedBox(height:8),
             Text('Encuéntranos',style:TextStyle(color:palette.text,
               fontSize:18,fontWeight:FontWeight.w900)),
             const SizedBox(height:5),
             Padding(padding:const EdgeInsets.symmetric(horizontal:18),
               child:Text(getText('direccion','Consulta cómo llegar'),
                 textAlign:TextAlign.center,maxLines:2,
                 overflow:TextOverflow.ellipsis,
                 style:TextStyle(color:palette.muted,fontSize:12))),
           ])),
         Positioned(left:12,right:12,bottom:12,child:Container(
           padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
           decoration:BoxDecoration(
             color:palette.surface.withOpacity(.94),
             borderRadius:BorderRadius.circular(10),
             border:Border.all(color:palette.border)),
           child:Row(children:[
             Icon(Icons.directions_outlined,
               color:palette.accentOnSurface,size:20),
             const SizedBox(width:8),
             Expanded(child:Text('Cómo llegar · Abrir en Google Maps',
               style:TextStyle(color:palette.onSurface,
                 fontWeight:FontWeight.w800,fontSize:12))),
             Icon(Icons.open_in_new_outlined,
               color:palette.onSurface,size:17),
           ]),
         )),
       ]),
     ),
   );
 }

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
     if(getText('instagram').isNotEmpty||
       getText('facebook').isNotEmpty||
       getText('tiktok').isNotEmpty||whatsappUrl!=null)...[
       SizedBox(height:22),
       Divider(height:1,color:palette.border.withOpacity(.6)),
       SizedBox(height:19),
       Text('Conecta con el establecimiento',
         style:TextStyle(color:palette.text,
          fontWeight:FontWeight.w800,fontSize:14)),
       SizedBox(height:11),
       _socialLinks(),
     ],
     if(whatsappUrl!=null)...[
       SizedBox(height:15),
       OutlinedButton.icon(
         onPressed:openSupport,
         icon:Icon(Icons.support_agent_outlined),
         label:Text('¿Dudas? Escríbenos por WhatsApp'),
         style:OutlinedButton.styleFrom(foregroundColor:palette.text,
           side:BorderSide(color:palette.border))),
     ],
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
   if(whatsappUrl!=null)
    (label:'WhatsApp',url:whatsappUrl.toString(),icon:Icons.chat_outlined),
  ];
  if(items.isEmpty)return const SizedBox.shrink();
  return Wrap(spacing:9,runSpacing:9,children:[
   for(final item in items)
    OutlinedButton.icon(
     onPressed:()async{
      final link=item.label=='WhatsApp'
        ?helpWhatsappLink(item.url,getText('titulo'),getText('sucursal'))
        :Uri.tryParse(item.url);
      if(link!=null&&link.scheme=='https')
       await launchUrl(link,mode:LaunchMode.externalApplication);
     },
     icon:Icon(item.icon,size:17,color:palette.accentOnSurface),
     label:Text(item.label)),
  ]);
 }

 Widget _bookingArea(bool wide){
   if(autoAssignOnly){
     final seats=automaticMax;
     final action=FilledButton.icon(
       onPressed:seats<1||widget.busy?null:startReservation,
       icon:const Icon(Icons.confirmation_number_outlined),
       label:const Text('Elegir mis puestos'),
       style:FilledButton.styleFrom(backgroundColor:brand,
         foregroundColor:onBrand,padding:const EdgeInsets.symmetric(
           horizontal:24,vertical:17)),
     );
     return EventPanel(
       padding:EdgeInsets.symmetric(horizontal:wide?27:20,vertical:wide?25:22),
       child:Container(key:_bookingKey,
         child:wide?Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
           Expanded(child:Column(
             crossAxisAlignment:CrossAxisAlignment.start,children:[
               EventSectionHeading(icon:Icons.event_seat_outlined,
                 title:'Reserva tu lugar',
                 subtitle:'Elige cuántos asistentes van a disfrutar el evento'),
               const SizedBox(height:13),
               Row(children:[
                 Icon(Icons.check_circle_outline,color:palette.accentOnSurface,size:18),
                 const SizedBox(width:8),
                 Flexible(child:Text(seats>0
                   ?'$seats puestos disponibles · Asignación automática'
                   :'No quedan puestos disponibles',
                   style:TextStyle(color:palette.text,
                     fontSize:13,fontWeight:FontWeight.w600))),
               ]),
             ],
           )),
           const SizedBox(width:26),
           action,
         ]):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           EventSectionHeading(icon:Icons.event_seat_outlined,
             title:'Reserva tu lugar',
             subtitle:'Selecciona cuántos asistentes van a disfrutar el evento'),
           const SizedBox(height:13),
           Text(seats>0
             ?'$seats puestos disponibles · Asignación automática'
             :'No quedan puestos disponibles',
             style:TextStyle(color:palette.muted,fontSize:13)),
           const SizedBox(height:17),
           action,
         ]),
       ),
     );
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
          subtitle:Text('Elige la cantidad; podemos asignar varias mesas.'),
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
                       onPressed:()=>showEventPhotoViewer(context,eventPalette:palette,
                         images:[t['foto']],
                         labels:['Mesa '+(t['numero']??id).toString()]),
                       icon:Icon(Icons.zoom_in,size:19))),
                   if(chosen)Positioned(right:8,top:8,
                     child:CircleAvatar(radius:15,backgroundColor:brand,
                       child:Icon(Icons.check,color:onBrand,size:18))),
                   if(!available)Positioned.fill(child:Container(
                       color:palette.heroShade.withOpacity(.60))),
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
                       color:EventPagePalette.readable(
                       available?EventColors.success:EventColors.warning,
                       palette.surfaceSoft),size:17),
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
               ()=>showEventPhotoViewer(context,eventPalette:palette,
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
               style:TextStyle(color:EventPagePalette.readable(
                 EventColors.success,palette.surface),fontSize:12)),
           ])),
         ]),
       ]else if(automatic&&bySeat)
         EventPill(icon:Icons.auto_awesome,
          label:'Se asignarán los puestos entre mesas disponibles')
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
           style:TextStyle(color:EventPagePalette.readable(
             chosenChairs.length==widget.seats?
               EventColors.success:EventColors.warning,palette.surface),fontSize:12)),
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
         Text(currency(total),style:TextStyle(color:palette.accentOnSurface,
           fontWeight:FontWeight.w900,fontSize:20)),
       ]),
       SizedBox(height:20),
       Text('Tus datos',style:TextStyle(
         color:palette.text,fontWeight:FontWeight.w800)),
       SizedBox(height:11),
       TextField(controller:widget.name,
         style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
         textCapitalization:TextCapitalization.words,
         decoration:InputDecoration(
           labelText:'Nombre completo *',prefixIcon:Icon(Icons.person_outline))),
       SizedBox(height:10),
       TextField(controller:widget.email,
         style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
         keyboardType:TextInputType.emailAddress,
         decoration:InputDecoration(
           labelText:'Correo electrónico *',prefixIcon:Icon(Icons.email_outlined))),
       SizedBox(height:10),
       TextField(controller:widget.phone,
         style:TextStyle(color:palette.onSurfaceSoft),cursorColor:palette.accentOnSoft,
         keyboardType:TextInputType.phone,
         decoration:InputDecoration(
           labelText:'Teléfono / WhatsApp',prefixIcon:Icon(Icons.phone_outlined))),
       SizedBox(height:16),
       if(widget.event['medioPago']=='MANUAL')
         Padding(padding:EdgeInsets.only(bottom:12),
           child:Text('La reserva quedará pendiente de aprobación del establecimiento.',
             style:TextStyle(color:palette.accentOnSurface,fontSize:12))),
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
   // La carta usa exclusivamente los productos vinculados al evento en BD.
   final selected=products;
   if(selected.isEmpty)return EventPanel(child:Column(
     key:_menuKey,crossAxisAlignment:CrossAxisAlignment.start,children:[
       EventSectionHeading(icon:Icons.menu_book_outlined,title:'Nuestra carta',
         subtitle:'Selección del establecimiento para esta experiencia'),
       const SizedBox(height:14),
       Text('Este evento todavía no tiene productos seleccionados.',
         style:TextStyle(color:palette.muted)),
     ]));

   final categories=<String,List<Map<String,dynamic>>>{};
   for(final product in selected){
     final type=product['tipo']?.toString().trim()??'';
     categories.putIfAbsent(type.isEmpty?'Nuestra selección':type,()=>[]).add(product);
   }
   final pages=eventMenuPages<Map<String,dynamic>>(categories);

   final paper=palette.menuPaper;
   final rawInk=palette.menuInk;
   final ink=EventPagePalette.contrast(rawInk,paper)>=4.5
     ?rawInk
     :(EventPagePalette.contrast(Colors.black,paper)>
       EventPagePalette.contrast(Colors.white,paper)
         ?Colors.black:Colors.white);
   final secondary=EventPagePalette.readable(
      Color.lerp(ink,paper,.18)!,paper);
   final rule=palette.menuBorder;
   final label=getText('sucursal',getText('empresa','Establecimiento')).trim();
   final subtitle=getText('titulo','Carta del evento');

   Widget productRow(Map<String,dynamic> product,double width){
     final description=product['descripcion']?.toString().trim()??'';
     final name=product['nombre']?.toString().trim()??'';
     final shownPrice=product['precio']==null
       ?'Consultar precio':'\$'+currency(product['precio']).replaceFirst('COP ','');
     final hasPhoto=width>=490&&eventPhoto(product['imagen'])!=null;
     return Padding(
       padding:const EdgeInsets.symmetric(horizontal:3,vertical:11),
       child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
         if(hasPhoto)...[
           EventArtwork(source:product['imagen'],width:72,height:72,
             borderRadius:11),
           const SizedBox(width:13),
         ],
         Expanded(child:Column(
           crossAxisAlignment:CrossAxisAlignment.start,children:[
             Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
               Expanded(child:Text(name,maxLines:3,
                 overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontFamily:'Georgia',
                   fontSize:width<410?14:15,fontWeight:FontWeight.w800,
                   height:1.3,color:ink))),
               const SizedBox(width:8),
               Text(shownPrice,textAlign:TextAlign.end,
                 style:TextStyle(fontSize:width<410?13:14,
                   fontWeight:FontWeight.w800,color:ink)),
             ]),
             if(description.isNotEmpty)...[
               const SizedBox(height:5),
               Text(description,maxLines:4,overflow:TextOverflow.ellipsis,
                 style:TextStyle(fontSize:width<410?12:13,
                   color:secondary,height:1.48)),
             ],
           ],
         )),
       ]),
     );
   }

   Widget menuSheet(List<MapEntry<String,List<Map<String,dynamic>>>> sections,
     int index,double width){
     final compact=width<450;
     return Container(
       width:width,
       decoration:BoxDecoration(
         color:paper,borderRadius:BorderRadius.circular(17),
         border:Border.all(color:rule.withOpacity(.75),width:1.1),
         boxShadow:[BoxShadow(color:Colors.black.withOpacity(.22),
           blurRadius:22,offset:const Offset(0,10))]),
       child:Padding(
         padding:EdgeInsets.fromLTRB(compact?20:28,compact?23:30,
           compact?20:28,20),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Center(child:Container(width:44,height:3,
             decoration:BoxDecoration(color:palette.accent,
               borderRadius:BorderRadius.circular(4)))),
           const SizedBox(height:17),
           Text(label.isEmpty?'Establecimiento':label,
             maxLines:2,overflow:TextOverflow.ellipsis,
             textAlign:TextAlign.center,
             style:TextStyle(fontFamily:'Georgia',
               fontSize:compact?22:27,fontWeight:FontWeight.w700,
               letterSpacing:.6,color:ink)),
           const SizedBox(height:5),
           Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
             textAlign:TextAlign.center,
             style:TextStyle(color:secondary,fontSize:compact?12:13,
               fontWeight:FontWeight.w600)),
           const SizedBox(height:7),
           Text('MENÚ DEL EVENTO',textAlign:TextAlign.center,
             style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,
               letterSpacing:2,color:secondary)),
           const SizedBox(height:23),
           for(final section in sections)...[
             Row(children:[
               Expanded(child:Container(height:1,color:rule.withOpacity(.52))),
               Padding(padding:const EdgeInsets.symmetric(horizontal:13),
                 child:Icon(Icons.auto_awesome_outlined,
                   color:EventPagePalette.readable(palette.accent,paper),size:15)),
               Expanded(child:Container(height:1,color:rule.withOpacity(.52))),
             ]),
             const SizedBox(height:13),
             Text(section.key,textAlign:TextAlign.center,
               maxLines:2,overflow:TextOverflow.ellipsis,
               style:TextStyle(fontFamily:'Georgia',
                 fontSize:compact?23:26,
                 fontWeight:FontWeight.w700,color:ink,height:1.18)),
             const SizedBox(height:12),
             LayoutBuilder(builder:(context,bounds){
               final columns=section.value.length>=3&&bounds.maxWidth>=535?2:1;
               final w=(bounds.maxWidth-(columns-1)*18)/columns;
               return Wrap(spacing:18,runSpacing:2,children:[
                 for(final product in section.value)
                   SizedBox(width:w,child:productRow(product,w)),
               ]);
             }),
             const SizedBox(height:18),
           ],
           const SizedBox(height:4),
           Container(height:1,color:rule.withOpacity(.5)),
           const SizedBox(height:13),
           Text((index+1).toString()+' / '+pages.length.toString(),
             textAlign:TextAlign.center,
             style:TextStyle(color:secondary,fontSize:11,
               letterSpacing:1.7,fontWeight:FontWeight.w700)),
         ]),
       ),
     );
   }

   return Column(
     key:_menuKey,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       EventPanel(padding:const EdgeInsets.symmetric(
         horizontal:23,vertical:21),child:Column(
         crossAxisAlignment:CrossAxisAlignment.start,children:[
           EventSectionHeading(icon:Icons.menu_book_outlined,
             title:'Nuestra carta',
             subtitle:'Selección del establecimiento · '+
               selected.length.toString()+' productos'),
           const SizedBox(height:8),
           Text('Sabores elegidos especialmente para este evento',
             style:TextStyle(color:palette.muted,fontSize:13,height:1.45)),
         ],
       )),
       const SizedBox(height:18),
       LayoutBuilder(builder:(context,space){
         final paired=space.maxWidth>=930;
         final width=paired?(space.maxWidth-20)/2:space.maxWidth;
         return Wrap(spacing:20,runSpacing:20,children:[
           for(var i=0;i<pages.length;i++)menuSheet(pages[i],i,width),
         ]);
       }),
     ],
   );
 }

 Widget _footer(bool wide)=>Container(
   padding:EdgeInsets.symmetric(horizontal:17,vertical:19),
   decoration:BoxDecoration(
     color:palette.surface.withOpacity(.95),
     borderRadius:BorderRadius.circular(16),
     border:Border.all(color:palette.border)),
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
