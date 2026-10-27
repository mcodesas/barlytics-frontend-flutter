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
  test('Instagram y TikTok copian enlace en vez de fingir publicación',(){
    expect(shareByCopy(ShareNetwork.instagram),isTrue);
    expect(shareByCopy(ShareNetwork.tiktok),isTrue);
    expect(shareByCopy(ShareNetwork.threads),isTrue);
    expect(shareByCopy(ShareNetwork.facebook),isFalse);
  });
}
