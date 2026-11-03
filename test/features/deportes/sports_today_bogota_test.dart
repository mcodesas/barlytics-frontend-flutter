import 'package:barlytics_frontend/features/deportes/presentation/widgets/sports_agenda_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('partidos de hoy en Inicio gerencial', () {
    test('utiliza fecha Colombia cuando UTC ya pasó a otro día', () {
      final today = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 2, 45));
      expect(today.year, 2026);
      expect(today.month, 11);
      expect(today.day, 2);
    });

    test('renueva fecha cuando Bogotá llega a medianoche', () {
      final before = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 4, 59));
      final after = sportsTodayBogota(now: DateTime.utc(2026, 11, 3, 5, 0));
      expect(before.day, 2);
      expect(after.day, 3);
      expect(after.difference(before).inDays, 1);
    });

    test('respeta el mismo día en Colombia durante el día', () {
      final today = sportsTodayBogota(now: DateTime.utc(2026, 11, 2, 20));
      expect(today.day, 2);
    });
  });
}
