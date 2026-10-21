import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barlytics_frontend/features/auth/data/services/remember_login_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('por defecto no recuerda usuario ni contraseña', () async {
    final preference = await const RememberLoginPreferences().load();
    expect(preference.enabled, false);
    expect(preference.identifier, isEmpty);
  });

  test('solo recuerda identificador y consentimiento', () async {
    const service = RememberLoginPreferences();
    await service.save(enabled: true, identifier: '  bar@example.com  ');

    final saved = await service.load();
    expect(saved.enabled, isTrue);
    expect(saved.identifier, 'bar@example.com');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(RememberLoginPreferences.enabledKey), isTrue);
    expect(prefs.getString(RememberLoginPreferences.identifierKey), 'bar@example.com');
    expect(prefs.getKeys(), isNot(contains('password')));
  });

  test('desmarcar elimina lo recordado sin borrar otras preferencias', () async {
    const service = RememberLoginPreferences();
    await service.save(enabled: true, identifier: 'bar@example.com');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('not_a_login_token', 'preserved');

    await service.forget();
    final saved = await service.load();
    expect(saved.enabled, isFalse);
    expect(saved.identifier, isEmpty);
    expect(prefs.containsKey(RememberLoginPreferences.enabledKey), isFalse);
    expect(prefs.containsKey(RememberLoginPreferences.identifierKey), isFalse);
    expect(prefs.getString('not_a_login_token'), 'preserved');
  });

  test('no acepta identificadores persistidos sin preferencia activa', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RememberLoginPreferences.identifierKey: 'old@example.com',
    });
    final saved = await const RememberLoginPreferences().load();
    expect(saved.enabled, isFalse);
    expect(saved.identifier, isEmpty);
  });
}
