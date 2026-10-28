import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_share_sheet.dart';

void main(){
  test('WhatsApp de dudas usa únicamente contacto del evento',(){
    final uri=helpWhatsappLink('https://wa.me/573001234567',
      'Brunch','Sucursal Centro');
    expect(uri,isNotNull);
    expect(uri!.host,'wa.me');
    expect(uri.path,'/573001234567');
    expect(uri.queryParameters['text'],contains('Brunch'));
    expect(uri.queryParameters['text'],contains('Sucursal Centro'));
  });
  test('WhatsApp del evento es prioritario frente al teléfono de la sucursal',(){
    final uri=eventWhatsappHelpLink({
      'titulo':'Brunch','sucursal':'Sucursal Norte',
      'whatsapp':'https://wa.me/573111112222',
      'telefono':'3001234567'
    });
    expect(uri?.path,'/573111112222');
  });
  test('Si falta el WhatsApp del evento usa el móvil de su sucursal',(){
    final uri=eventWhatsappHelpLink({
      'titulo':'Concierto','sucursal':'Sucursal Sur',
      'whatsapp':null,'telefono':'314 257 1739'
    });
    expect(uri?.host,'wa.me');
    expect(uri?.path,'/573142571739');
    expect(uri?.queryParameters['text'],contains('Sucursal Sur'));
  });
  test('No utiliza teléfonos fijos ni contactos de otras sucursales',(){
    expect(eventWhatsappHelpLink({
      'titulo':'Evento','sucursal':'Centro','telefono':'6015555555'
    }),isNull);
    expect(eventWhatsappHelpLink({
      'titulo':'Evento','sucursal':'Centro','telefono':null
    }),isNull);
    expect(eventWhatsappHelpLink({
      'titulo':'Evento','sucursal':'Centro','whatsapp':'https://sitio-falso.com',
      'telefono':'300 123 4567'
    })?.path,'/573001234567');
  });
  test('No permite dirigir las consultas a URLs ajenas a WhatsApp',(){
    expect(helpWhatsappLink('https://example.com/3001234567','Evento',''),isNull);
    expect(helpWhatsappLink('javascript:alert(1)','Evento',''),isNull);
    expect(helpWhatsappLink('','Evento',''),isNull);
  });
  test('Facebook Telegram y WhatsApp comparten enlace de vista previa',(){
    final url='https://www.barlytics.com.co/api/v1/eventos/public/demo/compartir';
    expect(shareDestination(ShareNetwork.facebook,url,'Evento').queryParameters['u'],url);
    expect(shareDestination(ShareNetwork.telegram,url,'Evento').queryParameters['url'],url);
    expect(shareDestination(ShareNetwork.whatsapp,url,'Evento')
      .queryParameters['text'],contains(url));
  });
  test('WhatsApp comparte siempre el enlace de la vista previa del evento',(){
    const preview='https://www.barlytics.com.co/api/v1/eventos/public/brunch/compartir?v=imagen7';
    const defaultLink='https://www.barlytics.com.co/api/v1/eventos/public/brunch/compartir';
    expect(eventSocialPreviewUrl({'enlaceCompartir':preview},defaultLink),preview);
    expect(shareDestination(ShareNetwork.whatsapp,preview,'Brunch')
       .queryParameters['text'],contains(preview));
  });
  test('Usa el dominio real sin www cuando el evento fue abierto allí',(){
    const fallback='https://www.barlytics.com.co/api/v1/eventos/public/brunch/compartir';
    const preview='https://www.barlytics.com.co/api/v1/eventos/public/brunch/compartir?v=afiche2';
    final shared=eventSocialPreviewUrl({'enlaceCompartir':preview},fallback,
      websiteUri:Uri.parse('https://barlytics.com.co/#/evento/brunch'));
    expect(shared,
      'https://barlytics.com.co/api/v1/eventos/public/brunch/compartir?v=afiche2');
  });
  test('No reescribe enlaces de otro dominio o de la aplicación móvil',(){
    const preview='https://api.ejemplo.com/api/v1/eventos/public/brunch/compartir?v=2';
    expect(eventSocialPreviewUrl({'enlaceCompartir':preview},preview,
      websiteUri:Uri.parse('https://barlytics.com.co/')),preview);
  });
  test('La raíz genérica de BarLytics nunca sustituye la vista previa',(){
    const fallback='https://www.barlytics.com.co/api/v1/eventos/public/brunch/compartir';
    expect(eventSocialPreviewUrl({'enlaceCompartir':'https://www.barlytics.com.co'},fallback),fallback);
    expect(eventSocialPreviewUrl({'enlaceCompartir':''},fallback),fallback);
    expect(eventSocialPreviewUrl({'enlaceCompartir':'javascript:alert(1)'},fallback),fallback);
  });
  test('Instagram y TikTok copian enlace en vez de fingir publicación',(){
    expect(shareByCopy(ShareNetwork.instagram),isTrue);
    expect(shareByCopy(ShareNetwork.tiktok),isTrue);
    expect(shareByCopy(ShareNetwork.threads),isTrue);
    expect(shareByCopy(ShareNetwork.facebook),isFalse);
  });
}
